# 16-bit RISC ISA

`class_cpu` · 5-stage pipeline, IF · ID · EX · MEM · WB.
Encoding lives in [`src/define_ISA.v`](../src/define_ISA.v). This file is the spec;
if code and spec disagree, fix one of them in the same commit.

## Axiom — all zeros means nothing happens

| Zeroed | Means |
|---|---|
| `inst == 16'h0000` | opcode `0000` (SYS), funct `000000` → NOP |
| `alu_op == 6'b000000` | NOP, result discarded |
| `reg_we` `mem_we` `mem_re` `branch` | all active-high, so 0 is inert |
| any pipeline register after reset or flush | the bubble it should be |

Flush writes zeros into IF/ID; stall writes zeros into ID/EX. With this rule both
are correct by construction. It also means an unprogrammed block RAM — which
powers up as zeros — executes NOPs instead of garbage.

## State

| | Width | Count |
|---|---|---|
| Registers `R0`–`R3` | 16 bit | 4, none hardwired |
| PC | 8 bit | 1, next address is `PC + 1` |
| Instruction memory | 16 bit | 256 words |
| Data memory | 16 bit | 256 words |

Word-addressed: one address selects one 16-bit word. No alignment, no byte enable.

No register is hardwired to zero — four registers cannot spare one. `LI` and the
`MOV` idiom replace it.

## Formats

| | `[15:12]` | `[11:10]` | `[9:8]` | `[7:6]` | `[5:0]` |
|---|---|---|---|---|---|
| **R** | opcode | `Rd` | `Rs1` | `Rs2` | `funct` |
| **I** | opcode | `Rd` | `Rs1` | `imm[7:0]` spans both ||
| **S** | opcode | `f2` | `Rs1` | `Rs2` | `imm[5:0]` |

`f2` is `imm[7:6]` for `ST`, the condition code for `BR`. Same wiring either way.

`Rs1` is always `[9:8]` and `Rs2` always `[7:6]`, in every format. ID drives the
register-file read ports straight from the instruction word, so the read starts in
parallel with decode. The opcode only decides whether the returned value is used —
read always, decide later.

Consequences, both harmless: S-format has no `Rd` but `inst[11:10]` is still read
(`reg_we = 0`), and I-format has no `Rs2` but port 2 still reads `inst[7:6]`
(`re2 = 0`).

`ST` needs two registers *and* 8 bits of displacement, which does not fit below
`Rs2` — so the top 2 bits go in `f2`. Splitting the immediate is cheaper than
moving a register field, which would put a mux in front of the register file.

## Instructions

| Op | Fmt | Assembly | Meaning |
|---|---|---|---|
| `0000` | R | `NOP` | nothing |
| `0000` | R | `HALT` | freeze the PC until reset |
| `0001` | R | `<alu> Rd, Rs1, Rs2` | `Rd ← funct(R[Rs1], R[Rs2])` |
| `0010` | I | `ADDI Rd, Rs1, #imm8` | `Rd ← R[Rs1] + sext8(imm)` |
| `0011` | I | `ANDI Rd, Rs1, #imm8` | `Rd ← R[Rs1] & zext8(imm)` |
| `0100` | I | `ORI  Rd, Rs1, #imm8` | `Rd ← R[Rs1] \| zext8(imm)` |
| `0101` | I | `LI   Rd, #imm8` | `Rd ← sext8(imm)` |
| `0110` | I | `LUI  Rd, #imm8` | `Rd ← {imm, 8'h00}` |
| `0111` | I | `LD   Rd, imm8(Rs1)` | `Rd ← M[(R[Rs1] + sext8(imm))[7:0]]` |
| `1000` | S | `ST   Rs2, imm8(Rs1)` | `M[(R[Rs1] + sext8(imm))[7:0]] ← R[Rs2]` |
| `1001` | S | `B<cc> Rs1, Rs2, #imm6` | `if (cc) PC ← PC + sext6(imm)` |
| `1010` | I | `JAL  Rd, #addr8` | `Rd ← PC+1 ; PC ← imm8` |
| `1011` | I | `JALR Rd, imm8(Rs1)` | `Rd ← PC+1 ; PC ← (R[Rs1] + sext8(imm))[7:0]` |

Opcodes `1100`–`1111` are reserved.

* `ST`'s first register is a **source** — the data being stored. Nothing is written back.
* Addresses truncate to 8 bits. `LI R0,#0; ST R1,-1(R0)` writes address `0xFF`.
* Branches are relative to the branch itself, not to `PC+1`.
* `JAL` is absolute — 8 bits reach all 256 instruction words.
* `JALR` is the return instruction and the jump-table instruction.

### ALU funct

