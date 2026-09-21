`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  mux2 -- two-way multiplexer.  sel = 0 picks d0.
//=========================================================================

module mux2 #(
    parameter W = 16
) (
    input  wire         sel,
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    output wire [W-1:0] y
);

    assign y = sel ? d1 : d0;

endmodule
