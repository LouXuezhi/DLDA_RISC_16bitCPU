`timescale 1ns/1ps
// mux3：sel 四个值（含未用的 3）× 500 组随机数据。每行：sel d0 d1 d2 y
module tb_mux3;
    reg  [ 1:0] sel;
    reg  [15:0] d0, d1, d2;
    wire [15:0] y;
    integer i, s, seed = 2;
    mux3 dut (.sel(sel), .d0(d0), .d1(d1), .d2(d2), .y(y));
    initial begin
        for (s = 0; s < 4; s = s + 1)
            for (i = 0; i < 500; i = i + 1) begin
                sel = s; d0 = $random(seed); d1 = $random(seed); d2 = $random(seed);
                #1 $display("%h %h %h %h %h", sel, d0, d1, d2, y);
            end
        $finish;
    end
endmodule
