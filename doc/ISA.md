# 16 位 RISC 指令集 · 16-bit RISC ISA

`class_cpu` · 单周期：数据通路 + 控制单元，每条指令一个时钟。

编码定义在 [`src/define_ISA.v`](../src/define_ISA.v)。**本文是规范**；代码和规范不一致时，
在同一个 commit 里改掉其中一个。

*Encoding lives in [`src/define_ISA.v`](../src/define_ISA.v). This file is the spec;
if code and spec disagree, fix one of them in the same commit.*

## 公理 —— 全零即什么都不发生 · Axiom: all zeros means nothing happens

| 置零的东西 Zeroed | 含义 Means |
|---|---|
| 操作码 `0000` | 什么都不做，无论其余 12 位是什么 |
| `alu_op == 6'b000000` | NOP，结果为 0 且不写回 |
| `reg_we` `mem_we` | 全部高有效，所以 0 是惰性的 |
| 全零的控制字 | 不写寄存器、不写存储，`PC ← PC + 1` |

[`src/define_ctrl.v`](../src/define_ctrl.v) 里每个选择信号的 0 都是最常用、最无害的那一路，
所以控制单元对 `NOP` 和保留操作码只要输出全零。它还意味着一片没烧过程序的存储 —— 全零 ——
执行的是 NOP 而不是乱码。

*Every select in `define_ctrl.v` has its inert choice at 0, so for NOP and the reserved
opcode the control unit emits all zeros. An unprogrammed memory — all zeros — executes
NOPs instead of garbage.*

## 状态 · State

| | 位宽 Width | 数量 Count |
|---|---|---|
| 寄存器 `R0`–`R3` | 16 bit | 4，没有任何一个被硬连线 |
| PC | 16 bit | 1，下一条地址是 `PC + 1` |
| 指令存储 Instruction memory | 16 bit | `IMEMNUM` 字，当前实现为 1024 |
| 数据存储 Data memory | 16 bit | 256 字 —— 整个 8 位数据空间 |

**按字寻址（word-addressed）：一个地址选中一个 16 位字。** 没有对齐问题，没有字节使能。
这里根本不存在"字节"这个可寻址单位，所以 `LB`/`SB` 不是"暂时没做"，而是没有东西可以指代。

*Word-addressed: one address selects one 16-bit word. No alignment, no byte enable.
There is no byte, so `LB`/`SB` are not merely absent — they have nothing to name.*

两个空间大小不同是有意的。数据地址会被截断到 8 位，所以 256 字就是这个空间，正好装满。PC 是
16 位，指令空间比任何单条 `JAL` 能够到的范围都大，靠 `JALR` 覆盖；`IMEMNUM` 是实际例化了多少
字 —— **地址总线的宽度不等于承诺要造那么多存储**。

*The two spaces are sized differently on purpose. A data address is truncated to 8 bits,
so 256 words is the space, exactly full. The PC is 16 bits, so the instruction space is
larger than any one `JAL` can reach and is covered by `JALR`; `IMEMNUM` is how many of
those words are actually built, and an address bus is not a promise to build that much
memory.*

没有寄存器被硬连线成零 —— 一共四个寄存器，匀不出来一个。`LI` 和 `MOV` 惯用法替代了它的作用。

*No register is hardwired to zero — four registers cannot spare one.*

## 指令格式 · Formats

| | `[15:12]` | `[11:10]` | `[9:8]` | `[7:6]` | `[5:0]` |
|---|---|---|---|---|---|
| **R** | opcode | `Rd` | `Rs1` | `Rs2` | `funct` |
| **I** | opcode | `Rd` | `Rs1` | `imm[7:0]` 横跨两栏 ||
| **S** | opcode | `imm[7:6]` | `Rs1` | `Rs2` | `imm[5:0]` |

**每个字段在用到该格式的每条指令里都只有一个含义。**

`Rs1` 永远在 `[9:8]`，`Rs2` 永远在 `[7:6]`。寄存器堆的读端口直接接在指令字上，所以**读
寄存器和译码是并行的**。操作码只决定读回来的值用不用 —— 先读，后决定。

*`Rs1` is always `[9:8]` and `Rs2` always `[7:6]`. The register-file read ports hang
straight off the instruction word, so the read runs in parallel with decode. The
opcode only decides whether the returned value is used — read always, decide later.*

