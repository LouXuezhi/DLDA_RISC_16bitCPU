`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  adder -- 16-bit adder, carry out discarded.  Used twice, for PC + 1
//  and for PC + imm; the ALU has its own.
//=========================================================================

module adder (
    input  wire [`REGBUS_LEN] a,
    input  wire [`REGBUS_LEN] b,
    output wire [`REGBUS_LEN] y
);

    assign y = a + b;

endmodule
