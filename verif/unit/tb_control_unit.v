`timescale 1ns/1ps
// control_unit：穷举。rst=0 时全部 65536 个指令字 × eq × lt；
// rst=1 时同样穷举，控制字必须全零。
// 每行：rst inst eq lt reg_we mem_we src_a src_b imm_sel alu_op wb_sel pc_sel
module tb_control_unit;
    reg         rst, eq, lt;
    reg  [15:0] inst;
    wire        reg_we, mem_we, src_a, src_b;
    wire [ 1:0] imm_sel, wb_sel, pc_sel;
    wire [ 5:0] alu_op;
    integer r, i, f;
    control_unit dut (.rst(rst), .inst(inst), .eq(eq), .lt(lt),
                      .reg_we(reg_we), .mem_we(mem_we), .src_a(src_a), .src_b(src_b),
                      .imm_sel(imm_sel), .alu_op(alu_op), .wb_sel(wb_sel), .pc_sel(pc_sel));
    initial begin
        for (r = 0; r < 2; r = r + 1)
            for (i = 0; i < 65536; i = i + 1)
                for (f = 0; f < 4; f = f + 1) begin
                    rst = r; inst = i; {eq, lt} = f;
                    #1 $display("%h %h %h %h %h %h %h %h %h %h %h %h", rst, inst, eq, lt,
                                reg_we, mem_we, src_a, src_b, imm_sel, alu_op, wb_sel, pc_sel);
                end
        $finish;
    end
endmodule