`funct` **is** the ALU control word, so R-type needs no control ROM. The immediate
forms synthesise the same codes, so EX holds one `case`.

| `funct` | | `funct` | | `funct` | |
|---|---|---|---|---|---|
| `000000` | *nop* | `000100` | `OR` | `001000` | `SLTU` |
| `000001` | `ADD` | `000101` | `XOR` | `001001` | `SLL` |
| `000010` | `SUB` | `000110` | `NOR` | `001010` | `SRL` |
| `000011` | `AND` | `000111` | `SLT` | `001011` | `SRA` |

`001100`–`111111` reserved. Shifts use `b[3:0]`.

### Branch conditions

`f2` = `00` `BEQ`, `01` `BNE`, `10` `BLT`, `11` `BGE` — all signed.
`BGT a,b` assembles as `BLT b,a`, `BLE a,b` as `BGE b,a`; the comparator reads both
operands symmetrically, so the swap is free.

Range is ±32 instructions. Further away, the assembler inverts and jumps:
`BLT R1,R2,far` → `BGE R1,R2,.skip` / `JAL R3,far` / `.skip:`.

Do not compare by testing the sign of `a − b`: it overflows, and `0x8000 − 0x0001`
= `0x7FFF` claims "positive". Use `(a[15] != b[15]) ? a[15] : borrow`.

## Decode

Fields come out unconditionally, before the opcode is looked at:

```verilog
wire [3:0] opcode = inst[15:12];
wire [1:0] rd     = inst[11:10];
wire [1:0] rs1    = inst[ 9: 8];
wire [1:0] rs2    = inst[ 7: 6];
wire [5:0] funct  = inst[ 5: 0];
wire [1:0] f2     = inst[11:10];
wire [7:0] imm_i  = inst[ 7: 0];
wire [5:0] imm_b  = inst[ 5: 0];
wire [7:0] imm_s  = {inst[11:10], inst[5:0]};
```

Then one `case (opcode)`:

| | `re1` | `re2` | `reg_we` | `alu_op` | `op1` | `op2` | `mem_re` | `mem_we` | `branch` |
|---|---|---|---|---|---|---|---|---|---|
| `SYS` | 0 | 0 | 0 | `NOP` | — | — | 0 | 0 | — |
| `ALU` | 1 | 1 | 1 | `funct` | `R[Rs1]` | `R[Rs2]` | 0 | 0 | — |
| `ADDI` | 1 | 0 | 1 | `ADD` | `R[Rs1]` | `sext8` | 0 | 0 | — |
| `ANDI` | 1 | 0 | 1 | `AND` | `R[Rs1]` | `zext8` | 0 | 0 | — |
| `ORI` | 1 | 0 | 1 | `OR` | `R[Rs1]` | `zext8` | 0 | 0 | — |
| `LI` | 0 | 0 | 1 | `ADD` | `0` | `sext8` | 0 | 0 | — |
| `LUI` | 0 | 0 | 1 | `ADD` | `0` | `{imm,8'h0}` | 0 | 0 | — |
| `LD` | 1 | 0 | 1 | `ADD` | `R[Rs1]` | `sext8` | **1** | 0 | — |
| `ST` | 1 | **1** | 0 | `ADD` | `R[Rs1]` | `sext8` | 0 | **1** | — |
| `BR` | 1 | 1 | 0 | `NOP` | — | — | 0 | 0 | `cc` |
| `JAL` | 0 | 0 | 1 | `ADD` | `PC` | `1` | 0 | 0 | always |
| `JALR` | **1** | 0 | 1 | `ADD` | `PC` | `1` | 0 | 0 | always |

1. `reg_we` is the only bit the register file cares about, so a junk `Rd` is harmless.
2. `re1`/`re2` drive **forwarding**, not the register file. A source is a hazard only
   if it is read — `ADDI` sets `re2 = 0`, so `inst[7:6]` never triggers a check.
3. `LD` is the only instruction whose write-back source is memory. That one bit is
   what the load-use detector looks at, one stage ahead.
4. `JAL`/`JALR` link through the ALU (`op1 = PC`, `op2 = 1`), so the write-back mux
   stays 2-way and `PC+1` is never carried down the pipeline as its own field.

`JALR` sets `re1 = 1` because its *target* needs `R[Rs1]`. That value goes to the
branch-target adder in ID, is forwarded like any other ID read, and a load feeding a
`JALR` is a load-use stall.

Branch target, one 8-bit adder with a mux on its inputs:

| | `a` | `b` |
|---|---|---|
| `BR` | `PC` | `sext6(imm6)` |
| `JAL` | `8'h0` | `imm8` |
| `JALR` | `R[Rs1][7:0]` forwarded | `sext8(imm8)` |

