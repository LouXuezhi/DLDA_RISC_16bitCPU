`timescale 1ns / 1ps
`ifndef DEFINE_CTRL_V
`define DEFINE_CTRL_V

//=========================================================================
//  class_cpu -- microarchitecture control encoding.
//  Not visible to the programmer.  Change freely; doc/ISA.md is unaffected.
//
//  Every control signal here is ACTIVE HIGH, so a zeroed pipeline register
//  is a bubble.  A bubble is this, not an instruction: nothing is ever
//  fetched or injected to create one.
//
//  There are no operand-mux, immediate-form or write-back selects here.
//  ID does not emit selects at all: it emits the widened 16-bit value
//  itself on imm1/imm2/mem_offset, and re1/re2 double as the operand mux
//  (read a register -> use it, after forwarding; do not -> use the
//  immediate).  That drops an immediate generator and its select lines
//  from EX.  See the Decode section of doc/ISA.md.
//=========================================================================

//---- stall vector, one bit per stage plus the PC ------------------------
`define STALLBUS_LEN 5:0
`define STALL_PC 0
`define STALL_IF 1
`define STALL_ID 2
`define STALL_EX 3
`define STALL_MEM 4
`define STALL_WB 5
`define NOSTALL 6'b000000

//---- data-side memory map.  Decoded in cpu_top.v, not in the core.  The
//     data address truncates to 8 bits (`DATAADDRBUS_LEN), which is what
//     puts these two ports within reach of a small negative offset:
//     `LI R0,#0; ST R1,-1(R0)` writes the LED port.
`define MMIO_SW 8'hFE           // read : {8'h00, sw[7:0]}
`define MMIO_LED 8'hFF           // write: led[7:0] <= wdata[7:0]

`endif
