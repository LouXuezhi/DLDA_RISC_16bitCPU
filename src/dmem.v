`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  dmem -- data memory.  Write on the clock edge, read combinationally.
//
//  The combinational read is what lets LD finish in its own cycle: the
//  address comes out of the ALU, the word comes back, and the write-back
//  mux hands it to the register file before the edge.  The address is
//  already 8 bits, so the 256 words fill the data space exactly.
//=========================================================================

module dmem #(
    parameter INIT = ""
) (
    input  wire                    clk,
    input  wire                    we,
    input  wire [`DATAADDRBUS_LEN] addr,
    input  wire [     `REGBUS_LEN] wdata,
    output wire [     `REGBUS_LEN] rdata
);

    reg [`REGBUS_LEN] mem[0:`DMEMNUM-1];

    integer i;
    initial begin
        for (i = 0; i < `DMEMNUM; i = i + 1) mem[i] = `ZEROWORD;
        if (INIT != "") $readmemh(INIT, mem);
    end

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= wdata;
        end
    end

    assign rdata = mem[addr];

endmodule
