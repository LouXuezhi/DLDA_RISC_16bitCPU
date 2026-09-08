# DLDA_RISC_16bitCPU

A 16-bit RISC CPU with a 5-stage pipeline, written in Verilog for the EES-331
board (Xilinx Zynq-7000 AP SoC).

Coursework for Digital Logic Design and Applications, Glasgow College, UESTC.

| | |
|---|---|
| [`doc/ISA.md`](doc/ISA.md) | instruction set specification |
| [`src/define_ISA.v`](src/define_ISA.v) | opcodes, funct codes, field positions |
| [`src/define_ctrl.v`](src/define_ctrl.v) | stall vector, memory map |
| [`testbench/`](testbench/) | tests for the core, and how to write one |
| [`RULE.md`](RULE.md) | conventions for anyone — human or tool — writing code here |

**Design axiom:** all zeros means nothing happens. Opcode `0000` does nothing,
every control signal is active high, and the pipeline stalls and flushes by
writing zeros. See `doc/ISA.md`.

Point your editor or coding agent at `RULE.md` before making changes.

Authors: Lou Xuezhi, Tan Xiangyun.
