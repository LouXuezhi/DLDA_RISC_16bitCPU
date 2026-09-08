`timescale 1ns / 1ps
`ifndef DEFINE_ISA_V
`define DEFINE_ISA_V

//=========================================================================
//  class_cpu -- 16-bit RISC ISA.  Programmer-visible encoding only.
//  Spec: doc/ISA.md
//
//  AXIOM: all zeros means nothing happens.
//    Opcode 0000 does nothing, whatever the other 12 bits hold, so the
//    whole range 0x0000..0x0FFF is inert.  Flush and stall both work by
//    writing zeros into a pipeline register.  Do not break this.
//=========================================================================

//---- widths -------------------------------------------------------------
`define INSTBUS_LEN 15:0
`define INSTADDRBUS_LEN 15:0           // the PC
`define REGBUS_LEN 15:0            // register file / ALU datapath
`define REGADDRBUS_LEN 1:0
`define DATAADDRBUS_LEN 7:0            // data address, after truncation
`define ALUOPBUS_LEN 5:0            // == the R-type funct field
`define REGNUM 4

//---- memory depth.  Both memories are word-addressed: one address selects
//     one 16-bit word.  There is no byte, so no alignment and no byte
//     enable, and `LB`/`SB` are not merely absent but meaningless.
//
//     The PC is 16 bits wide but only `IMEMNUM words are instantiated --
//     an address bus is not a promise to build that much memory.  Index
//     imem with the low `IMEMIDX_LEN bits; the two must agree.
`define IMEMNUM 1024
`define IMEMIDX_LEN 9:0

//     Data addresses truncate to 8 bits (see `DATAADDRBUS_LEN), so the
//     data memory is exactly full: 256 words, no unreachable holes.
`define DMEMNUM 256

`define ZEROWORD 16'h0000
`define ZEROADDR 16'h0000

//---- field positions.  These never move, and each means one thing. ------
`define F_OPCODE 15:12
`define F_RD 11:10           // R, I
`define F_RS1 9: 8           // R, I, S
`define F_RS2 7: 6           // R, S
`define F_FUNCT 5: 0           // R
`define F_IMM 7: 0           // I S
`define F_IMM_H 11:10           // S: imm[7:6]
`define F_IMM_L 5: 0           // S: imm[5:0]

//---- opcodes ------------------------------------------------------------
`define OP_SYS 4'b0000         // does nothing; 0x0000 is NOP
`define OP_ALU 4'b0001         // Rd = funct(Rs1, Rs2)
`define OP_ADDI 4'b0010         // Rd = Rs1 + sext8(imm)
`define OP_ANDI 4'b0011         // Rd = Rs1 & zext8(imm)   -- a bit mask
`define OP_ORI 4'b0100         // Rd = Rs1 | zext8(imm)   -- pairs with LUI
`define OP_LI 4'b0101         // Rd = sext8(imm)
`define OP_LUI 4'b0110         // Rd = {imm, 8'h00}
`define OP_LD 4'b0111         // Rd = M[(Rs1 + sext8(imm))[7:0]]
`define OP_ST 4'b1000         // M[(Rs1 + sext8(imm))[7:0]] = Rs2
`define OP_BEQ 4'b1001         // if (Rs1 == Rs2) PC += sext8(imm)
`define OP_BNE 4'b1010         // if (Rs1 != Rs2) PC += sext8(imm)
`define OP_BLT 4'b1011         // if (Rs1 <  Rs2) PC += sext8(imm), signed
`define OP_BGE 4'b1100         // if (Rs1 >= Rs2) PC += sext8(imm), signed
`define OP_JAL 4'b1101         // Rd = PC+1; PC += sext8(imm)    (relative)
`define OP_JALR 4'b1110         // Rd = PC+1; PC = Rs1 + sext8(imm)
//                   4'b1111         reserved

//---- aluop, low half == R-type funct.  For OP_ALU this IS the control --
//     word, so the R-type path needs no control ROM.  Width `ALUOPBUS_LEN.
//     The trailing tag is the `SEL_* result category EX routes it to.
`define ALU_NOP 6'b000000       // result discarded          -- SEL_NOP
`define ALU_ADD 6'b000001       // a + b                     -- SEL_ARITH
`define ALU_SUB 6'b000010       // a - b                     -- SEL_ARITH
`define ALU_AND 6'b000011       // a & b                     -- SEL_LOGIC
`define ALU_OR 6'b000100       // a | b                     -- SEL_LOGIC
`define ALU_XOR 6'b000101       // a ^ b                     -- SEL_LOGIC
`define ALU_NOR 6'b000110       // ~(a | b)  NOT a is NOR a,a -- SEL_LOGIC
`define ALU_SLT 6'b000111       // signed   a < b ? 1 : 0     -- SEL_ARITH
`define ALU_SLTU 6'b001000       // unsigned a < b ? 1 : 0     -- SEL_ARITH
`define ALU_SLL 6'b001001       // a <<  b[3:0]               -- SEL_SHIFT
`define ALU_SRL 6'b001010       // a >>  b[3:0]               -- SEL_SHIFT
`define ALU_SRA 6'b001011       // a >>> b[3:0], sign-filled  -- SEL_SHIFT
//                   6'b001100 .. 6'b001111   reserved for future funct

//---- aluop, high half.  The non-R opcodes carry their own aluop, decoded
//     from `F_OPCODE in ID.  These sit in funct's reserved range and can
//     never appear as a real funct.
`define ALU_LD 6'b010000       // LD    -- EX adds R[Rs1] + sext8(imm)  -- SEL_LOAD_STORE
`define ALU_ST 6'b010001       // ST    -- EX adds R[Rs1] + sext8(imm)  -- SEL_LOAD_STORE
`define ALU_BEQ 6'b010010       // BEQ                                  -- SEL_JUMP_BRANCH
`define ALU_BNE 6'b010011       // BNE                                  -- SEL_JUMP_BRANCH
`define ALU_BLT 6'b010100       // BLT, signed                          -- SEL_JUMP_BRANCH
`define ALU_BGE 6'b010101       // BGE, signed                          -- SEL_JUMP_BRANCH
`define ALU_JAL 6'b010110       // JAL   -- EX forms the link value PC+1 -- SEL_JUMP_BRANCH
`define ALU_JALR 6'b010111       // JALR  -- EX forms the link value PC+1 -- SEL_JUMP_BRANCH
//                   6'b011000 .. 6'b111111   reserved

//---- alusel.  Which functional unit's result writes back.  EX switches
//     on this, then the unit switches on aluop.  SEL_NOP holds the result
//     at zero, so a zeroed ID/EX register discards it -- the zeros axiom.
`define ALUSELBUS_LEN 2:0
`define SEL_NOP 3'b000            // NOP
`define SEL_LOGIC 3'b001            // AND ANDI OR ORI XOR NOR
`define SEL_SHIFT 3'b010            // SLL SRL SRA
`define SEL_ARITH 3'b011            // ADD ADDI SUB SLT SLTU LI LUI
`define SEL_JUMP_BRANCH 3'b100            // BEQ BNE BLT BGE JAL JALR
`define SEL_LOAD_STORE 3'b101            // LD ST
//                       3'b110 .. 3'b111   reserved

`endif
