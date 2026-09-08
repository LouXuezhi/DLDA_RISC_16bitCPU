`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module regfile (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   we,
    input  wire [`REGADDRBUS_LEN] waddr,
    input  wire [    `REGBUS_LEN] wdata,
    input  wire                   re1,
    input  wire [`REGADDRBUS_LEN] raddr1,
    output reg  [    `REGBUS_LEN] rdata1,
    input  wire                   re2,
    input  wire [`REGADDRBUS_LEN] raddr2,
    output reg  [    `REGBUS_LEN] rdata2
);

  reg [`REGBUS_LEN] regs[0:`REGNUM-1];
  // this means the bitwidth is `REGBUS_LEN while there are `REGNUM of them

  // write
  always @(posedge clk) begin
    if (!rst) begin
      // no register is hardwired to zero -- four registers cannot spare one
      if (we) begin
        //$display("WRITE REGISTER FILE: x%d = %h", waddr, wdata);
        regs[waddr] <= wdata;
      end
    end
  end
  // Lou: wdata means write data.
  // Lou: waddr means write address.

  // read 1
  always @(*) begin
    if (rst || !re1) begin
      rdata1 = 0;
    end else if (we && raddr1 == waddr) begin
      rdata1 = wdata;
      // this is called data bypass, it is designed to address Read after
      // Write (RAW Hazard)
    end else begin
      rdata1 = regs[raddr1];
    end
  end

  // read 2
  always @(*) begin
    if (rst || !re2) begin
      rdata2 = 0;
    end else if (we && raddr2 == waddr) begin
      rdata2 = wdata;
    end else begin
      rdata2 = regs[raddr2];
    end
  end

endmodule
