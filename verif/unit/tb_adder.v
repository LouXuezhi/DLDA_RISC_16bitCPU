`timescale 1ns/1ps
// adder：边界值两两组合 + 5000 组随机。每行：a b y
module tb_adder;
    `include "corners.vh"
    reg  [15:0] a, b;
    wire [15:0] y;
    integer i, j, seed = 3;
    adder dut (.a(a), .b(b), .y(y));
    initial begin
        #1;
        for (i = 0; i < 12; i = i + 1)
            for (j = 0; j < 12; j = j + 1) begin
                a = corner[i]; b = corner[j];
                #1 $display("%h %h %h", a, b, y);
            end
        for (i = 0; i < 5000; i = i + 1) begin
            a = $random(seed); b = $random(seed);
            #1 $display("%h %h %h", a, b, y);
        end
        $finish;
    end
endmodule
