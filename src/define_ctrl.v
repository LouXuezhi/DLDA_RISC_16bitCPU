`timescale 1ns/1ps
`ifndef DEFINE_CTRL_V
`define DEFINE_CTRL_V

//=========================================================================
//  class_cpu -- microarchitecture control encoding.
//  Not visible to the programmer.  Change freely; doc/ISA.md is unaffected.
//
//  Every control signal here is ACTIVE HIGH, so a zeroed pipeline register
//  is a bubble.  A bubble is this, not an instruction: nothing is ever
//  fetched or injected to create one.
//=========================================================================

//---- ALU operand 1.  Never an immediate, so no immediate input. --------
`define OP1_REG      2'b00           // R[Rs1], after forwarding
`define OP1_PC       2'b01           // JAL / JALR: the link value PC+1
`define OP1_ZERO     2'b10           // LI / LUI: nothing to add to

//---- ALU operand 2.  Never the PC, so one bit is enough. ---------------
`define OP2_REG      1'b0            // R[Rs2], after forwarding
`define OP2_IMM      1'b1

//---- immediate form.  Widening an 8-bit field to the 16-bit datapath ---
//     is not free: the wrong choice silently corrupts the high byte.
`define IMM_S8       3'b000          // sext(inst[7:0])   -- a signed offset
`define IMM_Z8       3'b001          // zext(inst[7:0])   -- a bit mask
`define IMM_U8       3'b010          // {inst[7:0], 8'h00}          -- LUI
`define IMM_SPLIT    3'b011          // sext({inst[11:10], inst[5:0]})
`define IMM_ONE      3'b100          // 16'd1  -- the +1 in the link value

//---- branch target select -----------------------------------------------
`define TGT_NONE     2'b00
`define TGT_PC_REL   2'b01           // PC + sext8(imm)     -- BEQ/BNE/BLT/BGE
`define TGT_ABS      2'b10           // {8'h00, inst[7:0]}  -- JAL
`define TGT_REG_REL  2'b11           // R[Rs1] + sext8(imm) -- JALR

//---- write-back source.  JAL/JALR link through the ALU, so 2-way. ------
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
