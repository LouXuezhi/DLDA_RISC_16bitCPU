`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  cache -- the core's stand-in for instruction and data memory.
//
//  Harvard, one port each side, so IF and MEM never contend.  Word-
//  addressed: one index is one 16-bit word, on both sides.  The PC is 16
//  bits but only `IMEMNUM words exist, so imem is indexed by the low
//  `IMEMIDX_LEN bits; data addresses arrive already truncated to 8 bits by
//  EX, so dmem is exactly `DMEMNUM words with no unreachable holes.
//
//  Both sides speak the handshake if_stage.v and mem_stage.v implement:
//
//    cycle N    master sees busy == 0, raises re (or we) with addr
//    cycle N+1  master sees busy == 0 again -> rdata holds the result
//               master sees busy == 1      -> wait, rdata not yet valid
//
//  LATENCY == 1 is a block RAM: busy never rises and every access takes
//  two cycles.  LATENCY > 1 models a miss by holding busy for the extra
//  cycles, which is what exercises the stall paths.
//
//  Unwritten words read as `ZEROWORD, so an uninitialised memory executes
//  NOPs -- the zeros axiom, see doc/ISA.md.
//=========================================================================

module cache #(
    parameter INST_INIT = "",
    parameter DATA_INIT = "",
    parameter LATENCY   = 1
) (
    input wire clk,
    input wire rst,

    // instruction side -- read only
    input  wire                    imem_re,
    input  wire [`INSTADDRBUS_LEN] imem_addr,
    output wire [     `REGBUS_LEN] imem_rdata,
    output wire                    imem_busy,
    output wire                    imem_done,

    // data side
    input  wire                    dmem_re,
    input  wire                    dmem_we,
    input  wire [`DATAADDRBUS_LEN] dmem_addr,
    input  wire [     `REGBUS_LEN] dmem_wdata,
    output wire [     `REGBUS_LEN] dmem_rdata,
    output wire                    dmem_busy,
    output wire                    dmem_done
);

    reg [`REGBUS_LEN] imem[0:`IMEMNUM-1];
    reg [`REGBUS_LEN] dmem[0:`DMEMNUM-1];

    integer i;
    initial begin
        for (i = 0; i < `IMEMNUM; i = i + 1) imem[i] = `ZEROWORD;
        for (i = 0; i < `DMEMNUM; i = i + 1) dmem[i] = `ZEROWORD;
        if (INST_INIT != "") $readmemh(INST_INIT, imem);
        if (DATA_INIT != "") $readmemh(DATA_INIT, dmem);
    end

    reg [`REGBUS_LEN] imem_rdata_r;
    reg                imem_pending;
    reg                imem_done_r;
    reg [        7:0] imem_cnt;

    reg [`REGBUS_LEN] dmem_rdata_r;
    reg                dmem_pending;
    reg                dmem_done_r;
    reg [        7:0] dmem_cnt;

    assign imem_rdata = imem_rdata_r;
    assign imem_busy  = imem_pending;
    assign imem_done  = imem_done_r;

    assign dmem_rdata = dmem_rdata_r;
    assign dmem_busy  = dmem_pending;
    assign dmem_done  = dmem_done_r;

    // instruction side
    always @(posedge clk) begin
        if (rst) begin
            imem_rdata_r <= `ZEROWORD;
            imem_pending <= 0;
            imem_done_r  <= 0;
            imem_cnt     <= 0;
        end else if (imem_pending) begin
            if (imem_cnt == 0) begin
                imem_pending <= 0;
                imem_done_r  <= 1;
            end else begin
                imem_cnt    <= imem_cnt - 1;
                imem_done_r <= 0;
            end
        end else if (imem_re) begin
            imem_rdata_r <= imem[imem_addr[`IMEMIDX_LEN]];
            if (LATENCY <= 1) begin
                imem_pending <= 0;
                imem_done_r  <= 1;
            end else begin
                imem_pending <= 1;
                imem_done_r  <= 0;
                imem_cnt     <= LATENCY - 2;
            end
        end else begin
            imem_done_r <= 0;
        end
    end

    // data side
    always @(posedge clk) begin
        if (rst) begin
            dmem_rdata_r <= `ZEROWORD;
            dmem_pending <= 0;
            dmem_done_r  <= 0;
            dmem_cnt     <= 0;
        end else if (dmem_pending) begin
            if (dmem_cnt == 0) begin
                dmem_pending <= 0;
                dmem_done_r  <= 1;
            end else begin
                dmem_cnt    <= dmem_cnt - 1;
                dmem_done_r <= 0;
            end
        end else if (dmem_re || dmem_we) begin
            if (dmem_we) begin
                dmem[dmem_addr] <= dmem_wdata;
            end
            dmem_rdata_r <= dmem[dmem_addr];
            if (LATENCY <= 1) begin
                dmem_pending <= 0;
                dmem_done_r  <= 1;
            end else begin
                dmem_pending <= 1;
                dmem_done_r  <= 0;
                dmem_cnt     <= LATENCY - 2;
            end
        end else begin
            dmem_done_r <= 0;
        end
    end

endmodule
