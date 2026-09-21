`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  imm_ext -- widen the 8-bit immediate to 16 bits.
//
//  The widening depends on what the immediate means, so the control unit
//  picks it per opcode (see doc/ISA.md, Widening the immediate).  The four
//  candidates are pure wiring; the only logic is the 4-way mux.
//=========================================================================

module imm_ext (
    input  wire [ `INSTBUS_LEN] inst,
    input  wire [`IMMSELBUS_LEN] imm_sel,
    output reg  [  `REGBUS_LEN] imm
);

    wire [7:0] imm_i = inst[`F_IMM];
    wire [7:0] imm_s = {inst[`F_IMM_H], inst[`F_IMM_L]};

    always @(*) begin
        case (imm_sel)
            `IMM_SEXT_I: imm = {{8{imm_i[7]}}, imm_i};
            `IMM_ZEXT_I: imm = {8'h00, imm_i};
            `IMM_LUI_I:  imm = {imm_i, 8'h00};
            `IMM_SEXT_S: imm = {{8{imm_s[7]}}, imm_s};
            default:     imm = `ZEROWORD;
        endcase
    end

endmodule
