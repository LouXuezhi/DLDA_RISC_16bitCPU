`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module id_ex_reg (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [   `ALUOPBUS_LEN] id_alu_op,
    input  wire [  `ALUSELBUS_LEN] id_alu_sel,
    input  wire [     `REGBUS_LEN] id_op1,
    input  wire [     `REGBUS_LEN] id_op2,
    input  wire [ `REGADDRBUS_LEN] id_reg_waddr,
    input  wire                    id_reg_we,
    input  wire [   `STALLBUS_LEN] ctrl_stall,
    input  wire [`INSTADDRBUS_LEN] id_link_addr,
    input  wire [     `REGBUS_LEN] id_ls_offset,
    output reg  [   `ALUOPBUS_LEN] ex_alu_op,
    output reg  [  `ALUSELBUS_LEN] ex_alu_sel,
    output reg  [     `REGBUS_LEN] ex_op1,
    output reg  [     `REGBUS_LEN] ex_op2,
    output reg  [ `REGADDRBUS_LEN] ex_reg_waddr,
    output reg                     ex_reg_we,
    output reg  [`INSTADDRBUS_LEN] ex_link_addr,
    output reg  [     `REGBUS_LEN] ex_ls_offset
);

    always @(posedge clk) begin
        if (rst || (ctrl_stall[`STALL_ID] && !ctrl_stall[`STALL_EX])) begin
            ex_alu_op      <= `ALU_NOP;
            ex_alu_sel     <= `SEL_NOP;
            ex_op1       <= 0;
            ex_op2       <= 0;
            ex_reg_waddr  <= 0;
            ex_reg_we         <= 0;
            ex_link_addr  <= 0;
            ex_ls_offset <= 0;
        end else if (!ctrl_stall[`STALL_ID]) begin
            ex_alu_op      <= id_alu_op;
            ex_alu_sel     <= id_alu_sel;
            ex_op1       <= id_op1;
            ex_op2       <= id_op2;
            ex_reg_waddr  <= id_reg_waddr;
            ex_reg_we         <= id_reg_we;
            ex_link_addr  <= id_link_addr;
            ex_ls_offset <= id_ls_offset;
        end
    end

endmodule
