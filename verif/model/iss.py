#!/usr/bin/env python3
"""class_cpu 指令级模拟器（ISS）—— 验证用的参考模型。

只照 doc/ISA.md 写，不看 src/。它不知道流水线还是单周期，只知道每条指令
执行完之后架构状态（PC、R0–R3、数据存储）应该是什么。

    python3 verif/model/iss.py PROG.hex [DATA.hex] [--trace] [--cap N]

作为库用：
    cpu = Iss(prog_words, data_words)
    for c in cpu.run():      # 每条指令产出一个 Commit
        ...
"""
import sys
from dataclasses import dataclass
from typing import List, Optional

MASK16 = 0xFFFF
IMEMNUM = 1024          # define_ISA.v `IMEMNUM
DMEMNUM = 256           # define_ISA.v `DMEMNUM

OP_SYS, OP_ALU, OP_ADDI, OP_ANDI, OP_ORI, OP_LI, OP_LUI, OP_LD, OP_ST = range(9)
OP_BEQ, OP_BNE, OP_BLT, OP_BGE, OP_JAL, OP_JALR = range(9, 15)

F_ADD, F_SUB, F_AND, F_OR, F_XOR, F_NOR, F_SLT, F_SLTU, F_SLL, F_SRL, F_SRA = range(1, 12)


def sext8(v):
    v &= 0xFF
    return (v - 0x100 if v & 0x80 else v) & MASK16


def signed16(v):
    return v - 0x10000 if v & 0x8000 else v


def alu(funct, a, b):
    """R 型 funct 的语义。不认识的 funct 返回 None —— 不写回。"""
    sh = b & 0xF
    if funct == F_ADD:  return (a + b) & MASK16
    if funct == F_SUB:  return (a - b) & MASK16
    if funct == F_AND:  return a & b
    if funct == F_OR:   return a | b
    if funct == F_XOR:  return a ^ b
    if funct == F_NOR:  return ~(a | b) & MASK16
    if funct == F_SLT:  return int(signed16(a) < signed16(b))
    if funct == F_SLTU: return int(a < b)
    if funct == F_SLL:  return (a << sh) & MASK16
    if funct == F_SRL:  return a >> sh
    if funct == F_SRA:  return (signed16(a) >> sh) & MASK16
    return None


@dataclass
class Commit:
    """一条指令执行完的全部架构副作用。比对就比这个。"""
    pc: int
    inst: int
    next_pc: int
    rd: Optional[int] = None        # 写了哪个寄存器（没写为 None）
    wdata: Optional[int] = None
    st_addr: Optional[int] = None   # ST 写了哪个数据字
    st_data: Optional[int] = None

    @property
    def halt(self):
        return self.next_pc == self.pc

    def __str__(self):
        s = "pc=%04x inst=%04x next=%04x" % (self.pc, self.inst, self.next_pc)
        if self.rd is not None:
            s += " r%d<=%04x" % (self.rd, self.wdata)
        if self.st_addr is not None:
            s += " M[%02x]<=%04x" % (self.st_addr, self.st_data)
        return s


class Iss:
    def __init__(self, prog: List[int], data: List[int] = ()):
        self.imem = [0] * IMEMNUM
        self.dmem = [0] * DMEMNUM
        for i, w in enumerate(prog[:IMEMNUM]):
            self.imem[i] = w & MASK16
        for i, w in enumerate(list(data)[:DMEMNUM]):
            self.dmem[i] = w & MASK16
        # 寄存器上电不定；RTL 里是 x。ISA 不承诺初值，程序必须先写后读。
        self.regs = [0] * 4
        self.pc = 0

    def step(self) -> Commit:
        pc = self.pc
        inst = self.imem[pc % IMEMNUM]
        op = inst >> 12
        rd = (inst >> 10) & 3
        rs1 = (inst >> 8) & 3
        rs2 = (inst >> 6) & 3
        funct = inst & 0x3F
        imm_i = inst & 0xFF
        imm_s = (((inst >> 10) & 3) << 6) | (inst & 0x3F)
        a, b = self.regs[rs1], self.regs[rs2]

        c = Commit(pc=pc, inst=inst, next_pc=(pc + 1) & MASK16)
        wb = None
        if op == OP_ALU:
            wb = alu(funct, a, b)
        elif op == OP_ADDI:
            wb = (a + sext8(imm_i)) & MASK16
        elif op == OP_ANDI:
            wb = a & imm_i
        elif op == OP_ORI:
            wb = a | imm_i
        elif op == OP_LI:
            wb = sext8(imm_i)
        elif op == OP_LUI:
            wb = (imm_i << 8) & MASK16
        elif op == OP_LD:
            wb = self.dmem[(a + sext8(imm_i)) & 0xFF]
        elif op == OP_ST:
            c.st_addr, c.st_data = (a + sext8(imm_s)) & 0xFF, b
            self.dmem[c.st_addr] = b
        elif op in (OP_BEQ, OP_BNE, OP_BLT, OP_BGE):
            take = {OP_BEQ: a == b, OP_BNE: a != b,
                    OP_BLT: signed16(a) < signed16(b),
                    OP_BGE: signed16(a) >= signed16(b)}[op]
            if take:
                c.next_pc = (pc + sext8(imm_s)) & MASK16
        elif op == OP_JAL:
            wb = (pc + 1) & MASK16
            c.next_pc = (pc + sext8(imm_i)) & MASK16
        elif op == OP_JALR:
            wb = (pc + 1) & MASK16
            c.next_pc = (a + sext8(imm_i)) & MASK16
        # OP_SYS 与保留的 1111：什么都不做

        if wb is not None:
            c.rd, c.wdata = rd, wb
            self.regs[rd] = wb
        self.pc = c.next_pc
        return c

    def run(self, cap=20000):
        """一直走到停机（含停机那一条）或 cap 条。"""
        for _ in range(cap):
            c = self.step()
            yield c
            if c.halt:
                return


def read_hex(path):
    """$readmemh 的子集：一行一个字，// 注释，不支持 @地址。"""
    words = []
    for line in open(path):
        line = line.split("//")[0].strip()
        if line:
            words.append(int(line, 16))
    return words


def main(argv):
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("prog")
    ap.add_argument("data", nargs="?")
    ap.add_argument("--trace", action="store_true")
    ap.add_argument("--cap", type=int, default=20000)
    a = ap.parse_args(argv)
    cpu = Iss(read_hex(a.prog), read_hex(a.data) if a.data else [])
    n, last = 0, None
    for c in cpu.run(a.cap):
        n += 1
        last = c
        if a.trace:
            print(c)
    print("%s after %d insts  R0=%04x R1=%04x R2=%04x R3=%04x" %
          ("HALT" if last and last.halt else "CAP", n, *cpu.regs))


if __name__ == "__main__":
    main(sys.argv[1:])
