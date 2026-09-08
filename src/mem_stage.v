`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module mem_stage (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [`REGADDRBUS_LEN] reg_waddr_i,
    input  wire                    we_i,
    input  wire [    `REGBUS_LEN] reg_wdata_i,
    input  wire [`DATAADDRBUS_LEN] mem_addr_i,
    input  wire [  `ALUOPBUS_LEN] aluop_i,
    input  wire [    `REGBUS_LEN] rs2_data_i,
    input  wire                    mem_busy,
    input  wire                    mem_done,
    input  wire [    `REGBUS_LEN] mem_data_i,
    output reg  [`REGADDRBUS_LEN] reg_waddr_o,
    output reg                     we_o,
    output reg  [    `REGBUS_LEN] reg_wdata_o,
    output reg                     mem_re,
    output reg                     mem_we,
    output reg  [    `REGBUS_LEN] mem_data_o,
    output reg  [`DATAADDRBUS_LEN] mem_addr_o,
    output reg                     stallreq
);

    reg mem_taking;
    reg mem_taking_next;

`define SET_MEM_INST(i_stallreq,i_mem_taking,i_mem_re,i_mem_we,i_mem_addr_o,i_mem_data_o)\
    stallreq        = i_stallreq;\
    mem_taking_next = i_mem_taking;\
    mem_re          = i_mem_re;\
    mem_we          = i_mem_we;\
    mem_addr_o      = i_mem_addr_o;\
    mem_data_o      = i_mem_data_o;

    always @(posedge clk) begin
        if (rst) begin
            mem_taking <= 0;
        end else begin
            mem_taking <= mem_taking_next;
        end
    end

    always @(*) begin
        mem_taking_next = mem_taking;
        mem_re          = 0;
        mem_we          = 0;
        mem_addr_o      = 0;
        mem_data_o      = 0;
        stallreq        = 0;

        reg_waddr_o     = reg_waddr_i;
        we_o            = we_i;
        reg_wdata_o     = reg_wdata_i;

        if (rst) begin
            `SET_MEM_INST(0, 0, 0, 0, 0, 0)
            reg_waddr_o = 0;
            we_o        = 0;
            reg_wdata_o = 0;
        end else if (!mem_busy && !mem_taking) begin
            reg_waddr_o = reg_waddr_i;
            we_o        = we_i;
            case (aluop_i)
                `ALU_LD: begin
                    `SET_MEM_INST(1, 1, 1, 0, mem_addr_i, 0)
                end
                `ALU_ST: begin
                    `SET_MEM_INST(1, 1, 0, 1, mem_addr_i, rs2_data_i)
                end
                default: begin
                    `SET_MEM_INST(0, 0, 0, 0, 0, 0)
                    reg_wdata_o = reg_wdata_i;
                end
            endcase
        end else if (!mem_busy && mem_taking) begin
            stallreq        = 0;
            mem_taking_next = 0;
            case (aluop_i)
                `ALU_LD: begin
                    reg_wdata_o = mem_data_i;
                end
                default: begin
                end
            endcase
        end else begin  // mem_busy
            stallreq = 1;
        end
    end

endmodule