由此带来两个后果，都无害：S 格式没有 `Rd`，但 `inst[11:10]` 照读不误（`reg_we = 0`）；I 格式
没有 `Rs2`，但读口 2 照样读 `inst[7:6]`（`rs2_re = 0`）。

`ST` 和分支指令需要两个寄存器**外加** 8 位位移，`Rs2` 底下放不下 —— 于是高 2 位挪到 `Rd` 本
来的位置。这个拆分花的是连线，不是门：`{inst[11:10], inst[5:0]}` 是改个名，不是一次运算。

*`ST` and the branches need two registers and 8 bits of displacement, which does not fit
below `Rs2` — so the top 2 bits go where `Rd` would be. The split costs wires, not gates.*

## 指令 · Instructions

| Op | Fmt | 汇编 Assembly | 含义 Meaning |
|---|---|---|---|
| `0000` | — | `NOP` | 什么都不做。这个操作码下的任何编码都是 NOP |
| `0001` | R | `<alu> Rd, Rs1, Rs2` | `Rd ← funct(R[Rs1], R[Rs2])` |
| `0010` | I | `ADDI Rd, Rs1, #imm8` | `Rd ← R[Rs1] + sext8(imm)` |
| `0011` | I | `ANDI Rd, Rs1, #imm8` | `Rd ← R[Rs1] & zext8(imm)` |
| `0100` | I | `ORI  Rd, Rs1, #imm8` | `Rd ← R[Rs1] \| zext8(imm)` |
| `0101` | I | `LI   Rd, #imm8` | `Rd ← sext8(imm)` |
| `0110` | I | `LUI  Rd, #imm8` | `Rd ← {imm, 8'h00}` |
| `0111` | I | `LD   Rd, imm8(Rs1)` | `Rd ← M[(R[Rs1] + sext8(imm))[7:0]]` |
| `1000` | S | `ST   Rs2, imm8(Rs1)` | `M[(R[Rs1] + sext8(imm))[7:0]] ← R[Rs2]` |
| `1001` | S | `BEQ  Rs1, Rs2, #imm8` | `if (R[Rs1] == R[Rs2]) PC ← PC + sext8(imm)` |
| `1010` | S | `BNE  Rs1, Rs2, #imm8` | `if (!=)` 同上 |
| `1011` | S | `BLT  Rs1, Rs2, #imm8` | `if (<)` 有符号，同上 |
| `1100` | S | `BGE  Rs1, Rs2, #imm8` | `if (>=)` 有符号，同上 |
| `1101` | I | `JAL  Rd, #imm8` | `Rd ← PC+1 ; PC ← PC + sext8(imm)` |
| `1110` | I | `JALR Rd, imm8(Rs1)` | `Rd ← PC+1 ; PC ← R[Rs1] + sext8(imm)` |

操作码 `1111` 保留。

* `ST` 的第一个寄存器是**源**操作数 —— 要存进去的数据。这条指令不写回任何寄存器。
* 地址截断到 8 位。`LI R0,#0; ST R1,-1(R0)` 写的是地址 `0xFF`。
* 分支和 `JAL` 都是**相对于该指令自身**，不是相对于 `PC+1`。范围 ±128 字。
* `JAL` 的射程和分支一样；它多出来的是链接值，不是距离。8 位立即数配 16 位 PC，**没有任何
  单条指令能编码一个远目标**。
* 因此 `JALR` 是唯一能到达任意地址的指令 —— 它的目标来自寄存器，用 `LI` 或 `LUI`+`ORI` 先
  把地址凑出来。它同时也是返回指令和跳转表指令。
* 没有 `HALT`。`JAL Rx, #0` —— 跳转到自身 —— 是停机惯用法；专门做一条停机指令只能省电，而
  这个核没有任何需要停下来的状态。

> **注意：** `JAL Rx, #0` 每转一圈都会往 `Rx` 里写一次 `PC+1`。停机用的寄存器要挑一个后面
> 不再读的。

### `alu_op` · ALU op

**`alu_op` 就是 R 型的 `funct` 字段。** 对 `ALU` 操作码来说，这个 `funct` **本身就是** ALU 的
控制字，所以 R 型通路不需要任何控制 ROM。其他操作码借用其中的 `ADD`、`AND`、`OR`，见下面的
译码表。

