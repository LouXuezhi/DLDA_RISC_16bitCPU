`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  cpu_core -- single-cycle datapath plus control unit.
//
//  Every instruction runs start to finish in one clock.  The only state
//  is the PC, the register file and data memory; each takes its new value
//  on the rising edge, and everything between two edges is combinational:
//
//    pc -> imem -> inst -+-> control_unit -> control word
//                        +-> regfile -> branch_cmp -> eq, lt
//                        |          \-> src_a/src_b muxes -> alu -> dmem
//                        +-> imm_ext                          |      |
//                                            wb mux <- pc+1, alu, dmem
//
//    next_pc = PC_PLUS1 : pc + 1
//              PC_REL   : pc + imm        taken branch, JAL (self-relative)
//              PC_ALU   : alu result      JALR, R[Rs1] + sext8(imm)
//
//  No pipeline registers, so there is nothing to stall, flush or forward.
//  While rst is high both write enables are held low.
//=========================================================================

module cpu_core #(
    parameter INST_INIT = "",
    parameter DATA_INIT = ""
) (
    input wire clk,
    input wire rst
);

    //---- fetch ---------------------------------------------------------------
    wire [`INSTADDRBUS_LEN] pc;
    wire [`INSTADDRBUS_LEN] pc_plus1 = pc + 1;
    reg  [`INSTADDRBUS_LEN] next_pc;
    wire [    `INSTBUS_LEN] inst;

    //---- control word --------------------------------------------------------
    wire                  reg_we;
    wire                  mem_we;
    wire                  src_a;
    wire                  src_b;
    wire [`IMMSELBUS_LEN] imm_sel;
    wire [ `ALUOPBUS_LEN] alu_op;
    wire [ `WBSELBUS_LEN] wb_sel;
    wire [ `PCSELBUS_LEN] pc_sel;

    //---- datapath ------------------------------------------------------------
    wire [`REGBUS_LEN] rdata1;
    wire [`REGBUS_LEN] rdata2;
    wire [`REGBUS_LEN] imm;
    wire [`REGBUS_LEN] alu_a = (src_a == `SRCA_ZERO) ? `ZEROWORD : rdata1;
    wire [`REGBUS_LEN] alu_b = (src_b == `SRCB_IMM) ? imm : rdata2;
    wire [`REGBUS_LEN] alu_result;
    wire [`REGBUS_LEN] mem_rdata;
    reg  [`REGBUS_LEN] wb_data;
    wire               eq;
    wire               lt;

    pc_reg u_pc_reg (
        .clk    (clk),
        .rst    (rst),
        .next_pc(next_pc),
        .pc     (pc)
    );

    imem #(
        .INIT(INST_INIT)
    ) u_imem (
        .addr(pc),
        .inst(inst)
    );

    control_unit u_control_unit (
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
        .we    (reg_we && !rst),
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

    alu u_alu (
        .alu_op(alu_op),
        .a     (alu_a),
        .b     (alu_b),
        .result(alu_result)
    );

    // ST stores Rs2; the address is the ALU sum truncated to 8 bits.
    dmem #(
        .INIT(DATA_INIT)
    ) u_dmem (
        .clk  (clk),
        .we   (mem_we && !rst),
        .addr (alu_result[`DATAADDRBUS_LEN]),
        .wdata(rdata2),
        .rdata(mem_rdata)
    );

    //---- write-back mux ------------------------------------------------------
    always @(*) begin
        case (wb_sel)
            `WB_MEM: wb_data = mem_rdata;
            `WB_PC1: wb_data = pc_plus1;
            default: wb_data = alu_result;
        endcase
    end

    //---- next-PC mux ---------------------------------------------------------
    always @(*) begin
        case (pc_sel)
            `PC_REL: next_pc = pc + imm;
            `PC_ALU: next_pc = alu_result;
            default: next_pc = pc_plus1;
        endcase
    end

endmodule
