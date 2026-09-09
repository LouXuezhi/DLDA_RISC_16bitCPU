#!/bin/sh
# 跑 bench/bench.list 里的每个核，每个 LATENCY 各跑一遍，出一张 CSV。
#
#   bench/run.sh                    跑一遍，和 bench/baseline.csv 比
#   bench/run.sh -o out.csv         结果另存
#   bench/run.sh -l 1,2,4           换一组 cache 延迟（默认 1,2,4）
#   bench/run.sh -b                 把这次的结果存成新的 baseline.csv
#   bench/run.sh -q                 只出 CSV，不打表
#
# 退出码：有核算错答案或者没停机就是 1。性能变差不算失败 —— 那是给人看的。
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

LATENCIES=1,2,4
OUT=""
BASELINE=bench/baseline.csv
SAVE=0
QUIET=0

while [ $# -gt 0 ]; do
    case $1 in
        -l) LATENCIES=$2; shift 2 ;;
        -o) OUT=$2; shift 2 ;;
        -b) SAVE=1; shift ;;
        -q) QUIET=1; shift ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "不认识的参数: $1" >&2; exit 2 ;;
    esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

HEADER='bench,latency,status,cycles,insts,cpi,stall_if,stall_id,stall_ex,stall_mem,luse,br_wait,branches,taken,jumps,loads,stores'
echo "$HEADER" > "$TMP/out.csv"

fails=0
for lat in $(echo "$LATENCIES" | tr ',' ' '); do
    # 每个延迟编译一个二进制 —— LATENCY 是设计的参数，不是运行时开关。
    iverilog -g2005 -Isrc -Ptb_bench.LATENCY="$lat" -o "$TMP/sim.$lat" \
             bench/tb_bench.v src/*.v 2>&1 | grep -v "Not enough words" || true

    grep -v '^[[:space:]]*#' bench/bench.list | grep -v '^[[:space:]]*$' |
    while read -r name prog data cap expects; do
        [ -n "$name" ] || continue
        dataarg=""
        [ "$data" = "-" ] || dataarg="+data=$data"
        # shellcheck disable=SC2086
        "$TMP/sim.$lat" +name="$name" +prog="$prog" $dataarg +cap="$cap" $expects \
            > "$TMP/log" 2>&1 || true
        grep -v "Not enough words" "$TMP/log" | grep -v '^CSV,' \
            | sed "s/^/  [$name lat=$lat] /" >&2
        if grep -q '^CSV,' "$TMP/log"; then
            grep '^CSV,' "$TMP/log" | sed 's/^CSV,//' >> "$TMP/out.csv"
        else
            echo "$name,$lat,CRASH,0,0,0.00,0,0,0,0,0,0,0,0,0,0,0" >> "$TMP/out.csv"
        fi
    done
done

# 上面的循环在管道里跑，fails 出不来 —— 直接从结果里数。
fails=$(grep -c ',PASS,' "$TMP/out.csv" || true)
total=$(($(wc -l < "$TMP/out.csv") - 1))
bad=$((total - fails))

[ -z "$OUT" ] || cp "$TMP/out.csv" "$OUT"
[ "$SAVE" -eq 0 ] || { cp "$TMP/out.csv" "$BASELINE"; echo "写入 $BASELINE" >&2; }

if [ "$QUIET" -eq 1 ]; then
    cat "$TMP/out.csv"
else
    echo
    awk -F, -v base="$BASELINE" '
    function pct(n, o) { return o == 0 ? 0 : (n - o) * 100.0 / o }
    BEGIN {
        haveb = 0
        while ((getline line < base) > 0) {
            split(line, f, ",")
            if (f[1] == "bench") continue
            bcyc[f[1] "," f[2]] = f[4]; bcpi[f[1] "," f[2]] = f[6]; haveb = 1
        }
        fmt = "%-9s %4s %-8s %8s %7s %6s %8s %8s %8s %8s %7s\n"
        printf fmt, "核", "lat", "结果", "周期", "指令", "CPI", "取指阻塞", "load-use", "访存阻塞", "等改向", "vs 基线"
        printf "%s\n", "----------------------------------------------------------------------------------------------"
    }
    NR == 1 { next }
    {
        d = "-"
        k = $1 "," $2
        if (haveb && (k in bcyc)) d = sprintf("%+.1f%%", pct($4, bcyc[k]))
        printf "%-9s %4s %-8s %8s %7s %6s %8s %8s %8s %8s %7s\n",
               $1, $2, $3, $4, $5, $6, $7, $11, $10, $12, d
    }
    END {
        if (!haveb) print "\n（没有 " base "，所以没有对比列。-b 存一份。）"
    }' "$TMP/out.csv"
    echo
    if [ "$bad" -eq 0 ]; then
        echo "$total 项全部 PASS"
    else
        echo "$bad/$total 项失败"
    fi
fi

[ "$bad" -eq 0 ] || exit 1
