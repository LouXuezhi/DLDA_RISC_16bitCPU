#!/usr/bin/env python3
"""逐个模块验证。testbench 只打印「输入 → 输出」，对错在这里判。

    python3 verif/unit.py              全部模块
    python3 verif/unit.py alu regfile  只跑这几个

每个模块一个参考函数，照 doc/ISA.md 和 src/define_ctrl.v 的编码写，
不看 RTL 的实现。组合模块：给一行输入，算出应有的输出。时序模块：
一个 Python 模型逐拍跟着走。
"""
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "src")
UNIT = os.path.join(HERE, "unit")
BUILD = os.path.join(ROOT, "build", "unit")
sys.path.insert(0, os.path.join(HERE, "model"))
from iss import alu as iss_alu, sext8  # noqa: E402

M16 = 0xFFFF
X = None                     # 未定值：RTL 打印成 xxxx


def s16(v):
    return v - 0x10000 if v & 0x8000 else v


def val(tok):
    return X if "x" in tok or "z" in tok else int(tok, 16)


#---- 组合模块的参考 ------------------------------------------------------
#  每个函数：输入元组 -> 期望输出元组

def ref_mux2(sel, d0, d1):
    return (d1 if sel else d0,)


def ref_mux3(sel, d0, d1, d2):
    return ({1: d1, 2: d2}.get(sel, d0),)


def ref_adder(a, b):
    return ((a + b) & M16,)


def ref_alu(op, a, b):
    r = iss_alu(op, a, b)                # ISS 的 R 型语义；不认识的码 -> None
    r = 0 if r is None else r            # ALU_NOP 和保留码输出 0
    c = v = 0
    if op == 1:                          # ADD：按数学值判断，不抄 RTL 的位公式
        c = int(a + b > M16)
        v = int(not -0x8000 <= s16(a) + s16(b) <= 0x7FFF)
    elif op == 2:                        # SUB
        c = int(a < b)
        v = int(not -0x8000 <= s16(a) - s16(b) <= 0x7FFF)
    return (r, int(r == 0), r >> 15, c, v)


def ref_branch_cmp(a, b):
    return (int(a == b), int(s16(a) < s16(b)))


def ref_imm_ext(inst, sel):
    imm_i = inst & 0xFF
    imm_s = ((inst >> 10) & 3) << 6 | (inst & 0x3F)
    return ({0: sext8(imm_i), 1: imm_i, 2: (imm_i << 8) & M16, 3: sext8(imm_s)}[sel],)


# 控制字编码，照 src/define_ctrl.v
REG, ZERO, IMM = 0, 1, 1
SEXT_I, ZEXT_I, LUI_I, SEXT_S = 0, 1, 2, 3
WB_ALU, WB_MEM, WB_PC1 = 0, 1, 2
PLUS1, REL, PCALU = 0, 1, 2
ADD, AND, OR = 1, 3, 4

# doc/ISA.md 译码表：opcode -> (reg_we, mem_we, src_a, src_b, imm_sel, alu_op, wb_sel)
DECODE = {
    0x2: (1, 0, REG,  IMM, SEXT_I, ADD, WB_ALU),   # ADDI
    0x3: (1, 0, REG,  IMM, ZEXT_I, AND, WB_ALU),   # ANDI
    0x4: (1, 0, REG,  IMM, ZEXT_I, OR,  WB_ALU),   # ORI
    0x5: (1, 0, ZERO, IMM, SEXT_I, ADD, WB_ALU),   # LI
    0x6: (1, 0, ZERO, IMM, LUI_I,  ADD, WB_ALU),   # LUI
    0x7: (1, 0, REG,  IMM, SEXT_I, ADD, WB_MEM),   # LD
    0x8: (0, 1, REG,  IMM, SEXT_S, ADD, WB_ALU),   # ST
    0x9: (0, 0, REG,  REG, SEXT_S, 0,   WB_ALU),   # BEQ
    0xA: (0, 0, REG,  REG, SEXT_S, 0,   WB_ALU),   # BNE
    0xB: (0, 0, REG,  REG, SEXT_S, 0,   WB_ALU),   # BLT
    0xC: (0, 0, REG,  REG, SEXT_S, 0,   WB_ALU),   # BGE
    0xD: (1, 0, REG,  REG, SEXT_I, 0,   WB_PC1),   # JAL
    0xE: (1, 0, REG,  IMM, SEXT_I, ADD, WB_PC1),   # JALR
}


def ref_control_unit(rst, inst, eq, lt):
    op, funct = inst >> 12, inst & 0x3F
    if rst:
        return (0,) * 8
    if op == 0x1:                                   # ALU：funct 就是 alu_op
        return (int(1 <= funct <= 11), 0, REG, REG, SEXT_I, funct, WB_ALU, PLUS1)
    if op not in DECODE:                            # SYS 和保留的 1111
        return (0,) * 8
    taken = {0x9: eq, 0xA: not eq, 0xB: lt, 0xC: not lt, 0xD: 1}.get(op, 0)
    pc_sel = PCALU if op == 0xE else (REL if taken else PLUS1)
    return DECODE[op] + (pc_sel,)


