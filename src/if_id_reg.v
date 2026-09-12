`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module if_id_reg (
    input  wire                    rst,
    input  wire                    clk,
    input  wire [`INSTADDRBUS_LEN] if_pc,
    input  wire [    `INSTBUS_LEN] if_inst,
    input  wire                    if_valid,
    input  wire [   `STALLBUS_LEN] ctrl_stall,
    input  wire                    id_br,
    output reg  [`INSTADDRBUS_LEN] id_pc,
    output reg  [    `INSTBUS_LEN] id_inst,
    output reg                     id_valid
);

    // The bubble is now if_valid == 0 arriving on its own, so the old
    // "I stalled but ID did not" test is gone.  ctrl_stall[`STALL_ID] is the
    // only stall bit this register still reads.  Zeros still ride along with
    // an invalid beat, so the all-zeros-means-nothing rule keeps holding.
    always @(posedge clk) begin
        if (rst || id_br) begin
            id_pc    <= 0;
            id_inst  <= 0;
            id_valid <= 1'b0;
        end else if (!ctrl_stall[`STALL_ID]) begin
            id_pc    <= if_valid ? if_pc   : 0;
            id_inst  <= if_valid ? if_inst : 0;
            id_valid <= if_valid;
        end
    end

endmodule
