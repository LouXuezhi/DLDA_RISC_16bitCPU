#!/usr/bin/env python3
"""拿 ISS 跑 bench/bench.list 的每一行，对它手算的期望值。

期望值是手算的，ISS 是照 ISA 独立写的：两者对上，说明 ISS 可以当参考模型。
    python3 verif/model/check_bench.py
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from iss import Iss, read_hex  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
fails = 0
for line in open(os.path.join(ROOT, "bench", "bench.list")):
    line = line.split("#")[0].split()
    if not line:
        continue
    name, prog, data, cap, *exp = line
    cpu = Iss(read_hex(os.path.join(ROOT, prog)),
              read_hex(os.path.join(ROOT, data)) if data != "-" else [])
    commits = list(cpu.run(int(cap)))
    bad = [] if commits and commits[-1].halt else ["没停机"]
    for e in exp:
        k, v = e.lstrip("+").split("=")
        if k[0] == "r":
            got, want = cpu.regs[int(k[1])], int(v, 16)
            if got != want:
                bad.append("R%s=%04x 期望 %s" % (k[1], got, v))
        else:
            addr, want = (int(x, 16) for x in v.split(":"))
            if cpu.dmem[addr] != want:
                bad.append("M[%02x]=%04x 期望 %04x" % (addr, cpu.dmem[addr], want))
    fails += bool(bad)
    print("%-10s %-5s %4d 条  %s" % (name, "FAIL" if bad else "PASS", len(commits), "; ".join(bad)))
sys.exit(1 if fails else 0)
