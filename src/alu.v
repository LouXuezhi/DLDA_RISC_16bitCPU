`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  alu -- one case on alu_op.  alu_op is the R-type funct code, so for
//  OP_ALU the instruction's own funct field drives this case directly;
//  every other opcode borrows ADD, AND or OR (see control_unit.v).
//
//  ALU_NOP and the reserved codes give 0.  The shift amount is b[3:0].
//=========================================================================

module alu (
    input  wire [`ALUOPBUS_LEN] alu_op,
    input  wire [  `REGBUS_LEN] a,
    input  wire [  `REGBUS_LEN] b,
    output reg  [  `REGBUS_LEN] result
);

    always @(*) begin
        case (alu_op)
            `ALU_ADD:  result = a + b;
            `ALU_SUB:  result = a - b;
            `ALU_AND:  result = a & b;
            `ALU_OR:   result = a | b;
            `ALU_XOR:  result = a ^ b;
            `ALU_NOR:  result = ~(a | b);
            `ALU_SLT:  result = ($signed(a) < $signed(b)) ? 16'd1 : 16'd0;
            `ALU_SLTU: result = (a < b) ? 16'd1 : 16'd0;
            `ALU_SLL:  result = a << b[3:0];
            `ALU_SRL:  result = a >> b[3:0];
            `ALU_SRA:  result = $signed(a) >>> b[3:0];
            default:   result = `ZEROWORD;
        endcase
    end

endmodule
