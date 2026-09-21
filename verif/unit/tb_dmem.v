`timescale 1ns/1ps
// dmem：INIT 预装，然后 5000 拍随机读写。每拍在上升沿之前打印：
//   we addr wdata rdata
// 读是组合的；写在上升沿生效，所以写的那一拍读到的是旧值。
module tb_dmem;
    parameter INIT = "";
    reg         clk = 0, we = 0;
    reg  [ 7:0] addr = 0;
    reg  [15:0] wdata = 0;
    wire [15:0] rdata;
    integer i, seed = 8;
    always #5 clk = ~clk;
    dmem #(.INIT(INIT)) dut (.clk(clk), .we(we), .addr(addr), .wdata(wdata), .rdata(rdata));
    initial begin
        for (i = 0; i < 256; i = i + 1) begin      // 先把预装内容和零初始化全读一遍
            @(negedge clk); we = 0; addr = i;
            #1 $display("%h %h %h %h", we, addr, wdata, rdata);
        end
        for (i = 0; i < 5000; i = i + 1) begin
            @(negedge clk);
            we = $random(seed); addr = $random(seed); wdata = $random(seed);
            #1 $display("%h %h %h %h", we, addr, wdata, rdata);
        end
        $finish;
    end
endmodule