| `funct` | | `funct` | | `funct` | |
|---|---|---|---|---|---|
| `000000` | *nop* | `000100` | `OR` | `001000` | `SLTU` |
| `000001` | `ADD` | `000101` | `XOR` | `001001` | `SLL` |
| `000010` | `SUB` | `000110` | `NOR` | `001010` | `SRL` |
| `000011` | `AND` | `000111` | `SLT` | `001011` | `SRA` |

`001100`–`001111` 保留给将来的 funct。移位量取 `b[3:0]`。*nop* 和保留码的 ALU 结果是 0，
而且不写回。

`BGT a,b` 汇编成 `BLT b,a`，`BLE a,b` 汇编成 `BGE b,a` —— 比较器对两个操作数是对称的，所以
交换不花代价。四个分支操作码因此覆盖了全部六种有符号关系。

*The comparator reads both operands symmetrically, so the swap is free. Four branch
opcodes therefore cover all six signed relations.*

**不要用 `a − b` 的符号位来做比较**：它会溢出，`0x8000 − 0x0001` = `0x7FFF` 会声称结果是
"正数"。要用 `(a[15] != b[15]) ? a[15] : borrow`。

## 有符号与无符号 · Signed and unsigned

数据通路本身不知道也不关心，只有三个地方例外。

| | 有符号和无符号有区别吗？ |
|---|---|
| `ADD` `SUB` `AND` `OR` `XOR` `NOR` `SLL` | 没有 —— 补码加法两种解释下位模式完全相同 |
| `SLT` vs `SLTU` | 有 —— 比较规则不同 |
| `SRA` vs `SRL` | 有 —— 空出来的高位填什么 |
| 溢出检测 overflow | 有 —— 进位输出 versus `N ⊕ V` |

除此之外，"有符号"是程序员加在一个位模式上的解释，不是硬件的属性。

*Everywhere else, "signed" is an interpretation the programmer puts on a bit pattern, not
a property of the hardware.*

## 立即数的展宽 · Widening the immediate

寄存器 16 位，立即数 8 位，所以每个立即数在进 ALU 之前都要展宽。**用哪种展宽取决于这个立即数
表示什么**，选错了会悄无声息地破坏高字节：

| 形式 Form | 产生 Produces | 谁在用 Used by | 因为这个立即数是 |
|---|---|---|---|
| `sext8` | `{{8{imm[7]}}, imm}` | `ADDI` `LD` `ST` `JALR` `LI` 分支 | 一个有符号数 —— `0xFF` 必须还是 `−1` |
| `zext8` | `{8'h00, imm}` | `ANDI` `ORI` | 一个位模式 —— `0xFF` 必须还是 `255` |
| `{imm, 8'h00}` | 高字节 | `LUI` | 一个常数的上半截 |

`ANDI Rd, Rs, #0xF0` 的意图是保留 bit 7–4。零扩展后掩码是 `0x00F0`，确实如此。符号扩展的话
掩码会变成 `0xFFF0`，**连整个高字节也一起保留了** —— 这是一个悄悄算错的结果，不是一个报错。
`ORI Rd, Rs, #0x80` 是同一个陷阱的反面：`0x0080` 置一位，`0xFF80` 置九位。

*A silent wrong answer, not an error.*

这就是为什么展宽方式是**按操作码逐条选**的，由控制单元的 `imm_sel` 决定，而不是整条数据
通路统一定一次。一个 16 位常数用 `LUI Rd,#hi` 加 `ORI Rd,Rd,#lo` 构造，而这个 `ORI` 之所以
能成立，正是因为它的立即数是零扩展的。

## 译码 · Decode

字段是无条件切出来的，在看操作码之前：

```verilog
wire [3:0] opcode = inst[15:12];
wire [1:0] rd     = inst[11:10];
wire [1:0] rs1    = inst[ 9: 8];
wire [1:0] rs2    = inst[ 7: 6];
wire [5:0] funct  = inst[ 5: 0];
wire [7:0] imm_i  = inst[ 7: 0];
wire [7:0] imm_s  = {inst[11:10], inst[5:0]};
```

然后 [`src/control_unit.v`](../src/control_unit.v) 用一个 `case (opcode)` 给出整组控制信号。
每个信号先置 0，每个操作码只拉高它要的那几个 —— 所以 `NOP` 和保留操作码 `1111` 落到全零。
编码在 [`src/define_ctrl.v`](../src/define_ctrl.v)。

