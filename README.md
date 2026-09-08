# DLDA_RISC_16bitCPU

16 位 RISC CPU，五级流水，Verilog 实现。

电子科技大学格拉斯哥学院《数字逻辑设计及应用》课程设计。

*A 16-bit RISC CPU with a 5-stage pipeline.
board (Xilinx Zynq-7000 AP SoC). Coursework for Digital Logic Design and
Applications, Glasgow College, UESTC.*

| 文件 File | 内容 Contents |
|---|---|
| [`doc/ISA.md`](doc/ISA.md) | 指令集规范 — instruction set specification |
| [`src/define_ISA.v`](src/define_ISA.v) | 操作码、funct 码、字段位置 — opcodes, funct codes, field positions |
| [`src/define_ctrl.v`](src/define_ctrl.v) | 暂停向量、内存映射 — stall vector, memory map |
| [`testbench/`](testbench/) | 测试，以及怎么写一个 — tests, and how to write one |
| [`RULE.md`](RULE.md) | 本项目的规范，人和工具都适用 — conventions for anyone writing code here |



## 流水线 · Pipeline

```
IF → IF/ID → ID → ID/EX → EX → EX/MEM → MEM → MEM/WB → 寄存器堆 regfile
```

分支在 ID 级解析（比较器 + 目标加法器），前递也在 ID 级；`src/cpu_core.v` 把这些连成
一个核，`src/cache.v` 是指令和数据存储的替身。

*Branches resolve in ID, and so does forwarding. `src/cpu_core.v` wires the stages
into one core; `src/cache.v` stands in for instruction and data memory.*

## 快速上手 · Quick start

```sh
iverilog -g2005 -Isrc -o run testbench/my_test.v src/*.v && ./run
```

`-Isrc` 是必需的 —— 每个源文件开头都 `` `include "define_ISA.v" ``。怎么写测试见
[`testbench/README.md`](testbench/README.md)。

*`-Isrc` is required: every source file includes the headers by name. See
[`testbench/README.md`](testbench/README.md) for how to write a test.*

