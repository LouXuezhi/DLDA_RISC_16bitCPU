`timescale 1ns/1ps
`ifndef DEFINE_ISA_V
`define DEFINE_ISA_V

//=========================================================================
//  class_cpu -- 16-bit RISC ISA.  Programmer-visible encoding only.
//  Spec: doc/ISA.md
//
//  AXIOM: all zeros means nothing happens.
//    inst == 16'h0000 -> SYS/NOP.  Never break this: flush and stall both
//    work by writing zeros into a pipeline register.
//=========================================================================

//---- widths -------------------------------------------------------------
`define InstBus      15:0
`define RegBus       15:0            // register file / ALU datapath
`define RegAddrBus    1:0
`define AddrBus       7:0            // word address, both memories
`define AluOpBus      5:0            // == the R-type funct field
`define RegNum        4
`define MemNum      256              // words per memory

`define ZeroWord    16'h0000
`define ZeroAddr     8'h00

//---- field positions.  These never move. --------------------------------
`define F_OPCODE     15:12
`define F_RD         11:10           // R, I
`define F_RS1         9: 8           // R, I, S
`define F_RS2         7: 6           // R, S
`define F_FUNCT       5: 0           // R
`define F_IMM_I       7: 0           // I
`define F_F2         11:10           // S: ST imm[7:6], or branch condition
`define F_IMM_SL      5: 0           // S: imm[5:0]

//---- opcodes ------------------------------------------------------------
`define OP_SYS       4'b0000         // writes nothing; 0x0000 is NOP
`define OP_ALU       4'b0001         // Rd = funct(Rs1, Rs2)
`define OP_ADDI      4'b0010         // Rd = Rs1 + sext8(imm)
`define OP_ANDI      4'b0011         // Rd = Rs1 & zext8(imm)
`define OP_ORI       4'b0100         // Rd = Rs1 | zext8(imm)   -- pairs with LUI
`define OP_LI        4'b0101         // Rd = sext8(imm)
`define OP_LUI       4'b0110         // Rd = {imm, 8'h00}
`define OP_LD        4'b0111         // Rd = M[Rs1 + sext8(imm)]
`define OP_ST        4'b1000         // M[Rs1 + sext8(imm)] = Rs2
`define OP_BR        4'b1001         // if (cc) PC = PC + sext6(imm)
`define OP_JAL       4'b1010         // Rd = PC+1; PC = imm          (absolute)
`define OP_JALR      4'b1011         // Rd = PC+1; PC = Rs1 + sext8(imm)
//                   4'b1100 .. 4'b1111   reserved

//---- SYS funct.  Any other funct decodes as NOP. ------------------------
`define SYS_NOP      6'b000000       // do nothing
`define SYS_HALT     6'b000001       // freeze the PC until reset

//---- ALU funct.  For OP_ALU this IS the control word, so the R-type -----
//     path needs no control ROM.  funct[5:4] = 00; 01/10/11 reserved.
`define ALU_NOP      6'b000000       // result discarded
`define ALU_ADD      6'b000001       // a + b
`define ALU_SUB      6'b000010       // a - b
`define ALU_AND      6'b000011       // a & b
`define ALU_OR       6'b000100       // a | b
`define ALU_XOR      6'b000101       // a ^ b
`define ALU_NOR      6'b000110       // ~(a | b)         -- NOT a is NOR a,a
`define ALU_SLT      6'b000111       // signed   a < b ? 1 : 0
`define ALU_SLTU     6'b001000       // unsigned a < b ? 1 : 0
`define ALU_SLL      6'b001001       // a <<  b[3:0]
`define ALU_SRL      6'b001010       // a >>  b[3:0]
`define ALU_SRA      6'b001011       // a >>> b[3:0], sign-filled
//                   6'b001100 .. 6'b111111   reserved

//---- branch condition, inst[11:10].  Signed. ----------------------------
//     BGT/BLE are these with the two source registers swapped.
`define CC_EQ        2'b00           // Rs1 == Rs2
`define CC_NE        2'b01           // Rs1 != Rs2
`define CC_LT        2'b10           // Rs1 <  Rs2
`define CC_GE        2'b11           // Rs1 >= Rs2

`endif
