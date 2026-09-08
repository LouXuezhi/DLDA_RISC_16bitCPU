`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module id_stage (
    input wire                    rst,
    input wire [`INSTADDRBUS_LEN] pc,
    input wire [    `INSTBUS_LEN] inst,
    input wire [     `REGBUS_LEN] reg_data1,
    input wire [     `REGBUS_LEN] reg_data2,

    input wire [  `ALUOPBUS_LEN] ex_aluop,
    input wire                   ex_we,
    input wire [`REGADDRBUS_LEN] ex_reg_waddr,
    input wire [    `REGBUS_LEN] ex_reg_wdata,

    input  wire                    mem_we,
    input  wire [     `REGBUS_LEN] mem_reg_wdata,
    // [1:0] | 4 address
    input  wire [ `REGADDRBUS_LEN] mem_reg_waddr,
    output reg                     re1,
    output reg                     re2,
    output reg  [ `REGADDRBUS_LEN] reg_addr1,
    output reg  [ `REGADDRBUS_LEN] reg_addr2,
    output reg  [   `ALUOPBUS_LEN] aluop,
    output reg  [  `ALUSELBUS_LEN] alusel,
    output reg  [     `REGBUS_LEN] opv1,
    output reg  [     `REGBUS_LEN] opv2,
    output reg  [ `REGADDRBUS_LEN] reg_waddr,
    output reg                     we,
    output wire                    stallreq,
    output reg                     br,
    output reg  [`INSTADDRBUS_LEN] br_addr,
    output reg  [`INSTADDRBUS_LEN] link_addr,
    output reg  [     `REGBUS_LEN] mem_offset
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

  reg  stallreq_for_reg1_load;
  reg  stallreq_for_reg2_load;
  assign stallreq = stallreq_for_reg1_load || stallreq_for_reg2_load;

  wire prev_is_load;
  assign prev_is_load = (ex_aluop == `ALU_LD);

  wire [`INSTADDRBUS_LEN] reg1_plus_I_imm;
  wire [`INSTADDRBUS_LEN] pc_plus_I_imm;
  wire [`INSTADDRBUS_LEN] pc_plus_S_imm;
  wire [`INSTADDRBUS_LEN] pc_plus_1;

  assign reg1_plus_I_imm = opv1 + {{8{imm_i[7]}}, imm_i};
  assign pc_plus_S_imm   = pc + {{8{imm_s[7]}}, imm_s};
  assign pc_plus_I_imm   = pc + {{8{imm_i[7]}}, imm_i};
  assign pc_plus_1       = pc + 1;

  wire reg1_reg2_eq;
  wire reg1_reg2_ne;
  wire reg1_reg2_lt;
  wire reg1_reg2_ge;

  assign reg1_reg2_eq = (opv1 == opv2);
  assign reg1_reg2_ne = (opv1 != opv2);
  assign reg1_reg2_lt = ($signed(opv1) < $signed(opv2));
  assign reg1_reg2_ge = ($signed(opv1) >= $signed(opv2));

  // verilog_format: off
  // The formal-parameter list of a `define must stay on one physical line:
  // splitting it is outside what the standard guarantees, and Vivado's
  // preprocessor is stricter about it than iverilog/verilator.
  `define SET_INST(i_alusel, i_aluop, i_inst_valid, i_re1, i_re2, i_reg_addr1, i_reg_addr2, i_we, i_reg_waddr, i_imm1, i_imm2, i_mem_offset)\
    aluop      = i_aluop;\
    alusel     = i_alusel;\
    inst_valid = i_inst_valid;\
    re1        = i_re1;\
    re2        = i_re2;\
    reg_addr1  = i_reg_addr1;\
    reg_addr2  = i_reg_addr2;\
    we         = i_we;\
    reg_waddr  = i_reg_waddr;\
    imm1       = i_imm1;\
    imm2       = i_imm2;\
    mem_offset = i_mem_offset;
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
          `SET_BRANCH(1, pc_plus_I_imm, pc_plus_1)
        end

        `OP_JALR: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_JALR, 1, 1, 0, rs1_addr, 0, 1, rd_addr, 0, 0, 0)
          `SET_BRANCH(1, reg1_plus_I_imm, pc_plus_1)
        end
        // i_alusel,i_aluop,i_inst_valid,i_re1,i_re2,i_reg_addr1,i_reg_addr2,i_we,i_reg_waddr,i_imm1,i_imm2,i_mem_offset
        `OP_BEQ: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_BEQ, 1, 1, 1, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
          if (reg1_reg2_eq) begin
            `SET_BRANCH(1, pc_plus_S_imm, 0)
          end
        end

        `OP_BNE: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_BNE, 1, 1, 1, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
          if (reg1_reg2_ne) begin
            `SET_BRANCH(1, pc_plus_S_imm, 0)
          end
        end

        `OP_BLT: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_BLT, 1, 1, 1, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
          if (reg1_reg2_lt) begin
            `SET_BRANCH(1, pc_plus_S_imm, 0)
          end
        end

        `OP_BGE: begin
          `SET_INST(`SEL_JUMP_BRANCH, `ALU_BGE, 1, 1, 1, rs1_addr, rs2_addr, 0, rd_addr, 0, 0, 0)
          if (reg1_reg2_ge) begin
            `SET_BRANCH(1, pc_plus_S_imm, 0)
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

  `define SET_OPV(opv, re, regaddr, reg_data, imm, stallreq)\
    stallreq = 0;\
    if (rst) begin\
        opv = 0;\
    end else if (re && prev_is_load && (ex_reg_waddr == regaddr)) begin\
        stallreq = 1;\
    end else if (re && ex_we && (ex_reg_waddr == regaddr)) begin\
        opv = ex_reg_wdata;\
    end else if (re && mem_we && (mem_reg_waddr == regaddr)) begin\
        opv = mem_reg_wdata;\
    end else if (re) begin\
        opv = reg_data;\
    end else if (!re) begin\
        opv = imm;\
    end else begin\
        opv = 0;\
    end
  // forwarding logic.  If the previous instruction is a load the data is not
  // ready yet, so stall; otherwise forward from EX or MEM.
  always @(*) begin
    `SET_OPV(opv1, re1, reg_addr1, reg_data1, imm1, stallreq_for_reg1_load)
  end
  always @(*) begin
    `SET_OPV(opv2, re2, reg_addr2, reg_data2, imm2, stallreq_for_reg2_load)
  end

endmodule
