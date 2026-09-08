`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module mem_rw_reg (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [`REGADDRBUS_LEN] mem_reg_waddr,
    input  wire                    mem_we,
    input  wire [    `REGBUS_LEN] mem_reg_wdata,
    input  wire [  `STALLBUS_LEN] stall,
    output reg  [`REGADDRBUS_LEN] wb_reg_waddr,
    output reg                     wb_we,
    output reg  [    `REGBUS_LEN] wb_reg_wdata
);

    always @(posedge clk) begin
        if (rst || (stall[`STALL_MEM] && !stall[`STALL_WB])) begin
            wb_reg_waddr <= 0;
            wb_we        <= 0;
            wb_reg_wdata <= 0;
        end else if (!stall[`STALL_MEM]) begin
            wb_reg_waddr <= mem_reg_waddr;
            wb_we        <= mem_we;
            wb_reg_wdata <= mem_reg_wdata;
        end
    end

endmodule
