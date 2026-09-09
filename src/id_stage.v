`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module id_stage (
    input wire                    rst,
    input wire [`INSTADDRBUS_LEN] pc,
    input wire [    `INSTBUS_LEN] inst,
    input wire [     `REGBUS_LEN] rs1_rdata,
    input wire [     `REGBUS_LEN] rs2_rdata,

    input wire [  `ALUOPBUS_LEN] fwd_ex_alu_op,
    input wire                   fwd_ex_reg_we,
    input wire [`REGADDRBUS_LEN] fwd_ex_reg_waddr,
    input wire [    `REGBUS_LEN] fwd_ex_reg_wdata,

    input  wire                    fwd_mem_reg_we,
    input  wire [     `REGBUS_LEN] fwd_mem_reg_wdata,
    // [1:0] | 4 address
    input  wire [ `REGADDRBUS_LEN] fwd_mem_reg_waddr,
    output reg                     rs1_re,
    output reg                     rs2_re,
    output reg  [ `REGADDRBUS_LEN] rs1_raddr,
    output reg  [ `REGADDRBUS_LEN] rs2_raddr,
    output reg  [   `ALUOPBUS_LEN] alu_op,
    output reg  [  `ALUSELBUS_LEN] alu_sel,
    output reg  [     `REGBUS_LEN] op1,
    output reg  [     `REGBUS_LEN] op2,
    output reg  [ `REGADDRBUS_LEN] reg_waddr,
    output reg                     reg_we,
    output wire                    stallreq,
    output reg                     br,
    output reg  [`INSTADDRBUS_LEN] br_addr,
    output reg  [`INSTADDRBUS_LEN] link_addr,
    output reg  [     `REGBUS_LEN] ls_offset
);

  wire [`F_OPCODE] opcode = inst[`F_OPCODE];
  wire [ `F_FUNCT] funct  = inst[`F_FUNCT];
  wire [   `F_IMM] imm_i  = inst[`F_IMM];
  wire [   `F_IMM] imm_s  = {inst[`F_IMM_H], inst[`F_IMM_L]};
  reg  [`REGBUS_LEN] imm1;
  reg  [`REGBUS_LEN] imm2;
  reg  inst_valid;

  wire [ `F_RD] rd_addr  = inst[`F_RD];
  wire [`F_RS1] rs1_addr = inst[`F_RS1];
  wire [`F_RS2] rs2_addr = inst[`F_RS2];

  reg  stallreq_rs1_load;
  reg  stallreq_rs2_load;
  assign stallreq = stallreq_rs1_load || stallreq_rs2_load;

  wire prev_is_load;
  assign prev_is_load = (fwd_ex_alu_op == `ALU_LD);

  wire [`INSTADDRBUS_LEN] rs1_plus_imm_i;
  wire [`INSTADDRBUS_LEN] pc_plus_imm_i;
  wire [`INSTADDRBUS_LEN] pc_plus_imm_s;
  wire [`INSTADDRBUS_LEN] pc_plus_1;

  assign rs1_plus_imm_i = op1 + {{8{imm_i[7]}}, imm_i};
  assign pc_plus_imm_s   = pc + {{8{imm_s[7]}}, imm_s};
  assign pc_plus_imm_i   = pc + {{8{imm_i[7]}}, imm_i};
  assign pc_plus_1       = pc + 1;

  wire cmp_eq;
  wire cmp_ne;
  wire cmp_lt;
  wire cmp_ge;

  assign cmp_eq = (op1 == op2);
  assign cmp_ne = (op1 != op2);
  assign cmp_lt = ($signed(op1) < $signed(op2));
  assign cmp_ge = ($signed(op1) >= $signed(op2));

  // verilog_format: off
  // The formal-parameter list of a `define must stay on one physical line:
  // splitting it is outside what the standard guarantees, and Vivado's
  // preprocessor is stricter about it than iverilog/verilator.
  `define SET_INST(i_alu_sel, i_alu_op, i_inst_valid, i_rs1_re, i_rs2_re, i_rs1_raddr, i_rs2_raddr, i_reg_we, i_reg_waddr, i_imm1, i_imm2, i_ls_offset)\
    alu_op      = i_alu_op;\
    alu_sel     = i_alu_sel;\
    inst_valid = i_inst_valid;\
    rs1_re        = i_rs1_re;\
    rs2_re        = i_rs2_re;\
    rs1_raddr  = i_rs1_raddr;\
    rs2_raddr  = i_rs2_raddr;\
    reg_we         = i_reg_we;\
    reg_waddr  = i_reg_waddr;\
    imm1       = i_imm1;\
    imm2       = i_imm2;\
    ls_offset = i_ls_offset;
  // imm1 imm2 are used to store the immediate value,
  // which is used to calculate the address of the memory.

  `define SET_BRANCH(i_br, i_br_addr, i_link_addr)\
    br        = i_br;\
    br_addr   = i_br_addr;\
    link_addr = i_link_addr;
  // verilog_format: on
  // br_addr   -> destination
  // link_addr -> where to jump back to, the return address for JAL and JALR.

  always @(*) begin
    if (rst) begin
      `SET_BRANCH(0, 0, 0)
      `SET_INST(`SEL_NOP, `ALU_NOP, 1, 0, 0, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
    end else begin
      `SET_BRANCH(0, 0, 0)
      `SET_INST(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      case (opcode)
        `OP_SYS: begin
          `SET_INST(`SEL_NOP, `ALU_NOP, 1, 0, 0, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
        end

        `OP_LUI: begin
          `SET_INST(`SEL_ARITH, `ALU_ADD, 1, 0, 0, 0, 0, 1, rd_addr, {imm_i, 8'h00}, 0, 0)
        end

        `OP_LI: begin
          `SET_INST(`SEL_ARITH, `ALU_ADD, 1, 0, 0, 0, 0, 1, rd_addr, {{8{imm_i[7]}}, imm_i}, 0, 0)
        end

        `OP_JAL: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_JAL, 1, 0, 0, 0, 0, 1, rd_addr, 0, 0, 0)
          `SET_BRANCH(1, pc_plus_imm_i, pc_plus_1)
        end

        `OP_JALR: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_JALR, 1, 1, 0, rs1_addr, 0, 1, rd_addr, 0, 0, 0)
          `SET_BRANCH(1, rs1_plus_imm_i, pc_plus_1)
        end
        // i_alu_sel,i_alu_op,i_inst_valid,i_rs1_re,i_rs2_re,i_rs1_raddr,i_rs2_raddr,i_reg_we,i_reg_waddr,i_imm1,i_imm2,i_ls_offset
        `OP_BEQ: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_BEQ, 1, 1, 1, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
          if (cmp_eq) begin
            `SET_BRANCH(1, pc_plus_imm_s, 0)
          end
        end

        `OP_BNE: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_BNE, 1, 1, 1, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
          if (cmp_ne) begin
            `SET_BRANCH(1, pc_plus_imm_s, 0)
          end
        end

        `OP_BLT: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_BLT, 1, 1, 1, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
          if (cmp_lt) begin
            `SET_BRANCH(1, pc_plus_imm_s, 0)
          end
        end

        `OP_BGE: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_BGE, 1, 1, 1, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
          if (cmp_ge) begin
            `SET_BRANCH(1, pc_plus_imm_s, 0)
          end
        end

        `OP_LD: begin
          `SET_INST(`SEL_LOAD_STORE, `ALU_LD, 1, 1, 0, rs1_addr, 0, 1, rd_addr, 0, 0, {
                    {8{imm_i[7]}}, imm_i})
        end

        `OP_ST: begin
          `SET_INST(`SEL_LOAD_STORE, `ALU_ST, 1, 1, 1, rs1_addr, rs2_addr, 0, 0, 0, 0, {
                    {8{imm_s[7]}}, imm_s})
        end

        `OP_ADDI: begin
          `SET_INST(`SEL_ARITH, `ALU_ADD, 1, 1, 0, rs1_addr, 0, 1, rd_addr, 0, {{8{imm_i[7]}}, imm_i
                    }, 0)
        end

        `OP_ORI: begin
          `SET_INST(`SEL_LOGIC, `ALU_OR, 1, 1, 0, rs1_addr, 0, 1, rd_addr, 0, {8'h00, imm_i}, 0)
        end

        `OP_ANDI: begin
          `SET_INST(`SEL_LOGIC, `ALU_AND, 1, 1, 0, rs1_addr, 0, 1, rd_addr, 0, {8'h00, imm_i}, 0)
        end

        `OP_ALU: begin
          case (funct)
            `ALU_ADD: begin
              `SET_INST(`SEL_ARITH, `ALU_ADD, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_SUB: begin
              `SET_INST(`SEL_ARITH, `ALU_SUB, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_AND: begin
              `SET_INST(`SEL_LOGIC, `ALU_AND, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_OR: begin
              `SET_INST(`SEL_LOGIC, `ALU_OR, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_XOR: begin
              `SET_INST(`SEL_LOGIC, `ALU_XOR, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_NOR: begin
              `SET_INST(`SEL_LOGIC, `ALU_NOR, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_SLT: begin
              `SET_INST(`SEL_ARITH, `ALU_SLT, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_SLTU: begin
              `SET_INST(`SEL_ARITH, `ALU_SLTU, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_SLL: begin
              `SET_INST(`SEL_SHIFT, `ALU_SLL, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_SRL: begin
              `SET_INST(`SEL_SHIFT, `ALU_SRL, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            `ALU_SRA: begin
              `SET_INST(`SEL_SHIFT, `ALU_SRA, 1, 1, 1, rs1_addr, rs2_addr, 1, rd_addr, 0, 0, 0)
            end
            default: begin
            end
          endcase
        end
        default: begin
        end
      endcase
    end
  end

  `define SET_OPV(op, re, raddr, rdata, imm, stallreq)\
    stallreq = 0;\
    if (rst) begin\
        op = 0;\
    end else if (re && prev_is_load && (fwd_ex_reg_waddr == raddr)) begin\
        stallreq = 1;\
    end else if (re && fwd_ex_reg_we && (fwd_ex_reg_waddr == raddr)) begin\
        op = fwd_ex_reg_wdata;\
    end else if (re && fwd_mem_reg_we && (fwd_mem_reg_waddr == raddr)) begin\
        op = fwd_mem_reg_wdata;\
    end else if (re) begin\
        op = rdata;\
    end else if (!re) begin\
        op = imm;\
    end else begin\
        op = 0;\
    end
  // forwarding logic.  If the previous instruction is a load the data is not
  // ready yet, so stall; otherwise forward from EX or MEM.
  always @(*) begin
    `SET_OPV(op1, rs1_re, rs1_raddr, rs1_rdata, imm1, stallreq_rs1_load)
  end
  always @(*) begin
    `SET_OPV(op2, rs2_re, rs2_raddr, rs2_rdata, imm2, stallreq_rs2_load)
  end

endmodule
