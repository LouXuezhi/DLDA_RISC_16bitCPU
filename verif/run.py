#!/usr/bin/env python3
"""把 RTL 和 ISS 逐条指令对比。Verilog 只打印，判断全在这里。

    python3 verif/run.py                  bench/bench.list 里的全部程序
    python3 verif/run.py --random 200     再加 200 个随机程序
    python3 verif/run.py --seed 7 ...     换随机种子（失败时打印种子，可复现）

失败的随机程序存到 build/verif/，拿 --trace 那条命令就能单独重跑。
"""
import argparse
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "model"))
from iss import Iss, read_hex  # noqa: E402

BUILD = os.path.join(ROOT, "build", "verif")
SIM = os.path.join(BUILD, "sim")


def build():
    os.makedirs(BUILD, exist_ok=True)
    src = sorted(os.path.join(ROOT, "src", f) for f in os.listdir(os.path.join(ROOT, "src"))
                 if f.endswith(".v"))
    subprocess.run(["iverilog", "-g2005", "-I", os.path.join(ROOT, "src"), "-o", SIM,
                    os.path.join(ROOT, "testbench", "tb_core.v")] + src, check=True)


def rtl_trace(prog, data, cap):
    args = [SIM, "+prog=" + prog, "+cap=%d" % cap] + (["+data=" + data] if data else [])
    out = subprocess.run(args, capture_output=True, text=True, cwd=ROOT).stdout
    return [l[2:] for l in out.splitlines() if l.startswith("C ")]


def iss_trace(prog, data, cap):
    cpu = Iss(read_hex(prog), read_hex(data) if data else [])
    return [str(c) for c in cpu.run(cap)]


def check(name, prog, data, cap):
    got, want = rtl_trace(prog, data, cap), iss_trace(prog, data, cap)
    for i, (g, w) in enumerate(zip(got, want)):
        if g != w:
            print("FAIL %-12s 第 %d 条\n  RTL %s\n  ISS %s" % (name, i, g, w))
            return False
    if len(got) != len(want):
        print("FAIL %-12s 条数 RTL %d / ISS %d" % (name, len(got), len(want)))
        return False
    print("ok   %-12s %4d 条" % (name, len(want)))
    return True


#---- 随机程序 -----------------------------------------------------------
#  只往前跳，所以一定停机；先用 LI 把四个寄存器都写一遍，避免读到 x。
R_FUNCT = list(range(1, 12))


def random_program(rng, n=60):
    words = [(5 << 12) | (r << 10) | rng.randrange(256) for r in range(4)]   # LI R0..R3
    while len(words) < n:
        here, left = len(words), n - len(words)
        rd, rs1, rs2 = rng.randrange(4), rng.randrange(4), rng.randrange(4)
        imm = rng.randrange(256)
        k = rng.random()
        if k < 0.35:                                  # R 型
            w = (1 << 12) | (rd << 10) | (rs1 << 8) | (rs2 << 6) | rng.choice(R_FUNCT)
        elif k < 0.60:                                # ADDI ANDI ORI LI LUI
            w = (rng.choice([2, 3, 4, 5, 6]) << 12) | (rd << 10) | (rs1 << 8) | imm
        elif k < 0.72:                                # LD
            w = (7 << 12) | (rd << 10) | (rs1 << 8) | imm
        elif k < 0.84:                                # ST
            w = (8 << 12) | ((imm >> 6) << 10) | (rs1 << 8) | (rs2 << 6) | (imm & 0x3F)
        elif k < 0.96 and left > 2:                   # 分支，只往前
            off = rng.randrange(1, min(left, 20))
            w = (rng.choice([9, 10, 11, 12]) << 12) | ((off >> 6) << 10) | (rs1 << 8) \
                | (rs2 << 6) | (off & 0x3F)
        elif left > 2:                                # JAL，只往前
            off = rng.randrange(1, min(left, 20))
            w = (13 << 12) | (rd << 10) | off
        else:
            w = 0
        words.append(w)
    words.append((13 << 12) | (rng.randrange(4) << 10))                      # HALT
    return words


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--random", type=int, default=0)
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args()

    build()
    fails = 0
    for line in open(os.path.join(ROOT, "bench", "bench.list")):
        f = line.split("#")[0].split()
        if f:
            name, prog, data, cap = f[:4]
            fails += not check(name, os.path.join(ROOT, prog),
                               None if data == "-" else os.path.join(ROOT, data), int(cap))

    rng = random.Random(a.seed)
    for i in range(a.random):
        path = os.path.join(BUILD, "rand_%d_%d.hex" % (a.seed, i))
        with open(path, "w") as fh:
            fh.write("\n".join("%04X" % w for w in random_program(rng)) + "\n")
        if check("rand%d" % i, path, None, 200):
            os.remove(path)
        else:
            fails += 1
            print("     重跑: build/verif/sim +prog=%s" % path)

    print("\n%s" % ("全部一致" if fails == 0 else "%d 个不一致" % fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
