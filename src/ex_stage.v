`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module ex_stage (
    input  wire                    rst,
    input  wire [   `ALUOPBUS_LEN] alu_op_i,
    input  wire [  `ALUSELBUS_LEN] alu_sel,
    input  wire [     `REGBUS_LEN] op1,
    input  wire [     `REGBUS_LEN] op2,
    input  wire [ `REGADDRBUS_LEN] reg_waddr_i,
    input  wire                    reg_we_i,
    input  wire [`INSTADDRBUS_LEN] link_addr,
    input  wire [     `REGBUS_LEN] ls_offset,
    output reg  [ `REGADDRBUS_LEN] reg_waddr_o,
    output reg                     reg_we_o,
    output reg  [     `REGBUS_LEN] reg_wdata,
    output reg                     stallreq,
    output reg  [`DATAADDRBUS_LEN] ls_addr,
    output wire [   `ALUOPBUS_LEN] alu_op_o,
    output wire [     `REGBUS_LEN] st_data
);

    assign alu_op_o = alu_op_i;
    assign st_data = op2;

    reg [`REGBUS_LEN] logic_result;
    reg [`REGBUS_LEN] shift_result;
    reg [`REGBUS_LEN] arith_result;
    reg [`REGBUS_LEN] ls_result;

    always @(*) begin
        if (rst || alu_sel != `SEL_LOGIC) begin
            logic_result = 0;
        end else begin
            case (alu_op_i)
                `ALU_AND: logic_result = op1 & op2;
                `ALU_OR:  logic_result = op1 | op2;
                `ALU_XOR: logic_result = op1 ^ op2;
                `ALU_NOR: logic_result = ~(op1 | op2);
                default:  logic_result = 0;
            endcase
        end
    end

    always @(*) begin
        if (rst || alu_sel != `SEL_SHIFT) begin
            shift_result = 0;
        end else begin
            case (alu_op_i)
                `ALU_SLL: shift_result = op1 << op2[3:0];
                `ALU_SRL: shift_result = op1 >> op2[3:0];
                `ALU_SRA: shift_result = ({16{op1[15]}} << (5'd16 - {1'b0, op2[3:0]}))
                                       | (op1 >> op2[3:0]);
                default:  shift_result = 0;
            endcase
        end
    end

    always @(*) begin
        if (rst || alu_sel != `SEL_ARITH) begin
            arith_result = 0;
        end else begin
            case (alu_op_i)
                `ALU_ADD:  arith_result = op1 + op2;
                `ALU_SUB:  arith_result = op1 - op2;
                `ALU_SLT:  arith_result = ($signed(op1) < $signed(op2)) ? 1 : 0;
                `ALU_SLTU: arith_result = ($unsigned(op1) < $unsigned(op2)) ? 1 : 0;
                default:   arith_result = 0;
            endcase
        end
    end

    always @(*) begin
        if (rst || alu_sel != `SEL_LOAD_STORE) begin
            ls_result = 0;
        end else begin
            ls_result = op1 + ls_offset;
        end
    end

    always @(*) begin
        stallreq  = 0;
        reg_waddr_o = reg_waddr_i;
        reg_we_o      = reg_we_i;
        ls_addr  = 0;
        case (alu_sel)
            `SEL_LOGIC: begin
                reg_wdata = logic_result;
            end
            `SEL_SHIFT: begin
                reg_wdata = shift_result;
            end
            `SEL_ARITH: begin
                reg_wdata = arith_result;
            end
            `SEL_LOAD_STORE: begin
                reg_wdata = 0;
                // the ISA truncates: M[(R[Rs1] + sext8(imm))[7:0]], which is
                // what puts the MMIO ports at the top of the space in reach
                // of a small negative offset.
                ls_addr  = ls_result[`DATAADDRBUS_LEN];
            end
            `SEL_JUMP_BRANCH: begin
                ls_addr= 0;
                reg_wdata = link_addr;
            end
            default: begin
                reg_wdata = 0;
            end
        endcase
    end

endmodule
