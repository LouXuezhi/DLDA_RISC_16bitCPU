# DLDA_RISC_16bitCPU

16 位 RISC CPU，五级流水，Verilog 实现，目标板 EES-331（Xilinx Zynq-7000 AP SoC）。

电子科技大学格拉斯哥学院《数字逻辑设计及应用》课程设计。

*A 16-bit RISC CPU with a 5-stage pipeline, written in Verilog for the EES-331
board (Xilinx Zynq-7000 AP SoC). Coursework for Digital Logic Design and
Applications, Glasgow College, UESTC.*

| 文件 File | 内容 Contents |
|---|---|
| [`doc/ISA.md`](doc/ISA.md) | 指令集规范 — instruction set specification |
| [`src/define_ISA.v`](src/define_ISA.v) | 操作码、funct 码、字段位置 — opcodes, funct codes, field positions |
| [`src/define_ctrl.v`](src/define_ctrl.v) | 暂停向量、内存映射 — stall vector, memory map |
| [`testbench/`](testbench/) | 测试，以及怎么写一个 — tests, and how to write one |
| [`RULE.md`](RULE.md) | 本项目的规范，人和工具都适用 — conventions for anyone writing code here |

## 设计公理 · Design axiom

**全零即什么都不发生。** 操作码 `0000` 什么都不做，所有控制信号高有效，流水线靠写零来
暂停和冲刷。详见 [`doc/ISA.md`](doc/ISA.md)。

*All zeros means nothing happens. Opcode `0000` does nothing, every control signal
is active high, and the pipeline stalls and flushes by writing zeros.*

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

## 约定 · Conventions

改代码前先把编辑器或 AI 工具指向 [`RULE.md`](RULE.md)。没有工具会自动加载它，这是故意的。

源码（`src/*.v`）的注释一律用英文：中文字符在部分 Vivado 版本的解析器里会因编码设置出问题。
文档（`doc/`、各 README）中文为主。

*Point your editor or coding agent at `RULE.md` before making changes — no tool
loads it automatically, by design. Comments in `src/*.v` stay English, because
non-ASCII characters in Verilog sources can trip Vivado's parser depending on
encoding settings. Documentation is Chinese-first.*

---

作者 Authors: Lou Xuezhi, Tan Xiangyun.
