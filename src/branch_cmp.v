`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  branch_cmp -- compare the two register operands for the branches.
//
//  Two flags cover all four branch opcodes: BEQ = eq, BNE = !eq,
//  BLT = lt, BGE = !lt.  The control unit turns them into the PC select.
//
//  lt is a signed compare.  Do not take it from the sign of a - b: that
//  overflows (0x8000 - 0x0001 = 0x7FFF, "positive").
//=========================================================================

module branch_cmp (
    input  wire [`REGBUS_LEN] a,
    input  wire [`REGBUS_LEN] b,
    output wire               eq,
    output wire               lt
);

    assign eq = (a == b);
    assign lt = ($signed(a) < $signed(b));

endmodule
