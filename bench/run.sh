#!/bin/sh
# 跑 bench/bench.list 里的每个核，出一张 CSV。
#
#   bench/run.sh                    跑一遍，和 bench/baseline.csv 比
#   bench/run.sh -o out.csv         结果另存
#   bench/run.sh -b                 把这次的结果存成新的 baseline.csv
#   bench/run.sh -q                 只出 CSV，不打表
#
# 表里还有一列「vs 流水线」：和 bench/baseline_pipeline.csv 里五级流水版
# （LATENCY = 1）的周期数比。
#
# 退出码：有核算错答案或者没停机就是 1。性能变差不算失败 —— 那是给人看的。
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

OUT=""
BASELINE=bench/baseline.csv
PIPELINE=bench/baseline_pipeline.csv
SAVE=0
QUIET=0

while [ $# -gt 0 ]; do
    case $1 in
        -o) OUT=$2; shift 2 ;;
        -b) SAVE=1; shift ;;
        -q) QUIET=1; shift ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "不认识的参数: $1" >&2; exit 2 ;;
    esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

HEADER='bench,status,cycles,insts,cpi,branches,taken,jumps,loads,stores'
echo "$HEADER" > "$TMP/out.csv"

iverilog -g2005 -Isrc -o "$TMP/sim" bench/tb_bench.v src/*.v 2>&1 \
    | grep -v "Not enough words" || true

grep -v '^[[:space:]]*#' bench/bench.list | grep -v '^[[:space:]]*$' |
while read -r name prog data cap expects; do
    [ -n "$name" ] || continue
    dataarg=""
    [ "$data" = "-" ] || dataarg="+data=$data"
    # shellcheck disable=SC2086
    "$TMP/sim" +name="$name" +prog="$prog" $dataarg +cap="$cap" $expects \
        > "$TMP/log" 2>&1 || true
    grep -v "Not enough words" "$TMP/log" | grep -v '^CSV,' \
        | sed "s/^/  [$name] /" >&2
    if grep -q '^CSV,' "$TMP/log"; then
        grep '^CSV,' "$TMP/log" | sed 's/^CSV,//' >> "$TMP/out.csv"
    else
        echo "$name,CRASH,0,0,0.00,0,0,0,0,0" >> "$TMP/out.csv"
    fi
done

passes=$(grep -c ',PASS,' "$TMP/out.csv" || true)
total=$(($(wc -l < "$TMP/out.csv") - 1))
bad=$((total - passes))

[ -z "$OUT" ] || cp "$TMP/out.csv" "$OUT"
[ "$SAVE" -eq 0 ] || { cp "$TMP/out.csv" "$BASELINE"; echo "写入 $BASELINE" >&2; }

if [ "$QUIET" -eq 1 ]; then
    cat "$TMP/out.csv"
else
    echo
    awk -F, -v base="$BASELINE" -v pipe="$PIPELINE" '
    function pct(n, o) { return o == 0 ? 0 : (n - o) * 100.0 / o }
    BEGIN {
        while ((getline line < base) > 0) {
            split(line, f, ",")
            if (f[1] != "bench") bcyc[f[1]] = f[3]
        }
        # 流水线基线的列是 bench,latency,status,cycles,...
        while ((getline line < pipe) > 0) {
            split(line, f, ",")
            if (f[1] != "bench" && f[2] == 1) pcyc[f[1]] = f[4]
        }
        fmt = "%-10s %-8s %7s %6s %5s %6s %6s %6s %8s %10s\n"
        printf fmt, "核", "结果", "周期", "指令", "CPI", "分支", "跳了", "访存", "vs 基线", "vs 流水线"
        printf "%s\n", "-------------------------------------------------------------------------------"
    }
    NR == 1 { next }
    {
        d = "-"; p = "-"
        if ($1 in bcyc) d = sprintf("%+.1f%%", pct($3, bcyc[$1]))
        if ($1 in pcyc) p = sprintf("%+.1f%%", pct($3, pcyc[$1]))
        printf "%-10s %-8s %7s %6s %5s %6s %6s %6s %8s %10s\n",
               $1, $2, $3, $4, $5, $6, $7, $9 + $10, d, p
    }' "$TMP/out.csv"
    echo
    if [ "$bad" -eq 0 ]; then
        echo "$total 项全部 PASS"
    else
        echo "$bad/$total 项失败"
    fi
fi

[ "$bad" -eq 0 ] || exit 1
