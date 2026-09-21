`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  control_unit -- the whole decoder of the single-cycle core.
//
//  Combinational: opcode and funct in, one control word out.  The only
//  data it sees are the two branch flags, and those touch only pc_sel.
//
//  Every output is first set to 0 -- all zeros means nothing happens --
//  and each opcode raises only what it needs.  NOP, the reserved opcode
//  1111 and reset therefore all give the all-zero word: nothing written.
//
//    opcode  reg_we mem_we src_a src_b imm_sel  alu_op  wb_sel pc_sel
//    SYS       0      0    REG   REG   SEXT_I   NOP     ALU    PLUS1
//    ALU       *      0    REG   REG   SEXT_I   funct   ALU    PLUS1
//    ADDI      1      0    REG   IMM   SEXT_I   ADD     ALU    PLUS1
//    ANDI      1      0    REG   IMM   ZEXT_I   AND     ALU    PLUS1
//    ORI       1      0    REG   IMM   ZEXT_I   OR      ALU    PLUS1
//    LI        1      0    ZERO  IMM   SEXT_I   ADD     ALU    PLUS1
//    LUI       1      0    ZERO  IMM   LUI_I    ADD     ALU    PLUS1
//    LD        1      0    REG   IMM   SEXT_I   ADD     MEM    PLUS1
//    ST        0      1    REG   IMM   SEXT_S   ADD     ALU    PLUS1
//    Bxx       0      0    REG   REG   SEXT_S   NOP     ALU    REL if cond
//    JAL       1      0    REG   REG   SEXT_I   NOP     PC1    REL
//    JALR      1      0    REG   IMM   SEXT_I   ADD     PC1    ALU
//
//    * reg_we for OP_ALU only when funct names a real operation, so the
//      funct NOP and the reserved functs write nothing.
//=========================================================================

module control_unit (
    input  wire                   rst,
    input  wire [   `INSTBUS_LEN] inst,
    input  wire                   eq,
    input  wire                   lt,
    output reg                    reg_we,
    output reg                    mem_we,
    output reg                    src_a,
    output reg                    src_b,
    output reg  [`IMMSELBUS_LEN] imm_sel,
    output reg  [ `ALUOPBUS_LEN] alu_op,
    output reg  [ `WBSELBUS_LEN] wb_sel,
    output reg  [ `PCSELBUS_LEN] pc_sel
);

    wire [3:0]            opcode = inst[`F_OPCODE];
    wire [`ALUOPBUS_LEN]  funct  = inst[`F_FUNCT];
    wire                  funct_ok = (funct >= `ALU_ADD) && (funct <= `ALU_SRA);

    always @(*) begin
        reg_we  = 1'b0;
        mem_we  = 1'b0;
        src_a   = `SRCA_REG;
        src_b   = `SRCB_REG;
        imm_sel = `IMM_SEXT_I;
        alu_op  = `ALU_NOP;
        wb_sel  = `WB_ALU;
        pc_sel  = `PC_PLUS1;

        if (!rst) case (opcode)
            `OP_ALU: begin
                reg_we = funct_ok;
                alu_op = funct;
            end
            `OP_ADDI: begin
                reg_we = 1'b1;
                src_b  = `SRCB_IMM;
                alu_op = `ALU_ADD;
            end
            `OP_ANDI: begin
                reg_we  = 1'b1;
                src_b   = `SRCB_IMM;
                imm_sel = `IMM_ZEXT_I;
                alu_op  = `ALU_AND;
            end
            `OP_ORI: begin
                reg_we  = 1'b1;
                src_b   = `SRCB_IMM;
                imm_sel = `IMM_ZEXT_I;
                alu_op  = `ALU_OR;
            end
            `OP_LI: begin
                reg_we = 1'b1;
                src_a  = `SRCA_ZERO;
                src_b  = `SRCB_IMM;
                alu_op = `ALU_ADD;
            end
            `OP_LUI: begin
                reg_we  = 1'b1;
                src_a   = `SRCA_ZERO;
                src_b   = `SRCB_IMM;
                imm_sel = `IMM_LUI_I;
                alu_op  = `ALU_ADD;
            end
            `OP_LD: begin
                reg_we = 1'b1;
                src_b  = `SRCB_IMM;
                alu_op = `ALU_ADD;
                wb_sel = `WB_MEM;
            end
            `OP_ST: begin
                mem_we  = 1'b1;
                src_b   = `SRCB_IMM;
                imm_sel = `IMM_SEXT_S;
                alu_op  = `ALU_ADD;
            end
            `OP_BEQ: begin
                imm_sel = `IMM_SEXT_S;
                if (eq) pc_sel = `PC_REL;
            end
            `OP_BNE: begin
                imm_sel = `IMM_SEXT_S;
                if (!eq) pc_sel = `PC_REL;
            end
            `OP_BLT: begin
                imm_sel = `IMM_SEXT_S;
                if (lt) pc_sel = `PC_REL;
            end
            `OP_BGE: begin
                imm_sel = `IMM_SEXT_S;
                if (!lt) pc_sel = `PC_REL;
            end
            `OP_JAL: begin
                reg_we = 1'b1;
                wb_sel = `WB_PC1;
                pc_sel = `PC_REL;
            end
            `OP_JALR: begin
                reg_we = 1'b1;
                src_b  = `SRCB_IMM;
                alu_op = `ALU_ADD;
                wb_sel = `WB_PC1;
                pc_sel = `PC_ALU;
            end
            default: ;  // OP_SYS and the reserved 1111: all zeros
        endcase
    end

endmodule
