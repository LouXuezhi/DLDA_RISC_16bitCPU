`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module if_stage (
    input wire rst,
    input wire clk,
    input wire [`INSTADDRBUS_LEN] pc_i,
    input wire [`REGBUS_LEN] mem_data_i,
    input wire mem_busy,
    input wire mem_done,
    input wire br,
    input wire br_ready,
    output reg mem_re,
    output reg [`INSTADDRBUS_LEN] mem_addr_o,
    output reg [`INSTADDRBUS_LEN] pc_o,
    output reg [`INSTBUS_LEN] inst_o,
    output reg stallreq
);
  reg mem_taking;
  reg mem_taking_next;
  reg waiting_for_br_ready;
  reg waiting_for_br_ready_next;



  always @(posedge clk) begin
    if (rst) begin
      mem_taking <= 0;
      waiting_for_br_ready <= 0;
    end else begin
      mem_taking <= mem_taking_next;
      waiting_for_br_ready <= waiting_for_br_ready_next;
    end
  end

  always @(*) begin
    mem_taking_next           = mem_taking;
    waiting_for_br_ready_next = waiting_for_br_ready;
    // default setting to avoid 'if' does not cover all cases.
    stallreq                  = 1'b0;
    mem_re                    = 1'b0;
    mem_addr_o                = 0;

    pc_o                      = 0;
    inst_o                    = 0;
    if (rst) begin
      mem_taking_next           = 1'b0;
      waiting_for_br_ready_next = 1'b0;
    end else if (br) begin
      // br generated from id_stage, which is faster.
      // so we need to wait for the pc_reg corrrectly update the pc_o
      mem_taking_next = 1'b0;
      waiting_for_br_ready_next = 1'b1;

    end else if (waiting_for_br_ready) begin
      // Not fetching this cycle, so the PC must not move: the redirected
      // PC is on pc_i right now and this is the only cycle it is there.
      // The stall belongs to the whole wait state, not to the cycle that
      // happens to leave it -- reg_pc gives br priority over stall, so
      // holding the PC here cannot block the next branch.
      stallreq = 1'b1;
      if (br_ready) begin
        waiting_for_br_ready_next = 1'b0;
      end

    end else if (!mem_taking) begin

      if (!mem_busy) begin
        mem_re          = 1'b1;
        mem_addr_o      = pc_i;
        stallreq        = 1'b1;

        mem_taking_next = 1'b1;
      end else begin
        stallreq = 1'b1;
      end

    end else begin

      if (mem_busy) begin
        stallreq = 1'b1;
      end else begin
        pc_o            = pc_i;
        inst_o          = mem_data_i;

        stallreq        = 1'b0;
        mem_taking_next = 1'b0;

      end
    end
  end
endmodule
