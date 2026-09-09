`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module mem_wb_reg (
    input  wire                   clk,
    input  wire                   rst,
    input  wire [`REGADDRBUS_LEN] mem_reg_waddr,
    input  wire                   mem_reg_we,
    input  wire [    `REGBUS_LEN] mem_reg_wdata,
    input  wire [  `STALLBUS_LEN] ctrl_stall,
    output reg  [`REGADDRBUS_LEN] wb_reg_waddr,
    output reg                    wb_reg_we,
    output reg  [    `REGBUS_LEN] wb_reg_wdata
);

    always @(posedge clk) begin
        if (rst || (ctrl_stall[`STALL_MEM] && !ctrl_stall[`STALL_WB])) begin
            wb_reg_waddr <= 0;
            wb_reg_we        <= 0;
            wb_reg_wdata <= 0;
        end else if (!ctrl_stall[`STALL_MEM]) begin
            wb_reg_waddr <= mem_reg_waddr;
            wb_reg_we        <= mem_reg_we;
            wb_reg_wdata <= mem_reg_wdata;
        end
    end

endmodule
