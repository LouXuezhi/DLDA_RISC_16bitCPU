# DLDA_RISC_16bitCPU

16 位 RISC CPU，单周期（数据通路 + 控制单元），Verilog 实现。

电子科技大学格拉斯哥学院《数字逻辑设计及应用》课程设计。

*A 16-bit single-cycle RISC CPU (datapath + control unit).
Coursework for Digital Logic Design and
Applications, Glasgow College, UESTC.*

| 文件 File | 内容 Contents |
|---|---|
| [`doc/ISA.md`](doc/ISA.md) | 指令集规范 — instruction set specification |
| [`src/define_ISA.v`](src/define_ISA.v) | 操作码、funct 码、字段位置 — opcodes, funct codes, field positions |
| [`src/define_ctrl.v`](src/define_ctrl.v) | 控制信号编码、内存映射 — control encodings, memory map |
| [`testbench/`](testbench/) | 测试，以及怎么写一个 — tests, and how to write one |
| [`RULE.md`](RULE.md) | 本项目的规范，人和工具都适用 — conventions for anyone writing code here |



## 结构 · Structure

单周期：一个数据通路加一个控制单元，每条指令一个时钟，CPI = 1。

*Single-cycle: one datapath plus one control unit, one instruction per clock.*

```
pc ─► imem ─► inst ─┬─► control_unit ─► 控制字 control word
                    ├─► regfile ─┬─► branch_cmp ─► eq, lt ─► control_unit
                    │            └─► src_a/src_b mux ─► alu ─► dmem
                    └─► imm_ext                          │       │
            写回 mux write-back ◄── pc+1 ─── alu 结果 ────┴── 读出 ─┘
next_pc = pc+1 | pc+imm | alu 结果
```

| 模块 Module | 作用 Role |
|---|---|
| [`src/cpu_core.v`](src/cpu_core.v) | 顶层：只有连线，框图上每个方块是一个实例 |
| [`src/control_unit.v`](src/control_unit.v) | 译码：`opcode`/`funct` → 控制字 |
| [`src/pc_reg.v`](src/pc_reg.v) | PC 寄存器 |
| [`src/imem.v`](src/imem.v) [`src/dmem.v`](src/dmem.v) | 指令 / 数据存储，组合读 |
| [`src/regfile.v`](src/regfile.v) | R0–R3，两读一写 |
| [`src/imm_ext.v`](src/imm_ext.v) | 立即数展宽 |
| [`src/alu.v`](src/alu.v) | ALU，`alu_op` 即 `funct` |
| [`src/branch_cmp.v`](src/branch_cmp.v) | 分支比较：`eq`、有符号 `lt` |
| [`src/mux2.v`](src/mux2.v) [`src/mux3.v`](src/mux3.v) | ALU 两个输入的选择；写回和 next-PC 的选择 |
| [`src/adder.v`](src/adder.v) | `PC + 1`、`PC + imm` |

五级流水的版本在 `refine` / `main` 分支上。

*The 5-stage pipelined version lives on the `refine` / `main` branches.*

## 验证 · Verification

```sh
make verify                          # bench 全部程序 + 200 个随机程序，RTL 与 ISS 逐条比对
python3 verif/run.py --random 1000   # 随机程序更多
```

`testbench/tb_core.v` 只负责打印：每执行一条指令打一行 commit（PC、指令、下一条 PC、写了什么）。
判断全在 Python：`verif/run.py` 编译、运行，再拿 `verif/model/iss.py`（照 `doc/ISA.md` 写的
指令级模拟器）的输出逐行对比，第一处不同就报出来。

*`tb_core.v` only prints one commit line per instruction; `verif/run.py` compares it line by
line against the ISS in `verif/model/iss.py`.*

## 快速上手 · Quick start

```sh
iverilog -g2005 -Isrc -o run testbench/my_test.v src/*.v && ./run
```

`-Isrc` 是必需的 —— 每个源文件开头都 `` `include "define_ISA.v" ``。怎么写测试见
[`testbench/README.md`](testbench/README.md)。

*`-Isrc` is required: every source file includes the headers by name. See
[`testbench/README.md`](testbench/README.md) for how to write a test.*

