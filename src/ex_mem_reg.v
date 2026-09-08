`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module ex_mem_reg (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [`REGADDRBUS_LEN] ex_reg_waddr,
    input  wire                    ex_we,
    input  wire [    `REGBUS_LEN] ex_reg_wdata,
    input  wire [`DATAADDRBUS_LEN] ex_mem_addr,
    input  wire [  `ALUOPBUS_LEN] ex_aluop,
    input  wire [    `REGBUS_LEN] ex_rs2_data,
    input  wire [  `STALLBUS_LEN] stall,
    output reg  [`REGADDRBUS_LEN] mem_reg_waddr,
    output reg                     mem_we,
    output reg  [    `REGBUS_LEN] mem_reg_wdata,
    output reg  [`DATAADDRBUS_LEN] mem_mem_addr,
    output reg  [  `ALUOPBUS_LEN] mem_aluop,
    output reg  [    `REGBUS_LEN] mem_rs2_data
);

    always @(posedge clk) begin
        if (rst || (stall[`STALL_EX] && !stall[`STALL_MEM])) begin
            mem_reg_waddr <= 0;
            mem_we        <= 0;
            mem_reg_wdata <= 0;
            mem_mem_addr  <= 0;
            mem_aluop     <= `ALU_NOP;
            mem_rs2_data  <= 0;
        end else if (!stall[`STALL_EX]) begin
            mem_reg_waddr <= ex_reg_waddr;
            mem_we        <= ex_we;
            mem_reg_wdata <= ex_reg_wdata;
            mem_mem_addr  <= ex_mem_addr;
            mem_aluop     <= ex_aluop;
            mem_rs2_data  <= ex_rs2_data;
        end
    end

endmodule
