`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module if_stage (
    input wire rst,
    input wire clk,
    input wire [`INSTADDRBUS_LEN] pc,
    input wire [`REGBUS_LEN] imem_rdata,
    input wire imem_busy,
    input wire imem_done,
    input wire id_br,
    input wire pc_br_ready,
    output reg imem_re,
    output reg [`INSTADDRBUS_LEN] imem_addr,
    output reg [`INSTADDRBUS_LEN] if_pc,
    output reg [`INSTBUS_LEN] if_inst,
    output reg stallreq
);
  reg imem_taking;
  reg imem_taking_next;
  reg waiting_for_br_ready;
  reg waiting_for_br_ready_next;



  always @(posedge clk) begin
    if (rst) begin
      imem_taking <= 0;
      waiting_for_br_ready <= 0;
    end else begin
      imem_taking <= imem_taking_next;
      waiting_for_br_ready <= waiting_for_br_ready_next;
    end
  end

  always @(*) begin
    imem_taking_next           = imem_taking;
    waiting_for_br_ready_next = waiting_for_br_ready;
    // default setting to avoid 'if' does not cover all cases.
    stallreq                  = 1'b0;
    imem_re                    = 1'b0;
    imem_addr                = 0;

    if_pc                      = 0;
    if_inst                    = 0;
    if (rst) begin
      imem_taking_next           = 1'b0;
      waiting_for_br_ready_next = 1'b0;
    end else if (id_br) begin
      // id_br generated from id_stage, which is faster.
      // so we need to wait for the pc_reg corrrectly update the pc
      imem_taking_next = 1'b0;
      waiting_for_br_ready_next = 1'b1;

    end else if (waiting_for_br_ready) begin
      // Not fetching this cycle, so the PC must not move: the redirected
      // PC is on pc right now and this is the only cycle it is there.
      // The stall belongs to the whole wait state, not to the cycle that
      // happens to leave it -- pc_reg gives id_br priority over stall, so
      // holding the PC here cannot block the next branch.
      stallreq = 1'b1;
      if (pc_br_ready) begin
        waiting_for_br_ready_next = 1'b0;
      end

    end else if (!imem_taking) begin

      if (!imem_busy) begin
        imem_re          = 1'b1;
        imem_addr      = pc;
        stallreq        = 1'b1;

        imem_taking_next = 1'b1;
      end else begin
        stallreq = 1'b1;
      end

    end else begin

      if (imem_busy) begin
        stallreq = 1'b1;
      end else begin
        if_pc            = pc;
        if_inst          = imem_rdata;

        stallreq        = 1'b0;
        imem_taking_next = 1'b0;

      end
    end
  end
endmodule
