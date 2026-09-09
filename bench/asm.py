#!/usr/bin/env python3
"""class_cpu 汇编器 -- .s 汇编成 $readmemh 能读的 .hex。

    bench/asm.py bench/prog/fib.s > bench/prog/fib.hex

编码见 doc/ISA.md 和 src/define_ISA.v；这里是那张表的机器可读形式，
两者不一致时改这个文件，不要改 ISA。

语法：
    label:                      标号，单独一行或在指令前
    ADD  Rd, Rs1, Rs2           R 型
    ADDI Rd, Rs1, #imm          I 型
    LI   Rd, #imm               LUI 同
    LD   Rd, imm(Rs1)           JALR 同
    ST   Rs2, imm(Rs1)          S 型，第一个寄存器是数据源
    BEQ  Rs1, Rs2, label        BNE BLT BGE 同；也接受 #imm
    JAL  Rd, label              也接受 #imm
    ; 注释                      # 和 // 也行
伪指令：NOP / MOV Rd,Rs / NOT Rd,Rs / NEG Rd,Rs / J Rd,label / HALT Rd /
        RET Rd,Rlink / LI16 Rd,#imm16 / BGT / BLE
HALT 和 J 都要写出那个被丢弃的 Rd —— JAL 每次都会写它，挑一个后面不读的。
"""
import re
import sys

FUNCT = {"ADD": 1, "SUB": 2, "AND": 3, "OR": 4, "XOR": 5, "NOR": 6,
         "SLT": 7, "SLTU": 8, "SLL": 9, "SRL": 10, "SRA": 11}
OP = {"SYS": 0, "ALU": 1, "ADDI": 2, "ANDI": 3, "ORI": 4, "LI": 5, "LUI": 6,
      "LD": 7, "ST": 8, "BEQ": 9, "BNE": 10, "BLT": 11, "BGE": 12,
      "JAL": 13, "JALR": 14}
BRANCH = ("BEQ", "BNE", "BLT", "BGE")
# 伪指令展开成几个字 -- 第一趟排地址要用
WIDTH = {"NEG": 2, "LI16": 2}


class AsmError(Exception):
    pass


def reg(tok):
    m = re.fullmatch(r"[Rr]([0-3])", tok.strip())
    if not m:
        raise AsmError("不是寄存器: %s" % tok)
    return int(m.group(1))


def imm(tok, lo, hi):
    v = int(tok.strip().lstrip("#"), 0)
    if not lo <= v <= hi:
        raise AsmError("立即数 %d 超出 [%d, %d]" % (v, lo, hi))
    return v & 0xFF


def split_ops(rest):
    return [t for t in (t.strip() for t in rest.split(",")) if t]


def mem_operand(tok):
    """imm(Rs1) -> (imm, rs1)"""
    m = re.fullmatch(r"(.+?)\s*\(\s*([Rr][0-3])\s*\)", tok.strip())
    if not m:
        raise AsmError("不是 imm(Rs) 形式: %s" % tok)
    return m.group(1), reg(m.group(2))


def expand(mn, ops):
    """伪指令 -> 真指令列表。返回 [(助记符, 操作数列表), ...]"""
    if mn == "NOP":
        return [("SYS", [])]
    if mn == "MOV":
        return [("ADDI", [ops[0], ops[1], "#0"])]
    if mn == "NOT":
        return [("NOR", [ops[0], ops[1], ops[1]])]
    if mn == "NEG":
        return [("NOR", [ops[0], ops[1], ops[1]]), ("ADDI", [ops[0], ops[0], "#1"])]
    if mn == "J":
        return [("JAL", [ops[0], ops[1]])]
    if mn == "HALT":
        return [("JAL", [ops[0], "#0"])]
    if mn == "RET":
        return [("JALR", [ops[0], "0(%s)" % ops[1]])]
    if mn == "LI16":
        v = int(ops[1].lstrip("#"), 0) & 0xFFFF
        return [("LUI", [ops[0], "#%d" % (v >> 8)]),
                ("ORI", [ops[0], ops[0], "#%d" % (v & 0xFF)])]
    if mn == "BGT":                       # a > b  <=>  b < a
        return [("BLT", [ops[1], ops[0], ops[2]])]
    if mn == "BLE":                       # a <= b <=>  b >= a
        return [("BGE", [ops[1], ops[0], ops[2]])]
    return [(mn, ops)]


