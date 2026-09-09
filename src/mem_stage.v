`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module mem_stage (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [ `REGADDRBUS_LEN] reg_waddr_i,
    input  wire                    reg_we_i,
    input  wire [     `REGBUS_LEN] reg_wdata_i,
    input  wire [`DATAADDRBUS_LEN] ls_addr,
    input  wire [   `ALUOPBUS_LEN] alu_op,
    input  wire [     `REGBUS_LEN] st_data,
    input  wire                    dmem_busy,
    input  wire                    dmem_done,
    input  wire [     `REGBUS_LEN] dmem_rdata,
    output reg  [ `REGADDRBUS_LEN] reg_waddr_o,
    output reg                     reg_we_o,
    output reg  [     `REGBUS_LEN] reg_wdata_o,
    output reg                     dmem_re,
    output reg                     dmem_we,
    output reg  [     `REGBUS_LEN] dmem_wdata,
    output reg  [`DATAADDRBUS_LEN] dmem_addr,
    output reg                     stallreq
);

    reg dmem_taking;
    reg dmem_taking_next;

`define SET_MEM_INST(i_stallreq,i_dmem_taking,i_dmem_re,i_dmem_we,i_dmem_addr,i_dmem_wdata)\
    stallreq        = i_stallreq;\
    dmem_taking_next = i_dmem_taking;\
    dmem_re          = i_dmem_re;\
    dmem_we          = i_dmem_we;\
    dmem_addr      = i_dmem_addr;\
    dmem_wdata      = i_dmem_wdata;

    always @(posedge clk) begin
        if (rst) begin
            dmem_taking <= 0;
        end else begin
            dmem_taking <= dmem_taking_next;
        end
    end

    always @(*) begin
        dmem_taking_next = dmem_taking;
        dmem_re          = 0;
        dmem_we          = 0;
        dmem_addr      = 0;
        dmem_wdata      = 0;
        stallreq        = 0;

        reg_waddr_o     = reg_waddr_i;
        reg_we_o            = reg_we_i;
        reg_wdata_o     = reg_wdata_i;

        if (rst) begin
            `SET_MEM_INST(0, 0, 0, 0, 0, 0)
            reg_waddr_o = 0;
            reg_we_o        = 0;
            reg_wdata_o = 0;
        end else if (!dmem_busy && !dmem_taking) begin
            reg_waddr_o = reg_waddr_i;
            reg_we_o        = reg_we_i;
            case (alu_op)
                `ALU_LD: begin
                    `SET_MEM_INST(1, 1, 1, 0, ls_addr, 0)
                end
                `ALU_ST: begin
                    `SET_MEM_INST(1, 1, 0, 1, ls_addr, st_data)
                end
                default: begin
                    `SET_MEM_INST(0, 0, 0, 0, 0, 0)
                    reg_wdata_o = reg_wdata_i;
                end
            endcase
        end else if (!dmem_busy && dmem_taking) begin
            stallreq        = 0;
            dmem_taking_next = 0;
            case (alu_op)
                `ALU_LD: begin
                    reg_wdata_o = dmem_rdata;
                end
                default: begin
                end
            endcase
        end else begin  // mem_busy
            stallreq = 1;
        end
    end

endmodule
