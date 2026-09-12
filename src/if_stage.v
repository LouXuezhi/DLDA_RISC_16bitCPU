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
    // ds_stall == ctrl_stall[`STALL_ID]: the push-side ready, driven low by
    // ID/EX/MEM.  No combinational loop: in ctrl.v if_stallreq only ever sets
    // bits 0 and 1, so bit 2 can never depend on what this module outputs.
    input wire ds_stall,
    output reg imem_re,
    output reg [`INSTADDRBUS_LEN] imem_addr,
    output reg [`INSTADDRBUS_LEN] if_pc,
    output reg [`INSTBUS_LEN] if_inst,
    output reg if_valid,
    output reg stallreq
);

  // The request in flight: pc_reg is its address, inflight says it has not
  // come back yet.  At most one can be in flight -- cache.v refuses a second
  // while imem_busy, and at LATENCY == 1 the first completes in one cycle.
  reg                    inflight;
  reg [`INSTADDRBUS_LEN] pc_reg;

  // The skid slot.  The answer side has no ready line: the memory hands back
  // a word whether or not ID can take it, so the one request that was already
  // in flight when the stall arrived needs somewhere to land.  One slot is
  // enough, and can_issue below is what keeps it that way.
  reg                    skid_valid;
  reg [`INSTADDRBUS_LEN] pc_cached;
  reg [    `INSTBUS_LEN] inst_cached;

  // A redirect leaves one wrong-path request in flight that cannot be
  // cancelled; drop the word when it arrives.
  reg                    kill_next;

  // This cycle imem_rdata holds a word worth keeping.
  wire answer_keep = imem_done && inflight && !kill_next;

  // Issue only when the word will have somewhere to go: ds_stall means ID
  // cannot take it and the PC cannot move, skid_valid means the one slot is
  // already spoken for.
  wire can_issue = !rst && !imem_busy && !skid_valid && !ds_stall && !id_br;

  // Probe for bench/tb_bench.v: this cycle fetch was blocked by a redirect.
  wire br_wait = id_br;

  always @(*) begin
    imem_re   = can_issue;
    imem_addr = pc;
    // New meaning: "no request went out this cycle", which is exactly when
    // the PC must hold.  pc_reg.v needs no change because of this.
    stallreq  = !rst && !can_issue;
  end

  always @(*) begin
    if (rst) begin
      if_valid = 1'b0;
      if_pc    = 0;
      if_inst  = 0;
    end else if (skid_valid) begin
      if_valid = 1'b1;
      if_pc    = pc_cached;
      if_inst  = inst_cached;
    end else begin
      if_valid = answer_keep;
      if_pc    = pc_reg;
      if_inst  = imem_rdata;
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      inflight    <= 1'b0;
      pc_reg      <= 0;
      skid_valid  <= 1'b0;
      pc_cached   <= 0;
      inst_cached <= 0;
      kill_next   <= 1'b0;
    end else begin
      if (imem_re) begin
        inflight <= 1'b1;
        pc_reg   <= pc;
      end else if (imem_done) begin
        inflight <= 1'b0;
      end

      if (id_br) begin
        kill_next <= inflight && !imem_done;
      end else if (imem_done) begin
        kill_next <= 1'b0;
      end

      if (id_br) begin
        skid_valid <= 1'b0;
      end else if (skid_valid) begin
        if (!ds_stall) skid_valid <= 1'b0;
      end else if (answer_keep && ds_stall) begin
        skid_valid  <= 1'b1;
        pc_cached   <= pc_reg;
        inst_cached <= imem_rdata;
      end
    end
  end

endmodule