*One `case (opcode)` in `control_unit.v` sets the whole control word. Every output starts
at 0 and each opcode raises only what it needs, so NOP and the reserved opcode fall through
as all zeros.*

| | `reg_we` | `mem_we` | `src_a` | `src_b` | `imm_sel` | `alu_op` | `wb_sel` | `pc_sel` |
|---|---|---|---|---|---|---|---|---|
| `SYS` | 0 | 0 | `REG` | `REG` | `SEXT_I` | `NOP` | `ALU` | `PLUS1` |
| `ALU` | funct 合法则 1 | 0 | `REG` | `REG` | `SEXT_I` | `funct` | `ALU` | `PLUS1` |
| `ADDI` | 1 | 0 | `REG` | `IMM` | `SEXT_I` | `ADD` | `ALU` | `PLUS1` |
| `ANDI` | 1 | 0 | `REG` | `IMM` | `ZEXT_I` | `AND` | `ALU` | `PLUS1` |
| `ORI` | 1 | 0 | `REG` | `IMM` | `ZEXT_I` | `OR` | `ALU` | `PLUS1` |
| `LI` | 1 | 0 | `ZERO` | `IMM` | `SEXT_I` | `ADD` | `ALU` | `PLUS1` |
| `LUI` | 1 | 0 | `ZERO` | `IMM` | `LUI_I` | `ADD` | `ALU` | `PLUS1` |
| `LD` | 1 | 0 | `REG` | `IMM` | `SEXT_I` | `ADD` | `MEM` | `PLUS1` |
| `ST` | 0 | 1 | `REG` | `IMM` | `SEXT_S` | `ADD` | `ALU` | `PLUS1` |
| 分支 | 0 | 0 | `REG` | `REG` | `SEXT_S` | `NOP` | `ALU` | 条件成立则 `REL` |
| `JAL` | 1 | 0 | `REG` | `REG` | `SEXT_I` | `NOP` | `PC1` | `REL` |
| `JALR` | 1 | 0 | `REG` | `IMM` | `SEXT_I` | `ADD` | `PC1` | `ALU` |

1. `ALU` 操作码只在 `funct` 是 `ADD`…`SRA` 之一时写回；`funct = 000000` 和保留的
   `001100`–`001111` 什么都不写。
2. `LD`/`ST` 的地址就是 ALU 的和，取低 8 位。`ST` 写入的数据是 `R[Rs2]`。
3. `LI`/`LUI` 把 ALU 的 `a` 端接 0，于是 `0 + imm` 就是要装的常数；它们的 `Rs1` 字段是立即数
   的一部分，被读但不用。
4. 写回 mux 三路：ALU 结果、数据存储读出、`PC + 1`（链接值）。
5. 分支只有 `pc_sel` 依赖数据：`branch_cmp` 给出 `eq` 和有符号 `lt`，`BEQ`/`BNE`/`BLT`/`BGE`
   分别取 `eq`/`!eq`/`lt`/`!lt`。

下一条 PC，一个三路 mux：

| `pc_sel` | `next_pc` | 谁用 |
|---|---|---|
| `PLUS1` | `PC + 1` | 其余所有指令、不跳的分支 |
| `REL` | `PC + imm` | 跳了的分支（`imm = sext8(imm_s)`）、`JAL`（`imm = sext8(imm_i)`） |
| `ALU` | ALU 结果，即 `R[Rs1] + sext8(imm_i)` | `JALR` |

`JAL` 和分支共用 `PC + imm` 这个加法器，区别只在立即数怎么拆；`JALR` 借用 ALU 算目标，
因为它自己不需要 ALU 算别的 —— 写回的是 `PC + 1`。

## 冒险 · Hazards

单周期核里没有冒险。每条指令在一个时钟内读寄存器、算、写回；写入在上升沿落下，下一条指令
在下一个周期读到它。所以没有前递、没有暂停、没有冲刷，分支也不杀指令。

*A single-cycle core has no hazards: each instruction's write lands on the clock edge and the
next instruction reads it in the next cycle. No forwarding, no stall, no flush.*

寄存器堆因此**不能**有写读旁路：写数据是由同一周期的读数据算出来的，旁路会闭合一个组合环
（`ADDI R0,R0,#1`：`rdata1 → ALU → wdata → rdata1`）。

## 伪指令 · Pseudo-instructions

