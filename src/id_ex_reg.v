`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module id_ex_reg (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [  `ALUOPBUS_LEN] id_aluop,
    input  wire [ `ALUSELBUS_LEN] id_alusel,
    input  wire [    `REGBUS_LEN] id_opv1,
    input  wire [    `REGBUS_LEN] id_opv2,
    input  wire [`REGADDRBUS_LEN] id_reg_waddr,
    input  wire                    id_we,
    input  wire [  `STALLBUS_LEN] stall,
    input  wire [`INSTADDRBUS_LEN] id_link_addr,
    input  wire [    `REGBUS_LEN] id_mem_offset,
    output reg  [  `ALUOPBUS_LEN] ex_aluop,
    output reg  [ `ALUSELBUS_LEN] ex_alusel,
    output reg  [    `REGBUS_LEN] ex_opv1,
    output reg  [    `REGBUS_LEN] ex_opv2,
    output reg  [`REGADDRBUS_LEN] ex_reg_waddr,
    output reg                     ex_we,
    output reg  [`INSTADDRBUS_LEN] ex_link_addr,
    output reg  [    `REGBUS_LEN] ex_mem_offset
);

    always @(posedge clk) begin
        if (rst || (stall[`STALL_ID] && !stall[`STALL_EX])) begin
            ex_aluop      <= `ALU_NOP;
            ex_alusel     <= `SEL_NOP;
            ex_opv1       <= 0;
            ex_opv2       <= 0;
            ex_reg_waddr  <= 0;
            ex_we         <= 0;
            ex_link_addr  <= 0;
            ex_mem_offset <= 0;
        end else if (!stall[`STALL_ID]) begin
            ex_aluop      <= id_aluop;
            ex_alusel     <= id_alusel;
            ex_opv1       <= id_opv1;
            ex_opv2       <= id_opv2;
            ex_reg_waddr  <= id_reg_waddr;
            ex_we         <= id_we;
            ex_link_addr  <= id_link_addr;
            ex_mem_offset <= id_mem_offset;
        end
    end

endmodule
