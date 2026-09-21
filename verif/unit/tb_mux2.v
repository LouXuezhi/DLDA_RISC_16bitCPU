`timescale 1ns/1ps
// mux2：sel 两个值 × 500 组随机数据。每行：sel d0 d1 y
module tb_mux2;
    reg         sel;
    reg  [15:0] d0, d1;
    wire [15:0] y;
    integer i, s, seed = 1;
    mux2 dut (.sel(sel), .d0(d0), .d1(d1), .y(y));
    initial begin
        for (s = 0; s < 2; s = s + 1)
            for (i = 0; i < 500; i = i + 1) begin
                sel = s; d0 = $random(seed); d1 = $random(seed);
                #1 $display("%h %h %h %h", sel, d0, d1, y);
            end
        $finish;
    end
endmodule