#---- 时序模块的模型 ------------------------------------------------------
#  每个函数吃全部行，返回 (出错行号, 说明) 的列表

def seq_pc_reg(rows):
    pc, bad = 0, []            # tb 以 rst=1 起步，打印第一行前已经过了一个上升沿
    for i, (rst, nxt, got) in enumerate(rows):
        if got != pc:
            bad.append((i, "pc=%s 期望 %s" % (hx(got), hx(pc))))
        pc = 0 if rst else nxt
    return bad


def seq_regfile(rows):
    regs, bad = [X] * 4, []
    for i, (we, wa, wd, ra1, rd1, ra2, rd2) in enumerate(rows):
        if (rd1, rd2) != (regs[ra1], regs[ra2]):    # 同拍写不影响读：没有旁路
            bad.append((i, "读 R%d=%s R%d=%s 期望 %s %s" %
                        (ra1, hx(rd1), ra2, hx(rd2), hx(regs[ra1]), hx(regs[ra2]))))
        if we:
            regs[wa] = wd
    return bad


def seq_dmem(rows, init):
    mem, bad = list(init) + [0] * (256 - len(init)), []
    for i, (we, addr, wd, rd) in enumerate(rows):
        if rd != mem[addr]:
            bad.append((i, "M[%02x]=%s 期望 %s" % (addr, hx(rd), hx(mem[addr]))))
        if we:
            mem[addr] = wd
    return bad


def seq_imem(rows, init):
    mem, bad = list(init) + [0] * (1024 - len(init)), []
    for i, (addr, got) in enumerate(rows):
        if got != mem[addr & 1023]:
            bad.append((i, "imem[%04x]=%s 期望 %s" % (addr, hx(got), hx(mem[addr & 1023]))))
    return bad


def hx(v):
    return "xxxx" if v is X else "%x" % v


#---- 运行 ----------------------------------------------------------------
#  名字 -> (输入个数, 参考)；输入个数之后的列是输出。时序模块另走。
COMB = {
    "mux2": (3, ref_mux2), "mux3": (4, ref_mux3), "adder": (2, ref_adder),
    "alu": (3, ref_alu), "branch_cmp": (2, ref_branch_cmp),
    "imm_ext": (2, ref_imm_ext), "control_unit": (4, ref_control_unit),
}
SEQ = ["pc_reg", "regfile", "dmem", "imem"]


def simulate(name, params=()):
    os.makedirs(BUILD, exist_ok=True)
    exe = os.path.join(BUILD, name)
    src = [os.path.join(SRC, f) for f in sorted(os.listdir(SRC)) if f.endswith(".v")]
    cmd = ["iverilog", "-g2005", "-I", SRC, "-I", UNIT, "-s", "tb_" + name, "-o", exe]
    cmd += ["-Ptb_%s.%s=\"%s\"" % (name, k, v) for k, v in params]
    subprocess.run(cmd + [os.path.join(UNIT, "tb_%s.v" % name)] + src, check=True)
    out = subprocess.run([exe], capture_output=True, text=True).stdout
    return [[val(t) for t in l.split()] for l in out.splitlines()
            if l and not l.startswith(("WARNING", "VCD"))]


def write_init(name, n, rng):
    words = [rng.randrange(1 << 16) for _ in range(n)]
    path = os.path.join(BUILD, name + "_init.hex")
    os.makedirs(BUILD, exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join("%04x" % w for w in words) + "\n")
    return path, words


def run(name):
    rng = random.Random(name)
    if name in COMB:
        nin, ref = COMB[name]
        rows = simulate(name)
        bad = []
        for i, r in enumerate(rows):
            want = ref(*r[:nin])
            if tuple(r[nin:]) != want:
                bad.append((i, "输入 %s 得 %s 期望 %s" %
                            (" ".join(map(hx, r[:nin])), " ".join(map(hx, r[nin:])),
                             " ".join(map(hx, want)))))
    elif name == "pc_reg":
        rows = simulate(name); bad = seq_pc_reg(rows)
    elif name == "regfile":
        rows = simulate(name); bad = seq_regfile(rows)
    elif name == "dmem":
        path, init = write_init("dmem", 200, rng)      # 只装前 200 个，后面要读出 0
        rows = simulate(name, [("INIT", path)]); bad = seq_dmem(rows, init)
    elif name == "imem":
        path, init = write_init("imem", 700, rng)
        rows = simulate(name, [("INIT", path)]); bad = seq_imem(rows, init)
    else:
        sys.exit("没有这个模块: %s" % name)

    if not rows:
        bad = [(0, "testbench 没有输出")]
    print("%-4s %-13s %7d 组向量%s" % ("FAIL" if bad else "ok", name, len(rows),
                                     "" if not bad else "，%d 组不对" % len(bad)))
    for i, msg in bad[:5]:
        print("       第 %d 行: %s" % (i, msg))
    return not bad


def main():
    names = sys.argv[1:] or list(COMB) + SEQ
    fails = sum(not run(n) for n in names)
    print("\n%s" % ("全部模块通过" if not fails else "%d 个模块失败" % fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
