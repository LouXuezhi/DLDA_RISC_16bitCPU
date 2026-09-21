`timescale 1ns/1ps
// pc_reg：3000 拍随机 next_pc，rst 大约每 10 拍拉高一次。
// 每拍在上升沿之前打印：rst next_pc pc
module tb_pc_reg;
    reg         clk = 0, rst = 1;
    reg  [15:0] next_pc = 0;
    wire [15:0] pc;
    integer i, seed = 6;
    always #5 clk = ~clk;
    pc_reg dut (.clk(clk), .rst(rst), .next_pc(next_pc), .pc(pc));
    initial begin
        for (i = 0; i < 3000; i = i + 1) begin
            @(negedge clk);
            rst = (i < 2) || ($random(seed) % 10 == 0);
            next_pc = $random(seed);
            #1 $display("%h %h %h", rst, next_pc, pc);
        end
        $finish;
    end
endmodule