| 写作 Written | 汇编成 Assembles to | 字数 Words |
|---|---|---|
| `NOP` | `0x0000` | 1 |
| `MOV  Rd, Rs` | `ADDI Rd, Rs, #0` | 1 |
| `NOT  Rd, Rs` | `NOR  Rd, Rs, Rs` | 1 |
| `NEG  Rd, Rs` | `NOR Rd,Rs,Rs` ; `ADDI Rd,Rd,#1` | 2 |
| `J    addr` | `JAL Rx, addr`，结果丢弃 | 1 |
| `HALT` | `JAL Rx, #0` —— 跳转到自身 | 1 |
| `RET  Rlink` | `JALR Rx, 0(Rlink)`，结果丢弃 | 1 |
| `LI16 Rd, #imm16` | `LUI Rd,#hi` ; `ORI Rd,Rd,#lo` | 2 |
| `BGT` `BLE` | 交换操作数 | 1 |

只有四个寄存器，一个可行的约定是 `R3` 作链接和临时，`R0`–`R2` 放数据。

## 示例 · Example

求 `M[0..3]` 之和，在 LED 上显示总数，然后停机。

```
        LI   R0, #0          ; i = 0
        LI   R1, #0          ; sum = 0
        LI   R3, #4          ; limit
loop:   LD   R2, 0(R0)       ; v = M[i]
        ADD  R1, R1, R2      ; sum += v
        ADDI R0, R0, #1      ; i++
        BLT  R0, R3, loop    ; while (i < 4)
        LI   R0, #0
        ST   R1, -1(R0)      ; M[0xFF] = sum  ->  LEDs
done:   JAL  R3, #0          ; 停机 —— 相对寻址，跳到自身就是 +0
```

| 地址 Addr | 位域 Bit fields | Hex |
|---|---|---|
| 0 | `0101 00 00 00000000` | `5000` |
| 1 | `0101 01 00 00000000` | `5400` |
| 2 | `0101 11 00 00000100` | `5C04` |
| 3 | `0111 10 00 00000000` | `7800` |
| 4 | `0001 01 01 10 000001` | `1581` |
| 5 | `0010 00 00 00000001` | `2001` |
| 6 | `1011 11 00 11 111101` | `BCFD` |
| 7 | `0101 00 00 00000000` | `5000` |
| 8 | `1000 11 00 01 111111` | `8C7F` |
| 9 | `1101 11 00 00000000` | `DC00` |



## 局限 · Limits

1. **只有四个寄存器。** 活跃值超过三个就得溢出到内存。把寄存器字段加宽到 3 位，等于从每个
   立即数里拿走 3 位 —— 那是另一套 ISA，不是改个参数。
2. **没有无符号分支。** `SLTU` 能把比较结果算进寄存器，但没有 `BLTU`。只要地址和计数器都
   小于 32768 就没问题。
3. **没有移位立即数。** `SLL Rd,Rs,Rt` 的移位量必须放在寄存器里 —— 要搭一条 `LI` 和一个
   寄存器。另一个方案是在立即数内部再切一个子字段，那会让立即数的宽度取决于它自己装的值。
4. **没有字节寻址。** 字节数组会浪费每个字的一半。仅仅在操作码 `1111` 上加 `LB`/`SB` 是不够
   的：字节根本不可寻址，加它意味着改变"一个地址选中多大一块"，随之而来的是两个存储上的对齐
   和字节使能问题。
5. **一个周期要走完整条通路。** 最长的一条是 `LD`：`pc → imem → regfile → ALU → dmem →
   写回 mux → regfile`，时钟周期不能短于它。单周期核的 CPI 恒为 1，换来的是这条长路径决定
   时钟频率。

## 验证 · Verification

测试放在 [`testbench/`](../testbench/)，写法见该目录下的 README。

一个测试的形状是：把十六进制程序 `$readmemh` 进 `dut.u_imem.mem`，跑若干周期，然后检查
寄存器和数据字（`dut.u_regfile.regs`、`dut.u_dmem.mem`）。



## 参考文献 · References

[1] Z. Fan, "RISC-V-CPU: a five-stage pipelined RISC-V CPU in Verilog HDL," *GitHub*,
2018. [Online]. Available: https://github.com/Evensgn/RISC-V-CPU

[2] A. Waterman and K. Asanović, Eds., *The RISC-V Instruction Set Manual, Volume I:
Unprivileged ISA*, document version 20191213, RISC-V Foundation, Dec. 2019.
