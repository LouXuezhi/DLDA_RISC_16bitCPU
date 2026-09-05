# DLDA_RISC_16bitCPU

A 16-bit RISC CPU with a 5-stage pipeline, written in Verilog for the EES-331
board (Xilinx Zynq-7000 AP SoC).

Coursework for Digital Logic Design and Applications, Glasgow College, UESTC.

| | |
|---|---|
| [`doc/ISA.md`](doc/ISA.md) | instruction set specification |
| [`src/define_ISA.v`](src/define_ISA.v) | opcodes, funct codes, field positions |
| [`src/define_ctrl.v`](src/define_ctrl.v) | mux selects, stall vector, memory map |
| [`AGENTS.md`](AGENTS.md) | conventions for anyone — human or tool — writing code here |

**Design axiom:** all zeros means nothing happens. `16'h0000` is a NOP, every
control signal is active high, and the pipeline stalls and flushes by writing
zeros. See `doc/ISA.md`.

Authors: Lou Xuezhi, Tan Xiangyun.
