#!/bin/sh
# Build the core and run every program in tb/prog against its expectations.
# Usage: tb/run.sh [iverilog]        -- from the repository root.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

iverilog -g2005 -Isrc -o "$OUT/run" tb/tb_cpu_core.v src/*.v
iverilog -g2005 -Isrc -Ptb_cpu_core.LATENCY=4 -o "$OUT/slow" tb/tb_cpu_core.v src/*.v

fails=0
run() {
    name=$1
    bin=$2
    shift 2
    printf '\n=== %s ===\n' "$name"
    if "$OUT/$bin" "$@" | grep -v "^WARNING:.*Not enough words" | tee "$OUT/log"; then :; fi
    if ! grep -q '^PASS' "$OUT/log"; then
        fails=$((fails + 1))
    fi
}

# sum: the doc's worked example.  1+2+3+4 = 10, and the store must land on
# 0xFF -- that address only exists because the data address truncates.
run sum        run +prog=tb/prog/sum.hex +data=tb/prog/sum.data.hex \
               +cycles=120 +r0=0000 +r1=000a +m=ff:000a

# The same program with a slow cache: the result must not change.
run sum-slow   slow +prog=tb/prog/sum.hex +data=tb/prog/sum.data.hex \
               +cycles=400 +r1=000a +m=ff:000a

run logic      run +prog=tb/prog/logic.hex \
               +cycles=60 +r0=abcd +r1=0006 +r2=000d +r3=5432

run shift      run +prog=tb/prog/shift.hex \
               +cycles=60 +r0=fff8 +r2=fffe +r3=3ffe

run branch     run +prog=tb/prog/branch.hex \
               +cycles=200 +r0=0005 +r1=0005 +r2=0011 +r3=000c

run loaduse    run +prog=tb/prog/loaduse.hex +data=tb/prog/loaduse.data.hex \
               +cycles=80 +r1=0007 +r2=000e +r3=000f +m=05:000f

printf '\n'
if [ "$fails" -eq 0 ]; then
    echo "all programs PASS"
else
    echo "$fails program(s) FAILED"
    exit 1
fi
