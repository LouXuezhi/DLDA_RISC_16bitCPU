`timescale 1ns/1ps
// imm_ext：穷举。全部 65536 个指令字 × 4 种 imm_sel。每行：inst sel imm
module tb_imm_ext;
    reg  [15:0] inst;
    reg  [ 1:0] sel;
    wire [15:0] imm;
    integer i, s;
    imm_ext dut (.inst(inst), .imm_sel(sel), .imm(imm));
    initial begin
        for (s = 0; s < 4; s = s + 1)
            for (i = 0; i < 65536; i = i + 1) begin
                sel = s; inst = i;
                #1 $display("%h %h %h", inst, sel, imm);
            end
        $finish;
    end
endmodule
