`timescale 1ns / 1ps
`ifndef DEFINE_CTRL_V
`define DEFINE_CTRL_V

//=========================================================================
//  class_cpu -- microarchitecture control encoding (single-cycle core).
//  Not visible to the programmer.  Change freely; doc/ISA.md is unaffected.
//
//  Every select below has its most common, inert choice at 0, and every
//  enable is active high.  So an all-zero control word -- what the control
//  unit emits for NOP and for the reserved opcode -- writes nothing and
//  steps the PC by one.  That is the zeros axiom, see doc/ISA.md.
//=========================================================================

//---- word-addressed: the next instruction is always PC + 1 --------------
`define PC_STEP 16'd1

//---- the 3-way selects below feed mux3.v, which picks d0/d1/d2 for codes
//     0/1/2 in the order the codes are listed.

//---- ALU operand A: a register, or zero (LI, LUI) ----------------------
`define SRCA_REG 1'b0
`define SRCA_ZERO 1'b1

//---- ALU operand B: a register, or the widened immediate --------------
`define SRCB_REG 1'b0
`define SRCB_IMM 1'b1

//---- how the 8-bit immediate is widened to 16 bits ---------------------
`define IMMSELBUS_LEN 1:0
`define IMM_SEXT_I 2'b00           // {{8{imm_i[7]}}, imm_i}  ADDI LI LD JAL JALR
`define IMM_ZEXT_I 2'b01           // {8'h00, imm_i}          ANDI ORI
`define IMM_LUI_I 2'b10           // {imm_i, 8'h00}          LUI
`define IMM_SEXT_S 2'b11           // {{8{imm_s[7]}}, imm_s}  ST, branches

//---- what writes back to the register file -----------------------------
`define WBSELBUS_LEN 1:0
`define WB_ALU 2'b00           // ALU result
`define WB_MEM 2'b01           // data memory (LD)
`define WB_PC1 2'b10           // PC + 1, the link value (JAL JALR)
//                   2'b11     reserved

//---- where the next PC comes from --------------------------------------
`define PCSELBUS_LEN 1:0
`define PC_PLUS1 2'b00           // PC + 1
`define PC_REL 2'b01           // PC + imm  -- taken branch, JAL
`define PC_ALU 2'b10           // ALU result, R[Rs1] + sext8(imm) -- JALR
//                   2'b11     reserved

//---- data-side memory map.  Decoded in cpu_top.v, not in the core.  The
//     data address truncates to 8 bits (`DATAADDRBUS_LEN), which is what
//     puts these two ports within reach of a small negative offset:
//     `LI R0,#0; ST R1,-1(R0)` writes the LED port.
`define MMIO_SW 8'hFE           // read : {8'h00, sw[7:0]}
`define MMIO_LED 8'hFF           // write: led[7:0] <= wdata[7:0]

`endif