## Hazards

Per source register, newest producer first:

```verilog
if      (re && ex_is_load && ex_waddr == addr)  stallreq = 1;   // load-use
else if (re && ex_we      && ex_waddr == addr)  opv = ex_reg_wdata;
else if (re && mem_we     && mem_waddr == addr) opv = mem_reg_wdata;
else if (re)                                    opv = reg_data;
else                                            opv = imm;
```

`re` gates the whole chain, so `LI`, `LUI` and `JAL` never stall. Load-use is the one
case forwarding cannot cover: one bubble. A taken branch, resolved in ID, kills one
instruction; not-taken costs nothing.

## Pseudo-instructions

| Written | Assembles to | Words |
|---|---|---|
| `NOP` | `0x0000` | 1 |
| `MOV  Rd, Rs` | `ADDI Rd, Rs, #0` | 1 |
| `NOT  Rd, Rs` | `NOR  Rd, Rs, Rs` | 1 |
| `NEG  Rd, Rs` | `NOR Rd,Rs,Rs` ; `ADDI Rd,Rd,#1` | 2 |
| `J    addr` | `JAL Rx, addr`, result discarded | 1 |
| `RET  Rlink` | `JALR Rx, 0(Rlink)`, result discarded | 1 |
| `LI16 Rd, #imm16` | `LUI Rd,#hi` ; `ORI Rd,Rd,#lo` | 2 |
| `BGT` `BLE` | operand swap | 1 |

With four registers a workable convention is `R3` as link and scratch, `R0`–`R2` as data.

## Example

Sum `M[0..3]`, show the total on the LEDs, halt.

```
        LI   R0, #0          ; i = 0
        LI   R1, #0          ; sum = 0
        LI   R3, #4          ; limit
loop:   LD   R2, 0(R0)       ; v = M[i]
        ADD  R1, R1, R2      ; sum += v
        ADDI R0, R0, #1      ; i++
        BLT  R0, R3, loop    ; while (i < 4)
        LI   R0, #0
        ST   R1, -1(R0)      ; M[0xFF] = sum  ->  LEDs
        HALT
```

| Addr | Bit fields | Hex |
|---|---|---|
| 0 | `0101 00 00 00000000` | `5000` |
| 1 | `0101 01 00 00000000` | `5400` |
| 2 | `0101 11 00 00000100` | `5C04` |
| 3 | `0111 10 00 00000000` | `7800` |
| 4 | `0001 01 01 10 000001` | `1581` |
| 5 | `0010 00 00 00000001` | `2001` |
| 6 | `1001 10 00 11 111101` | `98FD` |
| 7 | `0101 00 00 00000000` | `5000` |
| 8 | `1000 11 00 01 111111` | `8C7F` |
| 9 | `0000 00 00 00 000001` | `0001` |

The branch targets `6 + (−3) = 3`. The store's displacement `−1` splits as `f2 = 11`,
`imm6 = 111111`, rejoins to `0xFF`, and added to `R0 = 0` addresses the LED port.

Per iteration: `LD R2` → `ADD` is a load-use, one bubble; `ADDI R0` → `BLT` forwards
from EX with zero bubbles; a taken `BLT` kills one instruction. Four instructions,
six cycles.

## Limits

1. **Four registers.** Anything with more than three live values spills to memory.
   Widening the register fields to 3 bits would take 3 bits from every immediate —
   a different ISA, not a parameter change.
2. **Branch range ±32.** Beyond that, invert-and-jump: 2 words and one extra taken branch.
3. **No unsigned branch.** `SLTU` computes the comparison into a register; there is no
   `BLTU`. Fine while addresses and counters stay under 32768.
4. **No shift-immediate.** `SLL Rd,Rs,Rt` needs the amount in a register — one `LI` and
   one register. The alternative was a sub-encoding inside the immediate field, which
   cost more in decode irregularity than it saved.
5. **No byte addressing.** Byte arrays waste half of each word. Opcode `1100` is the
   natural home for `LB`/`SB`.
6. **ID is the longest stage.** Register read, forwarding mux, comparator and branch
   adder all sit there, and the forwarded value is combinational out of the ALU:
   `ID/EX → ALU → mux → ID/EX`. If 100 MHz fails, move branch resolution to EX and pay
   a second killed instruction.

## References

[1] Z. Fan, "RISC-V-CPU: a five-stage pipelined RISC-V CPU in Verilog HDL," *GitHub*,
2018. [Online]. Available: https://github.com/Evensgn/RISC-V-CPU

[2] A. Waterman and K. Asanović, Eds., *The RISC-V Instruction Set Manual, Volume I:
Unprivileged ISA*, document version 20191213, RISC-V Foundation, Dec. 2019.
