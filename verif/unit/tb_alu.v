`timescale 1ns/1ps
// alu：全部 64 个 alu_op（含 NOP 和保留码）× (边界值两两 + 300 组随机)。
// 移位另扫一遍：b 取 0..31，让高位非零的移位量也出现。每行：op a b result
module tb_alu;
    `include "corners.vh"
    reg  [ 5:0] op;
    reg  [15:0] a, b;
    wire [15:0] result;
    integer k, i, j, seed = 4;
    alu dut (.alu_op(op), .a(a), .b(b), .result(result));
    initial begin
        #1;
        for (k = 0; k < 64; k = k + 1) begin
            op = k;
            for (i = 0; i < 12; i = i + 1)
                for (j = 0; j < 12; j = j + 1) begin
                    a = corner[i]; b = corner[j];
                    #1 $display("%h %h %h %h", op, a, b, result);
                end
            for (i = 0; i < 300; i = i + 1) begin
                a = $random(seed); b = $random(seed);
                #1 $display("%h %h %h %h", op, a, b, result);
            end
            for (i = 0; i < 12; i = i + 1)
                for (j = 0; j < 32; j = j + 1) begin
                    a = corner[i]; b = j;
                    #1 $display("%h %h %h %h", op, a, b, result);
                end
        end
        $finish;
    end
endmodule
