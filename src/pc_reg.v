`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  pc_reg -- the program counter.  The only register the datapath has
//  besides the register file: it takes next_pc on every edge and resets
//  to address 0.
//=========================================================================

module pc_reg (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [`INSTADDRBUS_LEN] next_pc,
    output reg  [`INSTADDRBUS_LEN] pc
);

    always @(posedge clk) begin
        if (rst) begin
            pc <= `ZEROADDR;
        end else begin
            pc <= next_pc;
        end
    end

endmodule
