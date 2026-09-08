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
    input  wire                    clk,
    input  wire                    rst,

    // instruction side -- read only
    input  wire                    i_re,
    input  wire [`INSTADDRBUS_LEN] i_addr,
    output wire [    `REGBUS_LEN] i_rdata,
    output wire                    i_busy,
    output wire                    i_done,

    // data side
    input  wire                    d_re,
    input  wire                    d_we,
    input  wire [`DATAADDRBUS_LEN] d_addr,
    input  wire [    `REGBUS_LEN] d_wdata,
    output wire [    `REGBUS_LEN] d_rdata,
    output wire                    d_busy,
    output wire                    d_done
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

    reg [`REGBUS_LEN] i_rdata_r;
    reg                i_pending;
    reg                i_done_r;
    reg [        7:0] i_cnt;

    reg [`REGBUS_LEN] d_rdata_r;
    reg                d_pending;
    reg                d_done_r;
    reg [        7:0] d_cnt;

    assign i_rdata = i_rdata_r;
    assign i_busy  = i_pending;
    assign i_done  = i_done_r;

    assign d_rdata = d_rdata_r;
    assign d_busy  = d_pending;
    assign d_done  = d_done_r;

    // instruction side
    always @(posedge clk) begin
        if (rst) begin
            i_rdata_r <= `ZEROWORD;
            i_pending <= 0;
            i_done_r  <= 0;
            i_cnt     <= 0;
        end else if (i_pending) begin
            if (i_cnt == 0) begin
                i_pending <= 0;
                i_done_r  <= 1;
            end else begin
                i_cnt    <= i_cnt - 1;
                i_done_r <= 0;
            end
        end else if (i_re) begin
            i_rdata_r <= imem[i_addr[`IMEMIDX_LEN]];
            if (LATENCY <= 1) begin
                i_pending <= 0;
                i_done_r  <= 1;
            end else begin
                i_pending <= 1;
                i_done_r  <= 0;
                i_cnt     <= LATENCY - 2;
            end
        end else begin
            i_done_r <= 0;
        end
    end

    // data side
    always @(posedge clk) begin
        if (rst) begin
            d_rdata_r <= `ZEROWORD;
            d_pending <= 0;
            d_done_r  <= 0;
            d_cnt     <= 0;
        end else if (d_pending) begin
            if (d_cnt == 0) begin
                d_pending <= 0;
                d_done_r  <= 1;
            end else begin
                d_cnt    <= d_cnt - 1;
                d_done_r <= 0;
            end
        end else if (d_re || d_we) begin
            if (d_we) begin
                dmem[d_addr] <= d_wdata;
            end
            d_rdata_r <= dmem[d_addr];
            if (LATENCY <= 1) begin
                d_pending <= 0;
                d_done_r  <= 1;
            end else begin
                d_pending <= 1;
                d_done_r  <= 0;
                d_cnt     <= LATENCY - 2;
            end
        end else begin
            d_done_r <= 0;
        end
    end

endmodule
