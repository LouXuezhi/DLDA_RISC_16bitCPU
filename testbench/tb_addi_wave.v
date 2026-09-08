`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  tb_addi_wave -- 跑 ADDI R1, R0, #10，导出 VCD 供 Surfer/GTKWave 查看。
//
//    iverilog -g2005 -Isrc -o run testbench/tb_addi_wave.v src/*.v
//    ./run                       # 生成 addi.vcd
//    surver addi.vcd             # 然后用 Surfer 客户端连它
//
//  这个 ISA 没有硬连线的零寄存器，所以 ADDI R1,R0,#10 要先把 R0 造成 0。
//=========================================================================

module tb_addi_wave;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    cpu_core dut (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        $dumpfile("addi.vcd");
        $dumpvars(0, tb_addi_wave);
        #1;
        $readmemh("testbench/prog/addi.hex", dut.u_cache.imem);
        repeat (2) @(posedge clk);
        rst = 0;
        repeat (14) @(posedge clk);
        $display("R0=%h R1=%h", dut.u_regfile.regs[0], dut.u_regfile.regs[1]);
        $finish;
    end

endmodule
