# 统一 benchmark · Unified benchmark

改微架构之前先跑一遍，改完再跑一遍，看两遍的差。

```sh
make bench-baseline     # 改之前：把当前数字存成 bench/baseline.csv
make bench              # 改之后：再跑一遍，「vs 基线」一列就是差
```

**答案错了就是 FAIL，性能变差不是** —— 退出码只看正确性，快慢留给人判断。一个算错了的核给出
的周期数没有意义。

## 核 · Kernels

| 核 | 动态指令 | 内容 |
|---|---|---|
| `alu` | 51 | 直线 ALU，无访存无分支，每条依赖前一条 |
| `fib` | 86 | 每圈一个必中分支，无访存 |
| `sumn` | 134 | 每圈一次 `LD` 紧跟着用 |
| `memcpy` | 131 | 每圈一读一写，套件里访存最密的 |
| `branchy` | 150 | 数据相关分支，每圈换方向 |
| `sum` | 22 | `doc/ISA.md` 的例子 |
| `br_stall` `jal_stall` | 6 / 5 | 流水线版的两个回归：`LD` 后紧跟分支、`ST` 后紧跟 `JAL` |
| `isa_alu` | 14 | 上面没用到的 `LUI` `ORI` `ANDI` `SLT` `SLTU` `NOR` `SRA` `SRL` |
| `isa_ctl` | 14 | `JALR` 返回、分支跳/不跳，以及三个必须是 NOP 的编码：`funct = 0`、保留 funct、保留操作码 `1111` |

源码是 `bench/prog/*.s`，用 `bench/asm.py` 汇编。`.hex` 已提交，所以**跑 benchmark 不需要
python**；只有改了 `.s` 才要 `make bench-asm`。

## 指标 · Metrics

跑到**停机**为止，不是跑固定周期数。停机就是 `JAL Rx, #0`，看成「`next_pc` 等于 `pc`」。

| 列 | 含义 |
|---|---|
| `cycles` | 放开复位到执行停机指令，之间的周期数（含停机那一拍） |
| `insts` | 执行的非零指令字数 |
| `cpi` | `cycles / insts`；单周期核恒为 1，只有程序里写了 `NOP` 才会大于 1 |
| `branches` `taken` | 分支指令数 / 其中跳了的 |
| `jumps` `loads` `stores` | `JAL`/`JALR`、`LD`、`ST` 的条数 |

`insts` 可以独立验算：`alu` 是 2 + 12×4 + 1 = 51，`fib` 是 4 + 20×4 + 2 = 86。

## 基线 · Baseline

`bench/baseline.csv` 是单周期核的数字。`bench/baseline_pipeline.csv` 是五级流水版
（`b121176`）的旧基线，`run.sh` 拿它的 `LATENCY = 1` 那几行算「vs 流水线」一列。

| 核 | 单周期 周期 | 流水线 周期 (lat=1) | 流水线 CPI |
|---|---|---|---|
| `alu` | 51 | 103 | 2.01 |
| `fib` | 86 | 211 | 2.45 |
| `sumn` | 134 | 331 | 2.47 |
| `memcpy` | 131 | 389 | 2.96 |
| `branchy` | 150 | 411 | 2.74 |
| `sum` | 22 | 51 | 2.31 |

周期数少了一半以上，但这不等于快了一半：单周期核的时钟周期要容纳整条 `LD` 路径，比流水线
的一级长得多。比较执行时间要乘上各自综合出来的周期。

## 加一个核 · Adding a kernel

1. 写 `bench/prog/<名字>.s`，末尾 `HALT Rx` —— **`Rx` 挑一个不查的**，`JAL Rx,#0` 每圈都写它。
   要放一个汇编器不认识的字（比如保留编码），写 `.WORD 0xHHHH`。
2. `make bench-asm`
3. 在 `bench/bench.list` 里加一行：名字、程序、数据（没有写 `-`）、周期上限、期望值。
4. **期望值照算法算，不要从 RTL 上抄。** 从 RTL 抄下来的期望值只能证明 RTL 等于它自己。
5. 加完之后把它该抓的东西故意弄坏一次，确认它真的 FAIL（`testbench/README.md` 那两个习惯）。

## 探针 · Probes

`bench/tb_bench.v` 顶上那一块 `wire` 是**唯一**引用设计内部信号的地方，改微架构时只需要改那里：

| 探针 | 引用 |
|---|---|
| 执行 / 分类 | `dut.inst` |
| 分支跳没跳 | `dut.pc_sel == PC_REL` |
| 停机检测 | `dut.pc_sel`、`dut.next_pc`、`dut.pc` |

探针在时钟**下降沿**采样：那时本周期的组合逻辑已经稳定，上升沿还没把它换成下一条。
