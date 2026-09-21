`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  mux3 -- three-way multiplexer.  sel = 0, 1, 2 picks d0, d1, d2;
//  the unused code 3 also picks d0, so a zero select is always safe.
//=========================================================================

module mux3 #(
    parameter W = 16
) (
    input  wire [  1:0] sel,
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    input  wire [W-1:0] d2,
    output reg  [W-1:0] y
);

    always @(*) begin
        case (sel)
            2'd1:    y = d1;
            2'd2:    y = d2;
            default: y = d0;
        endcase
    end

endmodule
