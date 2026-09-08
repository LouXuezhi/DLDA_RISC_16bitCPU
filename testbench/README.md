# 测试 · Testbench

`cpu_core` 的测试放在这里。目前还是空的。

*Tests for `cpu_core`. Nothing here yet — this is where they go.*

## 怎么跑 · Running one

```sh
iverilog -g2005 -Isrc -o run testbench/my_test.v src/*.v
./run
```

`-Isrc` 不能省：每个源文件开头都是 `` `include "define_ISA.v" ``，不给搜索路径就找不到。

*`-Isrc` is required: every source file starts with `` `include "define_ISA.v" ``.*

## 核的接口 · The core

```verilog
cpu_core #(
    .LATENCY(1)      // cache 延迟；>1 会拉高 busy，把暂停通路也测到
) dut (
    .clk(clk),
    .rst(rst)        // 高有效，同步复位
);
```

存储在核内部，见 `cache.v` —— 指令和数据分开（哈佛结构），都按字寻址（一个地址 = 一个
16 位字），上电时清零。复位要保持几个时钟再放开。

*Memory is inside the core, in `cache.v` — instruction and data are separate
(Harvard), both word-addressed, both zero-filled at time 0. `rst` is active high;
hold it for a few clocks before releasing it.*

## 装程序 · Loading a program

一行一个 16 位十六进制字，用 `$readmemh` 灌进数组。必须在 **0 时刻之后**做，因为
`cache.v` 自己在 `initial` 里清零：

*Write one 16-bit word of hex per line and `$readmemh` it into the array. Do this
after time 0, because `cache.v` zero-fills from its own `initial` block:*

```verilog
initial begin
    #1;
    $readmemh("testbench/prog/my_prog.hex", dut.u_cache.imem);
    $readmemh("testbench/prog/my_prog.data.hex", dut.u_cache.dmem);
end
```

`$readmemh` 会跳过 `//` 注释，所以把汇编写在编码旁边：

*`$readmemh` skips `//` comments, so keep the assembly next to the encoding:*

```
// LI R0, #5
5005
// JAL R1, #0        ; halt -- jump to self
D400
```

编码表在 [`doc/ISA.md`](../doc/ISA.md)。每个程序末尾都要有停机指令，否则 PC 会一路跑进
清零的存储区 —— 那里全是 NOP，程序不会崩，只是再也不做事了。

*Encodings are in [`doc/ISA.md`](../doc/ISA.md); every program needs a halt at the
end or the PC runs off into the zero-filled words, which are NOPs.*

> **坑：** `JAL Rd, #0` 靠跳转到自己来停机，但它**每转一圈都往 `Rd` 里写一次 `PC+1`**。
> 停机要用测试不检查的那个寄存器，否则停机指令会把答案覆盖掉。
>
> *`JAL Rd, #0` halts by jumping to itself, and it still writes `PC+1` into `Rd`
> every time round. Halt into a register the test does not check.*

## 看结果 · Checking the result

```verilog
dut.u_regfile.regs[0]      // R0 .. R3
dut.u_cache.dmem[8'hFF]    // 数据字；0xFF 是 LED 端口 -- the LED port
dut.pc                     // IF 级的 PC
dut.id_inst                // ID 级的指令
dut.br  dut.br_addr        // ID 解析出的分支及其目标
dut.stall                  // {WB, MEM, EX, ID, IF, PC}，1 = 冻结 frozen
```

## 两个值得养成的习惯 · Two things worth doing

**让错误的答案活到最后。** 如果一个测试想证明某条指令被跳过了，那条指令要写一个**后面
没人覆盖**的值。否则不管它有没有执行，检查都会通过 —— 这个测试等于没写。

*Make a wrong answer survive. If a test is meant to prove an instruction was
skipped, have that instruction write a value that nothing later overwrites.
Otherwise the check passes whether or not the instruction ran.*

**把 bug 塞回去。** 测试通过之后，故意把它该抓的东西改坏，确认它真的会失败。**一个从没
失败过的测试，没有被证明测到了任何东西。**

*Put the bug back. After a test passes, break the thing it is supposed to catch and
confirm the test fails. A test that has never failed has not been shown to test
anything.*

## 一个最小的测试 · A minimal test

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
