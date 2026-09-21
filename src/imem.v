`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  imem -- instruction memory, read only, combinational read.
//
//  A single-cycle core must fetch, decode, execute and write back inside
//  one clock, so the instruction has to appear in the same cycle the PC
//  does: no read latency.  On the FPGA this infers distributed (LUT) RAM,
//  not block RAM.  Only `IMEMNUM words exist; the PC's low `IMEMIDX_LEN
//  bits index them.
//
//  Unwritten words read as `ZEROWORD, which is NOP -- the zeros axiom.
//=========================================================================

module imem #(
    parameter INIT = ""
) (
    input  wire [`INSTADDRBUS_LEN] addr,
    output wire [    `INSTBUS_LEN] inst
);

    reg [`INSTBUS_LEN] mem[0:`IMEMNUM-1];

    integer i;
    initial begin
        for (i = 0; i < `IMEMNUM; i = i + 1) mem[i] = `ZEROWORD;
        if (INIT != "") $readmemh(INIT, mem);
    end

    assign inst = mem[addr[`IMEMIDX_LEN]];

endmodule
