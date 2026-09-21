`timescale 1ns/1ps
// imem：INIT 预装。先按 0..1023 读一遍，再读 3000 个随机 16 位地址
// （高位非零，要回卷到低 10 位）。每行：addr inst
module tb_imem;
    parameter INIT = "";
    reg  [15:0] addr;
    wire [15:0] inst;
    integer i, seed = 9;
    imem #(.INIT(INIT)) dut (.addr(addr), .inst(inst));
    initial begin
        #1;
        for (i = 0; i < 1024; i = i + 1) begin
            addr = i;
            #1 $display("%h %h", addr, inst);
        end
        for (i = 0; i < 3000; i = i + 1) begin
            addr = $random(seed);
            #1 $display("%h %h", addr, inst);
        end
        $finish;
    end
endmodule
