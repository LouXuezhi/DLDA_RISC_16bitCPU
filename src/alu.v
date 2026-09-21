`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  alu -- one case on alu_op.  alu_op is the R-type funct code, so for
//  OP_ALU the instruction's own funct field drives this case directly;
//  every other opcode borrows ADD, AND or OR (see control_unit.v).
//
//  ALU_NOP and the reserved codes give 0.  The shift amount is b[3:0].
//
//  Flags describe this cycle's result.  They are not stored and no
//  instruction reads them (the ISA branches on register compares), so
//  they are an observation port, not programmer-visible state:
//
//    zero      result == 0                                  every op
//    negative  result[15]                                   every op
//    carry     unsigned result out of range:                ADD, SUB
//                ADD -> carry out of bit 15
//                SUB -> borrow, i.e. a < b unsigned
//    overflow  signed result out of range:                  ADD, SUB
//                ADD -> a, b same sign, result sign differs
//                SUB -> a, b differ in sign, result sign differs from a
//
//  carry and overflow are 0 for every other op.
//=========================================================================

module alu (
    input  wire [`ALUOPBUS_LEN] alu_op,
    input  wire [  `REGBUS_LEN] a,
    input  wire [  `REGBUS_LEN] b,
    output reg  [  `REGBUS_LEN] result,
    output wire                 zero,
    output wire                 negative,
    output reg                  carry,
    output reg                  overflow
);

    // 17-bit sum and difference: bit 16 is the carry out / the borrow.
    wire [16:0] sum  = {1'b0, a} + {1'b0, b};
    wire [16:0] diff = {1'b0, a} - {1'b0, b};

    always @(*) begin
        carry    = 1'b0;
        overflow = 1'b0;
        case (alu_op)
            `ALU_ADD: begin
                result   = sum[15:0];
                carry    = sum[16];
                overflow = (a[15] == b[15]) && (sum[15] != a[15]);
            end
            `ALU_SUB: begin
                result   = diff[15:0];
                carry    = diff[16];
                overflow = (a[15] != b[15]) && (diff[15] != a[15]);
            end
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

    assign zero     = (result == `ZEROWORD);
    assign negative = result[15];

endmodule
