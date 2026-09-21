`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  cpu_core -- single-cycle datapath plus control unit.
//
//  Wiring only: every box in the block diagram is one instance below, and
//  there is no logic in this file.  Every instruction runs start to finish
//  in one clock.  The state is the PC, the register file and data memory;
//  each takes its new value on the rising edge.
//
//    pc -> imem -> inst -+-> control_unit -> control word
//                        +-> regfile -> branch_cmp -> eq, lt
//                        |          \-> mux_a / mux_b -> alu -> dmem
//                        +-> imm_ext                      |      |
//                                    mux_wb <- pc+1, alu, dmem
//
//    mux_pc:  PC_PLUS1 -> pc + 1
//             PC_REL   -> pc + imm        taken branch, JAL (self-relative)
//             PC_ALU   -> alu result      JALR, R[Rs1] + sext8(imm)
//=========================================================================

module cpu_core #(
    parameter INST_INIT = "",
    parameter DATA_INIT = ""
) (
    input wire clk,
    input wire rst
);

    //---- fetch -----------------------------------------------------------
    wire [`INSTADDRBUS_LEN] pc;
    wire [`INSTADDRBUS_LEN] pc_plus1;
    wire [`INSTADDRBUS_LEN] pc_rel;
    wire [`INSTADDRBUS_LEN] next_pc;
    wire [    `INSTBUS_LEN] inst;

    //---- control word ----------------------------------------------------
    wire                  reg_we;
    wire                  mem_we;
    wire                  src_a;
    wire                  src_b;
    wire [`IMMSELBUS_LEN] imm_sel;
    wire [ `ALUOPBUS_LEN] alu_op;
    wire [ `WBSELBUS_LEN] wb_sel;
    wire [ `PCSELBUS_LEN] pc_sel;

    //---- datapath --------------------------------------------------------
    wire [`REGBUS_LEN] rdata1;
    wire [`REGBUS_LEN] rdata2;
    wire [`REGBUS_LEN] imm;
    wire [`REGBUS_LEN] alu_a;
    wire [`REGBUS_LEN] alu_b;
    wire [`REGBUS_LEN] alu_result;
    wire [`REGBUS_LEN] mem_rdata;
    wire [`REGBUS_LEN] wb_data;
    wire               eq;
    wire               lt;

    //---- PC and next PC --------------------------------------------------
    pc_reg u_pc_reg (
        .clk    (clk),
        .rst    (rst),
        .next_pc(next_pc),
        .pc     (pc)
    );

    adder u_add_pc1 (
        .a(pc),
        .b(`PC_STEP),
        .y(pc_plus1)
    );

    adder u_add_rel (
        .a(pc),
        .b(imm),
        .y(pc_rel)
    );

    mux3 u_mux_pc (
        .sel(pc_sel),
        .d0 (pc_plus1),
        .d1 (pc_rel),
        .d2 (alu_result),
        .y  (next_pc)
    );

    //---- fetch and decode ------------------------------------------------
    imem #(
        .INIT(INST_INIT)
    ) u_imem (
        .addr(pc),
        .inst(inst)
    );

    control_unit u_control_unit (
        .rst    (rst),
        .inst   (inst),
        .eq     (eq),
        .lt     (lt),
        .reg_we (reg_we),
        .mem_we (mem_we),
        .src_a  (src_a),
        .src_b  (src_b),
        .imm_sel(imm_sel),
        .alu_op (alu_op),
        .wb_sel (wb_sel),
        .pc_sel (pc_sel)
    );

    regfile u_regfile (
        .clk   (clk),
        .we    (reg_we),
        .waddr (inst[`F_RD]),
        .wdata (wb_data),
        .raddr1(inst[`F_RS1]),
        .rdata1(rdata1),
        .raddr2(inst[`F_RS2]),
        .rdata2(rdata2)
    );

    imm_ext u_imm_ext (
        .inst   (inst),
        .imm_sel(imm_sel),
        .imm    (imm)
    );

    branch_cmp u_branch_cmp (
        .a (rdata1),
        .b (rdata2),
        .eq(eq),
        .lt(lt)
    );

    //---- execute ---------------------------------------------------------
    mux2 u_mux_a (
        .sel(src_a),
        .d0 (rdata1),
        .d1 (`ZEROWORD),
        .y  (alu_a)
    );

    mux2 u_mux_b (
        .sel(src_b),
        .d0 (rdata2),
        .d1 (imm),
        .y  (alu_b)
    );

    alu u_alu (
        .alu_op(alu_op),
        .a     (alu_a),
        .b     (alu_b),
        .result(alu_result)
    );

    //---- memory: address = ALU sum truncated to 8 bits, ST stores Rs2 ----
    dmem #(
        .INIT(DATA_INIT)
    ) u_dmem (
        .clk  (clk),
        .we   (mem_we),
        .addr (alu_result[`DATAADDRBUS_LEN]),
        .wdata(rdata2),
        .rdata(mem_rdata)
    );

    //---- write back ------------------------------------------------------
    mux3 u_mux_wb (
        .sel(wb_sel),
        .d0 (alu_result),
        .d1 (mem_rdata),
        .d2 (pc_plus1),
        .y  (wb_data)
    );

endmodule
