`timescale 1ns/1ps
// branch_cmp：边界值两两 + 相等的随机对 + 5000 组随机。每行：a b eq lt
module tb_branch_cmp;
    `include "corners.vh"
    reg  [15:0] a, b;
    wire        eq, lt;
    integer i, j, seed = 5;
    branch_cmp dut (.a(a), .b(b), .eq(eq), .lt(lt));
    initial begin
        #1;
        for (i = 0; i < 12; i = i + 1)
            for (j = 0; j < 12; j = j + 1) begin
                a = corner[i]; b = corner[j];
                #1 $display("%h %h %h %h", a, b, eq, lt);
            end
        for (i = 0; i < 500; i = i + 1) begin
            a = $random(seed); b = a;
            #1 $display("%h %h %h %h", a, b, eq, lt);
        end
        for (i = 0; i < 5000; i = i + 1) begin
            a = $random(seed); b = $random(seed);
            #1 $display("%h %h %h %h", a, b, eq, lt);
        end
        $finish;
    end
endmodule
