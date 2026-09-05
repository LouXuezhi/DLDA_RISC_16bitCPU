`timescale 1ns/1ps
`ifndef DEFINE_CTRL_V
`define DEFINE_CTRL_V

//=========================================================================
//  class_cpu -- microarchitecture control encoding.
//  Not visible to the programmer.  Change freely; doc/ISA.md is unaffected.
//
//  Every control signal here is ACTIVE HIGH, so a zeroed pipeline register
//  is a bubble.  Keep it that way.
//=========================================================================

//---- ALU operand 1 select -----------------------------------------------
`define OP1_REG      2'b00           // R[Rs1], after forwarding
`define OP1_PC       2'b01           // JAL / JALR link value
`define OP1_ZERO     2'b10           // LI / LUI

//---- ALU operand 2 select -----------------------------------------------
`define OP2_REG      2'b00           // R[Rs2], after forwarding
`define OP2_IMM      2'b01
`define OP2_ONE      2'b10           // JAL / JALR link value

//---- immediate form -----------------------------------------------------
`define IMM_S8       3'b000          // sext(inst[7:0])
`define IMM_Z8       3'b001          // zext(inst[7:0])
`define IMM_U8       3'b010          // {inst[7:0], 8'h00}          -- LUI
`define IMM_ST       3'b011          // sext({inst[11:10], inst[5:0]})
`define IMM_BR       3'b100          // sext(inst[5:0])

//---- branch target select -----------------------------------------------
`define TGT_NONE     2'b00
`define TGT_PC_REL   2'b01           // PC + sext6(imm)             -- BR
`define TGT_ABS      2'b10           // {8'h00, imm8}               -- JAL
`define TGT_REG_REL  2'b11           // R[Rs1] + sext8(imm)         -- JALR

//---- write-back source.  JAL/JALR link through the ALU, so 2-way. -------
`define WB_ALU       1'b0
`define WB_MEM       1'b1

//---- stall vector, one bit per stage plus the PC ------------------------
`define StallBus      5:0
`define STALL_PC      0
`define STALL_IF      1
`define STALL_ID      2
`define STALL_EX      3
`define STALL_MEM     4
`define STALL_WB      5
`define NoStall      6'b000000

//---- data-side memory map.  Decoded in cpu_top.v, not in the core. ------
`define MMIO_SW      8'hFE           // read : {8'h00, sw[7:0]}
`define MMIO_LED     8'hFF           // write: led[7:0] <= wdata[7:0]

`endif
