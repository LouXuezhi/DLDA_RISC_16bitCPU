`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  regfile -- R0..R3.  Two combinational read ports, one write port that
//  writes on the clock edge.
//
//  No write-to-read bypass.  In a single-cycle core the write data is
//  computed from the read data in the same cycle, so a bypass would close
//  a combinational loop (ADDI R0,R0,#1: rdata1 -> ALU -> wdata -> rdata1).
//  The write lands on the edge and the next instruction reads it.
//
//  No register is hardwired to zero -- four registers cannot spare one.
//=========================================================================

module regfile (
    input  wire                   clk,
    input  wire                   we,
    input  wire [`REGADDRBUS_LEN] waddr,
    input  wire [    `REGBUS_LEN] wdata,
    input  wire [`REGADDRBUS_LEN] raddr1,
    output wire [    `REGBUS_LEN] rdata1,
    input  wire [`REGADDRBUS_LEN] raddr2,
    output wire [    `REGBUS_LEN] rdata2
);

    reg [`REGBUS_LEN] regs[0:`REGNUM-1];

    always @(posedge clk) begin
        if (we) begin
            regs[waddr] <= wdata;
        end
    end

    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];

endmodule