def encode(mn, ops, here, labels):
    def target(tok):
        tok = tok.strip()
        if tok.lstrip("#").lstrip("-").isdigit() or tok.startswith("0x"):
            return imm(tok, -128, 127)
        if tok not in labels:
            raise AsmError("未定义的标号: %s" % tok)
        off = labels[tok] - here          # 分支和 JAL 相对指令自身
        if not -128 <= off <= 127:
            raise AsmError("标号 %s 距离 %d，超出 ±128" % (tok, off))
        return off & 0xFF

    if mn == "SYS":
        return 0x0000
    if mn in FUNCT:
        rd, rs1, rs2 = (reg(o) for o in ops)
        return (OP["ALU"] << 12) | (rd << 10) | (rs1 << 8) | (rs2 << 6) | FUNCT[mn]
    if mn in ("ADDI", "ANDI", "ORI"):
        rd, rs1 = reg(ops[0]), reg(ops[1])
        v = imm(ops[2], 0, 255) if mn in ("ANDI", "ORI") else imm(ops[2], -128, 127)
        return (OP[mn] << 12) | (rd << 10) | (rs1 << 8) | v
    if mn in ("LI", "LUI"):
        rd = reg(ops[0])
        v = imm(ops[1], 0, 255) if mn == "LUI" else imm(ops[1], -128, 127)
        return (OP[mn] << 12) | (rd << 10) | v
    if mn in ("LD", "JALR"):
        rd = reg(ops[0])
        off, rs1 = mem_operand(ops[1])
        return (OP[mn] << 12) | (rd << 10) | (rs1 << 8) | imm(off, -128, 127)
    if mn == "ST":
        rs2 = reg(ops[0])
        off, rs1 = mem_operand(ops[1])
        v = imm(off, -128, 127)
        return (OP["ST"] << 12) | ((v >> 6) << 10) | (rs1 << 8) | (rs2 << 6) | (v & 0x3F)
    if mn in BRANCH:
        rs1, rs2 = reg(ops[0]), reg(ops[1])
        v = target(ops[2])
        return (OP[mn] << 12) | ((v >> 6) << 10) | (rs1 << 8) | (rs2 << 6) | (v & 0x3F)
    if mn == "JAL":
        return (OP["JAL"] << 12) | (reg(ops[0]) << 10) | target(ops[1])
    raise AsmError("不认识的助记符: %s" % mn)


def parse(text):
    """-> [(行号, 源文本, 标号 or None, 助记符 or None, 操作数)]"""
    out = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = re.split(r";|//|#(?![0-9a-fA-FxX-])", raw, maxsplit=1)[0].strip()
        label = None
        m = re.match(r"([A-Za-z_.][\w.]*)\s*:\s*(.*)", line)
        if m:
            label, line = m.group(1), m.group(2).strip()
        mn, ops = None, []
        if line:
            parts = line.split(None, 1)
            mn = parts[0].upper()
            ops = split_ops(parts[1]) if len(parts) > 1 else []
        out.append((lineno, raw.rstrip(), label, mn, ops))
    return out


def assemble(text):
    stmts = parse(text)
    labels, addr = {}, 0
    for lineno, raw, label, mn, ops in stmts:          # 第一趟：排地址
        if label is not None:
            if label in labels:
                raise AsmError("第 %d 行: 标号 %s 重复" % (lineno, label))
            labels[label] = addr
        if mn:
            addr += WIDTH.get(mn, 1)

    lines, addr = [], 0
    for lineno, raw, label, mn, ops in stmts:          # 第二趟：编码
        if mn is None:
            body = raw.strip()
            lines.append(body if body.startswith("//") else
                         ("// %s" % body if body else ""))
            continue
        try:
            words = [encode(m, o, addr + i, labels)
                     for i, (m, o) in enumerate(expand(mn, ops))]
        except (AsmError, ValueError, IndexError) as e:
            raise AsmError("第 %d 行: %s\n    %s" % (lineno, e, raw.strip()))
        lines.append("// %3d  %s" % (addr, raw.strip()))
        lines += ["%04X" % w for w in words]
        addr += len(words)
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("用法: bench/asm.py FILE.s > FILE.hex")
    try:
        sys.stdout.write(assemble(open(sys.argv[1]).read()))
    except AsmError as e:
        sys.exit("asm: %s: %s" % (sys.argv[1], e))
