`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  tb_bench -- 跑一个核，数它花了多少周期、执行了哪些指令。
//
//    iverilog -g2005 -Isrc -o run bench/tb_bench.v src/*.v
//    ./run +name=fib +prog=bench/prog/fib.hex +r1=0c38
//
//  跑到停机为止，不是跑固定周期数：停机就是 doc/ISA.md 那个惯用法
//  `JAL Rx, #0`，看成「下一个 PC 等于本指令地址」。单周期核里停机指令
//  执行的那个周期，它前面的每条指令都已经写回，所以停下就能对答案。
//
//  Plus-arg：
//    +name=S        这一行叫什么（写进 CSV）
//    +prog=FILE     $readmemh 进指令存储
//    +data=FILE     $readmemh 进数据存储
//    +cap=N         没停机的话最多跑多少周期（默认 20000）
//    +r0=HHHH       期望的末态 R0（+r1 +r2 +r3 同）
//    +m=AA:HHHH     期望的末态数据字（+m1 +m2 同）
//    +trace         每周期一行
//
//  没给的期望值就不查。最后打一行 CSV 给 bench/run.sh 收。
//=========================================================================

module tb_bench;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    cpu_core dut (.clk(clk), .rst(rst));

    //---- 探针。改了微架构，要改的是这一块，别的地方不动。-----------------
    wire [`INSTBUS_LEN] inst    = dut.inst;
    wire [         3:0] opcode  = dut.inst[`F_OPCODE];
    wire                issuing = (inst != `ZEROWORD);
    wire                taken_s = (dut.pc_sel == `PC_REL);
    wire                halting = (dut.pc_sel != `PC_PLUS1) && (dut.next_pc == dut.pc);

    //---- 计数器 ---------------------------------------------------------
    integer cycles, insts;
    integer branches, taken, jumps, loads, stores;

    integer cap;
    integer errors;
    reg     tracing, done;
    reg [1023:0] name, prog, data;

    initial begin
        cycles = 0; insts = 0;
        branches = 0; taken = 0; jumps = 0; loads = 0; stores = 0;
        errors = 0; done = 0;
        name = "unnamed";
        tracing = $test$plusargs("trace");
        if (!$value$plusargs("cap=%d", cap)) cap = 20000;
        if ($value$plusargs("name=%s", name)) ;
    end

    // imem.v / dmem.v 在 0 时刻自己清零，所以程序要在那之后、放开复位之前灌进去。
    initial begin
        #1;
        if ($value$plusargs("prog=%s", prog)) $readmemh(prog, dut.u_imem.mem);
        if ($value$plusargs("data=%s", data)) $readmemh(data, dut.u_dmem.mem);
        repeat (4) @(posedge clk);
        rst = 0;
    end

    // 在下降沿采样：此时本周期的组合逻辑已经稳定，上升沿还没把它写掉。
    always @(negedge clk) begin
        if (!rst && !done) begin
            cycles = cycles + 1;

            if (issuing) begin
                insts = insts + 1;
                case (opcode)
                    `OP_LD:   loads    = loads + 1;
                    `OP_ST:   stores   = stores + 1;
                    `OP_JAL,
                    `OP_JALR: jumps    = jumps + 1;
                    `OP_BEQ, `OP_BNE, `OP_BLT, `OP_BGE: begin
                        branches = branches + 1;
                        if (taken_s) taken = taken + 1;
                    end
                    default: ;
                endcase
            end

            if (tracing)
                $display("%5d pc=%h inst=%h next=%h we=%b r%0d<=%h",
                         cycles, dut.pc, inst, dut.next_pc,
                         dut.reg_we, inst[`F_RD], dut.wb_data);

            if (halting) begin
                done = 1;
                // 让停机这条 JAL 自己的写回也落下去，再对答案。
                @(posedge clk); #1;
                report("PASS");
            end else if (cycles >= cap) begin
                done = 1;
                $display("  没等到停机指令，跑满了 %0d 周期", cap);
                errors = errors + 1;
                report("TIMEOUT");
            end
        end
    end

    //---- 对答案 ---------------------------------------------------------
    task check_reg(input [1023:0] who, input [15:0] got, input [15:0] want,
                   input has);
        begin
            if (has) begin
                if (got !== want) begin
                    $display("  FAIL  %0s = %h，期望 %h", who, got, want);
                    errors = errors + 1;
                end else $display("    ok  %0s = %h", who, got);
            end
        end
    endtask

    task check_mem(input [1023:0] spec, input has);
        reg [31:0] addr;
        reg [15:0] want;
        begin
            if (has && $sscanf(spec, "%h:%h", addr, want) == 2) begin
                if (dut.u_dmem.mem[addr[7:0]] !== want) begin
                    $display("  FAIL  M[%02h] = %h，期望 %h",
                             addr[7:0], dut.u_dmem.mem[addr[7:0]], want);
                    errors = errors + 1;
                end else $display("    ok  M[%02h] = %h", addr[7:0], want);
            end
        end
    endtask

    reg [15:0]   w0, w1, w2, w3;
    reg          h0, h1, h2, h3;
    reg [1023:0] ms0, ms1, ms2;
    reg          hm0, hm1, hm2;
    integer      cpi100;

    task report(input [1023:0] status);
        begin
            h0  = $value$plusargs("r0=%h", w0);
            h1  = $value$plusargs("r1=%h", w1);
            h2  = $value$plusargs("r2=%h", w2);
            h3  = $value$plusargs("r3=%h", w3);
            hm0 = $value$plusargs("m=%s",  ms0);
            hm1 = $value$plusargs("m1=%s", ms1);
            hm2 = $value$plusargs("m2=%s", ms2);

            check_reg("R0", dut.u_regfile.regs[0], w0, h0);
            check_reg("R1", dut.u_regfile.regs[1], w1, h1);
            check_reg("R2", dut.u_regfile.regs[2], w2, h2);
            check_reg("R3", dut.u_regfile.regs[3], w3, h3);
            check_mem(ms0, hm0);
            check_mem(ms1, hm1);
            check_mem(ms2, hm2);

            cpi100 = (insts == 0) ? 0 : (cycles * 100) / insts;

            // 一行 CSV，列的含义见 bench/run.sh 打的表头。
            $display("CSV,%0s,%0s,%0d,%0d,%0d.%02d,%0d,%0d,%0d,%0d,%0d",
                     name, (errors == 0) ? status : "FAIL",
                     cycles, insts, cpi100 / 100, cpi100 % 100,
                     branches, taken, jumps, loads, stores);
            $finish;
        end
    endtask

endmodule
