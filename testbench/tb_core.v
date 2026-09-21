`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  tb_core -- 最简单的测试台：灌程序，跑到停机，每条指令打印一行 commit。
//  对不对由 verif/run.py 拿 ISS（verif/model/iss.py）的输出逐行比较。
//
//    ./sim +prog=P.hex [+data=D.hex] [+cap=N]
//
//  每行格式和 iss.py 的 Commit.__str__ 一字不差：
//    C pc=0003 inst=7800 next=0004 r2<=0005
//    C pc=0008 inst=8c7f next=0009 M[ff]<=000a
//=========================================================================

module tb_core;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    cpu_core dut (.clk(clk), .rst(rst));

    reg [1023:0] prog, data;
    integer      cap, n;

    initial begin
        #1;
        if ($value$plusargs("prog=%s", prog)) $readmemh(prog, dut.u_imem.mem);
        if ($value$plusargs("data=%s", data)) $readmemh(data, dut.u_dmem.mem);
        if (!$value$plusargs("cap=%d", cap)) cap = 20000;
        n = 0;
        repeat (2) @(posedge clk);
        rst = 0;
    end

    // 下降沿：本条指令的组合逻辑已稳定，上升沿还没把它写掉。
    always @(negedge clk) begin
        if (!rst) begin
            if (dut.reg_we)
                $display("C pc=%h inst=%h next=%h r%0d<=%h",
                         dut.pc, dut.inst, dut.next_pc, dut.inst[`F_RD], dut.wb_data);
            else if (dut.mem_we)
                $display("C pc=%h inst=%h next=%h M[%h]<=%h",
                         dut.pc, dut.inst, dut.next_pc,
                         dut.alu_result[`DATAADDRBUS_LEN], dut.u_dmem.wdata);
            else
                $display("C pc=%h inst=%h next=%h", dut.pc, dut.inst, dut.next_pc);
            n = n + 1;
            if (dut.next_pc == dut.pc || n >= cap) $finish;
        end
    end

endmodule
