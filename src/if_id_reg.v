`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module if_id_reg (
    input  wire                    rst,
    input  wire                    clk,
    input  wire [`INSTADDRBUS_LEN] if_pc,
    input  wire [    `INSTBUS_LEN] if_inst,
    input  wire [   `STALLBUS_LEN] stall,
    input  wire                    br,
    output reg  [`INSTADDRBUS_LEN] id_pc,
    output reg  [    `INSTBUS_LEN] id_inst
);

    always @(posedge clk) begin
        if (rst || br || (stall[`STALL_IF] && !stall[`STALL_ID])) begin
            id_pc   <= 0;
            id_inst <= 0;
        end else if (!stall[`STALL_IF]) begin
            id_pc   <= if_pc;
            id_inst <= if_inst;
        end
    end

endmodule
