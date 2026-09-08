# Testbench

Tests for `cpu_core`. Nothing here yet — this is where they go.

## Running one

```sh
iverilog -g2005 -Isrc -o run testbench/my_test.v src/*.v
./run
```

`-Isrc` is required: every source file starts with `` `include "define_ISA.v" ``.

## The core

```verilog
cpu_core #(
    .LATENCY(1)      // cache cycles; >1 holds busy and exercises the stalls
) dut (
    .clk(clk),
    .rst(rst)        // active high, synchronous
);
```

Memory is inside the core, in `cache.v` — instruction and data are separate
(Harvard), both word-addressed, both zero-filled at time 0. Hold `rst` for a few
clocks before releasing it.

## Loading a program

Write one 16-bit word of hex per line and `$readmemh` it into the array. Do this
**after** time 0, because `cache.v` zero-fills from its own `initial` block:

```verilog
initial begin
    #1;
    $readmemh("testbench/prog/my_prog.hex", dut.u_cache.imem);
    $readmemh("testbench/prog/my_prog.data.hex", dut.u_cache.dmem);
end
```

`$readmemh` skips `//` comments, so keep the assembly next to the encoding:

```
// LI R0, #5
5005
// JAL R1, #0        ; halt -- jump to self
D400
```

Encodings are in [`doc/ISA.md`](../doc/ISA.md); every program needs a halt at the
end or the PC runs off into the zero-filled words, which are NOPs.

`JAL Rd, #0` halts by jumping to itself, and it still writes `PC+1` into `Rd` every
time round. Halt into a register the test does not check, or the halt overwrites the
answer.

## Checking the result

```verilog
dut.u_regfile.regs[0]      // R0 .. R3
dut.u_cache.dmem[8'hFF]    // a data word -- 0xFF is the LED port
dut.pc                     // the PC in IF
dut.id_inst                // the instruction in ID
dut.br  dut.br_addr        // branch resolved in ID, and its target
dut.stall                  // {WB, MEM, EX, ID, IF, PC}, 1 = frozen
```

## Two things worth doing

**Make a wrong answer survive.** If a test is meant to prove an instruction was
skipped, have that instruction write a value that nothing later overwrites.
Otherwise the check passes whether or not the instruction ran.

**Put the bug back.** After a test passes, break the thing it is supposed to
catch and confirm the test fails. A test that has never failed has not been
shown to test anything.

## A minimal test

```verilog
`timescale 1ns/1ps
module tb;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    cpu_core dut (.clk(clk), .rst(rst));

    initial begin
        #1; $readmemh("testbench/prog/my_prog.hex", dut.u_cache.imem);
        repeat (4) @(posedge clk);
        rst = 0;
        repeat (100) @(posedge clk);
        if (dut.u_regfile.regs[0] === 16'h0005) $display("PASS");
        else $display("FAIL  R0 = %h", dut.u_regfile.regs[0]);
        $finish;
    end
endmodule
```
