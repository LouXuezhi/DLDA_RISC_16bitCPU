`timescale 1ns/1ps
// regfile：3000 拍随机读写。每拍在上升沿之前打印本拍的输入和两个读口：
//   we waddr wdata raddr1 rdata1 raddr2 rdata2
// 写读同一寄存器的那一拍，读口必须还是旧值（没有旁路）。
module tb_regfile;
    reg         clk = 0, we = 0;
    reg  [ 1:0] waddr = 0, raddr1 = 0, raddr2 = 0;
    reg  [15:0] wdata = 0;
    wire [15:0] rdata1, rdata2;
    integer i, seed = 7;
    always #5 clk = ~clk;
    regfile dut (.clk(clk), .we(we), .waddr(waddr), .wdata(wdata),
                 .raddr1(raddr1), .rdata1(rdata1), .raddr2(raddr2), .rdata2(rdata2));
    initial begin
        for (i = 0; i < 3000; i = i + 1) begin
            @(negedge clk);
            we = $random(seed); waddr = $random(seed); wdata = $random(seed);
            raddr1 = $random(seed); raddr2 = $random(seed);
            #1 $display("%h %h %h %h %h %h %h", we, waddr, wdata, raddr1, rdata1, raddr2, rdata2);
        end
        $finish;
    end
endmodule
