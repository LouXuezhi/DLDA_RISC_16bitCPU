`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  tb_cpu_core -- runs one program and checks the state it leaves behind.
//
//    iverilog -g2005 -Isrc -o run tb/tb_cpu_core.v src/*.v
//    ./run +prog=tb/prog/sum.hex +data=tb/prog/sum.data.hex +r1=000a
//
//  Plus-args, all optional:
//    +prog=FILE     $readmemh into instruction memory
//    +data=FILE     $readmemh into data memory
//    +cycles=N      cycles to run after reset (default 200)
//  (cache latency is the LATENCY parameter, see below)
//    +r0=HHHH       expected final R0   (likewise +r1 +r2 +r3)
//    +m=AA:HHHH     expected final data word at address AA (also +m1 +m2)
//    +trace         one line per cycle
//
//  An expectation that is not given is not checked.  The run prints PASS
//  or FAIL; tb/run.sh turns that into an exit status.
//=========================================================================

module tb_cpu_core;

    // Cache latency is a parameter, not a plus-arg, because it is a
    // parameter of the design.  tb/run.sh builds a second binary with
    //   iverilog -Ptb_cpu_core.LATENCY=4
    // to prove a slow memory changes timing but never results.
    parameter LATENCY = 1;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    integer      cycles;
    reg [1023:0] prog;
    reg [1023:0] data;

    cpu_core #(
        .LATENCY(LATENCY)
    ) dut (
        .clk(clk),
        .rst(rst)
    );

    // cache.v fills its arrays from an initial block at time 0, so load the
    // program strictly after that, and before reset is released.
    initial begin
        #1;
        if ($value$plusargs("prog=%s", prog)) $readmemh(prog, dut.u_cache.imem);
        if ($value$plusargs("data=%s", data)) $readmemh(data, dut.u_cache.dmem);
    end

    integer n;
    integer errors;
    reg     tracing;

    initial begin
        errors  = 0;
        n       = 0;
        tracing = $test$plusargs("trace");
        if (!$value$plusargs("cycles=%d", cycles)) cycles = 200;
        repeat (4) @(posedge clk);
        rst = 0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            n = n + 1;
            if (tracing) begin
                $display("%4d pc=%h inst=%h br=%b tgt=%h stall=%b | wb we=%b r%0d<=%h | %h %h %h %h",
                         n, dut.pc, dut.id_inst, dut.br, dut.br_addr, dut.stall,
                         dut.wb_we, dut.wb_reg_waddr, dut.wb_reg_wdata,
                         dut.u_regfile.regs[0], dut.u_regfile.regs[1],
                         dut.u_regfile.regs[2], dut.u_regfile.regs[3]);
            end
            if (n >= cycles) finish_run;
        end
    end

    task check_reg(input [1023:0] name, input [15:0] got, input [15:0] want,
                   input got_expectation);
        begin
            if (got_expectation) begin
                if (got !== want) begin
                    $display("FAIL  %0s = %h, expected %h", name, got, want);
                    errors = errors + 1;
                end else begin
                    $display("  ok  %0s = %h", name, got);
                end
            end
        end
    endtask

    task check_mem(input [1023:0] spec, input got_expectation);
        reg [31:0] addr;
        reg [15:0] want;
        begin
            if (got_expectation) begin
                if ($sscanf(spec, "%h:%h", addr, want) == 2) begin
                    if (dut.u_cache.dmem[addr[7:0]] !== want) begin
                        $display("FAIL  M[%02h] = %h, expected %h",
                                 addr[7:0], dut.u_cache.dmem[addr[7:0]], want);
                        errors = errors + 1;
                    end else begin
                        $display("  ok  M[%02h] = %h", addr[7:0], want);
                    end
                end
            end
        end
    endtask

    reg [15:0]   w0, w1, w2, w3;
    reg          h0, h1, h2, h3;
    reg [1023:0] ms0, ms1, ms2;
    reg          hm0, hm1, hm2;

    task finish_run;
        begin
            h0  = $value$plusargs("r0=%h", w0);
            h1  = $value$plusargs("r1=%h", w1);
            h2  = $value$plusargs("r2=%h", w2);
            h3  = $value$plusargs("r3=%h", w3);
            hm0 = $value$plusargs("m=%s", ms0);
            hm1 = $value$plusargs("m1=%s", ms1);
            hm2 = $value$plusargs("m2=%s", ms2);

            check_reg("R0", dut.u_regfile.regs[0], w0, h0);
            check_reg("R1", dut.u_regfile.regs[1], w1, h1);
            check_reg("R2", dut.u_regfile.regs[2], w2, h2);
            check_reg("R3", dut.u_regfile.regs[3], w3, h3);
            check_mem(ms0, hm0);
            check_mem(ms1, hm1);
            check_mem(ms2, hm2);

            if (errors == 0) $display("PASS  (%0d cycles)", n);
            else             $display("FAIL  %0d mismatch(es)", errors);
            $finish;
        end
    endtask

endmodule
