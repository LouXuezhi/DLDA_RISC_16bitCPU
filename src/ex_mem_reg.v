`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module ex_mem_reg (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [ `REGADDRBUS_LEN] ex_reg_waddr,
    input  wire                    ex_reg_we,
    input  wire [     `REGBUS_LEN] ex_reg_wdata,
    input  wire [`DATAADDRBUS_LEN] ex_ls_addr,
    input  wire [   `ALUOPBUS_LEN] ex_alu_op,
    input  wire [     `REGBUS_LEN] ex_st_data,
    input  wire [   `STALLBUS_LEN] ctrl_stall,
    output reg  [ `REGADDRBUS_LEN] mem_reg_waddr,
    output reg                     mem_reg_we,
    output reg  [     `REGBUS_LEN] mem_reg_wdata,
    output reg  [`DATAADDRBUS_LEN] mem_ls_addr,
    output reg  [   `ALUOPBUS_LEN] mem_alu_op,
    output reg  [     `REGBUS_LEN] mem_st_data
);

    always @(posedge clk) begin
        if (rst || (ctrl_stall[`STALL_EX] && !ctrl_stall[`STALL_MEM])) begin
            mem_reg_waddr <= 0;
            mem_reg_we        <= 0;
            mem_reg_wdata <= 0;
            mem_ls_addr  <= 0;
            mem_alu_op     <= `ALU_NOP;
            mem_st_data  <= 0;
        end else if (!ctrl_stall[`STALL_EX]) begin
            mem_reg_waddr <= ex_reg_waddr;
            mem_reg_we        <= ex_reg_we;
            mem_reg_wdata <= ex_reg_wdata;
            mem_ls_addr  <= ex_ls_addr;
            mem_alu_op     <= ex_alu_op;
            mem_st_data  <= ex_st_data;
        end
    end

endmodule
