`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module ex_stage (
    input  wire                    rst,
    input  wire [  `ALUOPBUS_LEN] aluop,
    input  wire [ `ALUSELBUS_LEN] alusel,
    input  wire [    `REGBUS_LEN] opv1,
    input  wire [    `REGBUS_LEN] opv2,
    input  wire [`REGADDRBUS_LEN] reg_waddr_i,
    input  wire                    we_i,
    input  wire [`INSTADDRBUS_LEN] link_addr,
    input  wire [    `REGBUS_LEN] mem_offset,
    output reg  [`REGADDRBUS_LEN] reg_waddr,
    output reg                     we_o,
    output reg  [    `REGBUS_LEN] reg_wdata,
    output reg                     stallreq,
    output reg  [`DATAADDRBUS_LEN] mem_addr,
    output wire [  `ALUOPBUS_LEN] ex_aluop,
    output wire [    `REGBUS_LEN] rs2_data
);

    assign ex_aluop = aluop;
    assign rs2_data = opv2;

    reg [`REGBUS_LEN] logic_result;
    reg [`REGBUS_LEN] shift_result;
    reg [`REGBUS_LEN] arithmetic_result;
    reg [`REGBUS_LEN] mem_result;

    always @(*) begin
        if (rst || alusel != `SEL_LOGIC) begin
            logic_result = 0;
        end else begin
            case (aluop)
                `ALU_AND: logic_result = opv1 & opv2;
                `ALU_OR:  logic_result = opv1 | opv2;
                `ALU_XOR: logic_result = opv1 ^ opv2;
                `ALU_NOR: logic_result = ~(opv1 | opv2);
                default:  logic_result = 0;
            endcase
        end
    end

    always @(*) begin
        if (rst || alusel != `SEL_SHIFT) begin
            shift_result = 0;
        end else begin
            case (aluop)
                `ALU_SLL: shift_result = opv1 << opv2[3:0];
                `ALU_SRL: shift_result = opv1 >> opv2[3:0];
                `ALU_SRA: shift_result = ({16{opv1[15]}} << (5'd16 - {1'b0, opv2[3:0]}))
                                       | (opv1 >> opv2[3:0]);
                default:  shift_result = 0;
            endcase
        end
    end

    always @(*) begin
        if (rst || alusel != `SEL_ARITH) begin
            arithmetic_result = 0;
        end else begin
            case (aluop)
                `ALU_ADD:  arithmetic_result = opv1 + opv2;
                `ALU_SUB:  arithmetic_result = opv1 - opv2;
                `ALU_SLT:  arithmetic_result = ($signed(opv1) < $signed(opv2)) ? 1 : 0;
                `ALU_SLTU: arithmetic_result = ($unsigned(opv1) < $unsigned(opv2)) ? 1 : 0;
                default:   arithmetic_result = 0;
            endcase
        end
    end

    always @(*) begin
        if (rst || alusel != `SEL_LOAD_STORE) begin
            mem_result = 0;
        end else begin
            mem_result = opv1 + mem_offset;
        end
    end

    always @(*) begin
        stallreq  = 0;
        reg_waddr = reg_waddr_i;
        we_o      = we_i;
        mem_addr  = 0;
        case (alusel)
            `SEL_LOGIC: begin
                reg_wdata = logic_result;
            end
            `SEL_SHIFT: begin
                reg_wdata = shift_result;
            end
            `SEL_ARITH: begin
                reg_wdata = arithmetic_result;
            end
            `SEL_LOAD_STORE: begin
                reg_wdata = 0;
                // the ISA truncates: M[(R[Rs1] + sext8(imm))[7:0]], which is
                // what puts the MMIO ports at the top of the space in reach
                // of a small negative offset.
                mem_addr  = mem_result[`DATAADDRBUS_LEN];
            end
            `SEL_JUMP_BRANCH: begin
                mem_addr= 0;
                reg_wdata = link_addr;
            end
            default: begin
                reg_wdata = 0;
            end
        endcase
    end

endmodule
