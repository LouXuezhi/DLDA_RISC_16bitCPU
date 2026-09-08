# 16 位 RISC 指令集 · 16-bit RISC ISA

`class_cpu` · 五级流水 IF · ID · EX · MEM · WB。

编码定义在 [`src/define_ISA.v`](../src/define_ISA.v)。**本文是规范**；代码和规范不一致时，
在同一个 commit 里改掉其中一个。

*Encoding lives in [`src/define_ISA.v`](../src/define_ISA.v). This file is the spec;
if code and spec disagree, fix one of them in the same commit.*

## 公理 —— 全零即什么都不发生 · Axiom: all zeros means nothing happens

| 置零的东西 Zeroed | 含义 Means |
|---|---|
| 操作码 `0000` | 什么都不做，无论其余 12 位是什么 |
| `aluop == 6'b000000` | NOP，结果被丢弃 |
| `reg_we` `mem_we` `mem_re` | 全部高有效，所以 0 是惰性的 |
| 复位或冲刷后的任何流水寄存器 | 正是它该有的气泡 |

冲刷（flush）往 IF/ID 写零，暂停（stall）往 ID/EX 写零。有了这条规则，两者都是**构造上正确**
的，不需要额外逻辑。它还意味着一片没烧过程序的 block RAM —— 上电全零 —— 执行的是 NOP 而不是
乱码。

*Flush writes zeros into IF/ID; stall writes zeros into ID/EX. With this rule both are
correct by construction. It also means an unprogrammed block RAM — which powers up as
zeros — executes NOPs instead of garbage.*

**气泡不是一条指令。** 暂停是 `stall[5:0]` 加上被清零的控制位，全部发生在流水线内部；不会
去取一条 NOP，也不会往里注入什么。`NOP` **指令**存在是为了另一个理由：让程序员能写出它，以
及让全零的那个字是惰性的。

*A bubble is not an instruction. Stalling is `stall[5:0]` plus zeroed control bits,
entirely inside the pipeline; nothing is fetched or injected to make one.*

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

`Rs1` 永远在 `[9:8]`，`Rs2` 永远在 `[7:6]`。ID 直接拿指令字去驱动寄存器堆的读端口，所以**读
寄存器和译码是并行开始的**。操作码只决定读回来的值用不用 —— 先读，后决定。

*`Rs1` is always `[9:8]` and `Rs2` always `[7:6]`. ID drives the register-file read ports
straight from the instruction word, so the read starts in parallel with decode. The
opcode only decides whether the returned value is used — read always, decide later.*

由此带来两个后果，都无害：S 格式没有 `Rd`，但 `inst[11:10]` 照读不误（`reg_we = 0`）；I 格式
没有 `Rs2`，但读口 2 照样读 `inst[7:6]`（`re2 = 0`）。

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
| `1110` | I | `JALR Rd, imm8(Rs1)` | `Rd ← PC+1 ; PC ← (R[Rs1] + sext8(imm))[7:0]` |

操作码 `1111` 保留。

* `ST` 的第一个寄存器是**源**操作数 —— 要存进去的数据。这条指令不写回任何寄存器。
* 地址截断到 8 位。`LI R0,#0; ST R1,-1(R0)` 写的是地址 `0xFF`。
* 分支和 `JAL` 都是**相对于该指令自身**，不是相对于 `PC+1`。范围 ±128 字。
* `JAL` 的射程和分支一样；它多出来的是链接值，不是距离。8 位立即数配 16 位 PC，**没有任何
  单条指令能编码一个远目标**。
* 因此 `JALR` 是唯一能到达任意地址的指令 —— 它的目标来自寄存器，用 `LI` 或 `LUI`+`ORI` 先
  把地址凑出来。它同时也是返回指令和跳转表指令。
* 没有 `HALT`。`JAL Rx, #0` —— 跳转到自身 —— 是停机惯用法；专门做一条停机指令只能省电，而
  这条流水线没有任何需要停下来的状态。

> **注意：** `JAL Rx, #0` 每转一圈都会往 `Rx` 里写一次 `PC+1`。停机用的寄存器要挑一个后面
> 不再读的。

### `aluop` 与 `alusel` · ALU op and ALU sel

每条指令都带一个 `aluop`（ALU 做什么）和一个 `alusel`（哪个功能单元的结果写回）。ID 用一个
`case (opcode)` 同时定下这两个；EX 先按 `alusel` 分流，再由该单元按 `aluop` 选操作。两个枚举
都在 [`src/define_ISA.v`](../src/define_ISA.v) 里，紧挨着 funct 码。

*Every instruction carries an `aluop` (what the ALU does) and an `alusel` (which
functional unit's result writes back). ID sets both from one `case (opcode)`; EX switches
on `alusel`, then the unit switches on `aluop`.*

**`aluop` 低半区 —— 就是 R 型的 `funct` 字段。** 对 `ALU` 操作码来说，这个 `funct` **本身就
是** ALU 的控制字，所以 R 型通路不需要任何控制 ROM。带立即数的那些指令合成出同样的码。

| `funct` | | `funct` | | `funct` | |
|---|---|---|---|---|---|
| `000000` | *nop* | `000100` | `OR` | `001000` | `SLTU` |
| `000001` | `ADD` | `000101` | `XOR` | `001001` | `SLL` |
| `000010` | `SUB` | `000110` | `NOR` | `001010` | `SRL` |
| `000011` | `AND` | `000111` | `SLT` | `001011` | `SRA` |

`001100`–`001111` 保留给将来的 funct。移位量取 `b[3:0]`。

**`aluop` 高半区 —— 内部使用。** 非 R 型的操作码各自带一个 `aluop`，在 ID 里从操作码译出。
它们落在 `funct` 的保留区里，所以永远不可能和一个真实的 `funct` 撞上。

| `aluop` | | `aluop` | |
|---|---|---|---|
| `010000` | `LD` | `010100` | `BLT` |
| `010001` | `ST` | `010101` | `BGE` |
| `010010` | `BEQ` | `010110` | `JAL` |
| `010011` | `BNE` | `010111` | `JALR` |

`011000`–`111111` 保留。

**`alusel`。** `SEL_NOP` 把结果按在零上，所以一个被清零的 ID/EX 寄存器自然就丢弃了结果 ——
还是那条全零公理。

| `alusel` | | 覆盖 Covers |
|---|---|---|
| `000` | `NOP` | `NOP` |
| `001` | `LOGIC` | `AND` `ANDI` `OR` `ORI` `XOR` `NOR` |
| `010` | `SHIFT` | `SLL` `SRL` `SRA` |
| `011` | `ARITH` | `ADD` `ADDI` `SUB` `SLT` `SLTU` `LI` `LUI` |
| `100` | `JUMP_BRANCH` | `BEQ` `BNE` `BLT` `BGE` `JAL` `JALR` |
| `101` | `LOAD_STORE` | `LD` `ST` |

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

这就是为什么展宽方式是**按操作码逐条选**的，在 ID 写 `imm1` / `imm2` 的那一点上决定，而不是
整条数据通路统一定一次。一个 16 位常数用 `LUI Rd,#hi` 加 `ORI Rd,Rd,#lo` 构造，而这个 `ORI`
之所以能成立，正是因为它的立即数是零扩展的。

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

然后是一个 `case (opcode)`。**这里没有操作数选择码，也没有立即数形式选择码**：ID 直接把
**展宽好的 16 位值本身**放在 `imm1`、`imm2`、`mem_offset` 上，而 `re1`/`re2` 兼任操作数
mux —— 读寄存器就由前递链供值，不读就让立即数落下来。这样 EX 里就不需要立即数生成器和它的
选择线了。下表中的破折号表示"该端口读的是寄存器，所以立即数用不上"。

*ID emits the widened 16-bit value itself on `imm1`, `imm2` and `mem_offset`, and
`re1`/`re2` double as the operand mux. That removes an immediate generator and its select
lines from EX.*

| | `re1` | `re2` | `we` | `aluop` | `alusel` | `imm1` → `opv1` | `imm2` → `opv2` | `mem_offset` | `br` |
|---|---|---|---|---|---|---|---|---|---|
| `SYS` | 0 | 0 | 0 | `NOP` | `NOP` | 0 | 0 | 0 | 0 |
| `ALU` | 1 | 1 | 1 | `funct` | 由 `funct` 定 | — | — | 0 | 0 |
| `ADDI` | 1 | 0 | 1 | `ADD` | `ARITH` | — | `sext8(imm_i)` | 0 | 0 |
| `ANDI` | 1 | 0 | 1 | `AND` | `LOGIC` | — | `zext8(imm_i)` | 0 | 0 |
| `ORI` | 1 | 0 | 1 | `OR` | `LOGIC` | — | `zext8(imm_i)` | 0 | 0 |
| `LI` | 0 | 0 | 1 | `ADD` | `ARITH` | `sext8(imm_i)` | 0 | 0 | 0 |
| `LUI` | 0 | 0 | 1 | `ADD` | `ARITH` | `{imm_i, 8'h00}` | 0 | 0 | 0 |
| `LD` | 1 | 0 | 1 | `LD` | `LOAD_STORE` | — | 0 | `sext8(imm_i)` | 0 |
| `ST` | 1 | **1** | 0 | `ST` | `LOAD_STORE` | — | — | `sext8(imm_s)` | 0 |
| 分支 | 1 | 1 | 0 | `BEQ`…`BGE` | `JUMP_BRANCH` | — | — | 0 | 命中则 1 |
| `JAL` | 0 | 0 | 1 | `JAL` | `JUMP_BRANCH` | 0 | 0 | 0 | 1 |
| `JALR` | **1** | 0 | 1 | `JALR` | `JUMP_BRANCH` | — | 0 | 0 | 1 |

`LD`/`ST` 走 EX 里的地址加法器，算 `opv1 + mem_offset` 再截断到 8 位 —— 这是第三条操作数
总线，和 `opv2` 分开，这样 `SEL_LOAD_STORE` 不必去挤 ALU 的操作数通路。`JAL`/`JALR` 压根不
用加法器：ID 手里已经有 PC，就在那里形成 `PC + 1`，作为 `link_addr` 往下带。分支解析留在 ID
（比较器 + 目标加法器）；分支的 `aluop`/`alusel` 一路带着但用不上，除非将来把解析挪到 EX。

**没有 `mem_re`/`mem_we` 控制位，也没有 `branch` 码。** MEM 从 `aluop == LD`/`ST` 推出访存
选通，`br` 是解析出来的结果而不是译码属性 —— 于是没有任何字段身兼两职，也就没有东西需要保持
同步。

*There is no `mem_re`/`mem_we` control bit and no `branch` code — so no field means two
things and nothing has to stay in sync.*

1. `we` 是寄存器堆唯一在意的位，所以一个无意义的 `Rd` 是无害的。
2. `re1`/`re2` 驱动的是**前递**和操作数 mux。一个源寄存器只有在被读的时候才构成冒险 ——
   `ADDI` 把 `re2` 置 0，所以 `inst[7:6]` 永远不会触发检查。
3. `LD` 是唯一写回来源是内存的指令。load-use 检测器提前一级看的就是这一位。
4. `link_addr` 在流水线上是一个独立字段，EX 在 `SEL_JUMP_BRANCH` 下把它送到 `reg_wdata`。
   写回 mux 保持两路。

`JALR` 把 `re1` 置 1，是因为它的**目标**需要 `R[Rs1]`。这个值送进 ID 的分支目标加法器，像
任何一次 ID 读一样接受前递；一条 `LD` 后面紧跟 `JALR` 就是一次 load-use 暂停。

分支目标，一个 16 位加法器加输入端的 mux：

| | `a` | `b` |
|---|---|---|
| 分支 branches | `PC` | `sext8(imm_s)` |
| `JAL` | `PC` | `sext8(imm_i)` |
| `JALR` | `R[Rs1]` 前递后的值，即 `opv1` | `sext8(imm_i)` |

`JAL` 和分支两个输入都一样，区别只在于立即数是怎么拆的；`JALR` 是唯一换掉 `a` 的那个。

## 冒险 · Hazards

对每个源寄存器，从最新的产生者往回找：

```verilog
if      (re && ex_is_load && ex_waddr == addr)  stallreq = 1;   // load-use
else if (re && ex_we      && ex_waddr == addr)  opv = ex_reg_wdata;
else if (re && mem_we     && mem_waddr == addr) opv = mem_reg_wdata;
else if (re)                                    opv = reg_data;
else                                            opv = imm;
```

`re` 把整条链都门控住了，所以 `LI`、`LUI`、`JAL` 永远不会暂停。load-use 是前递唯一救不了的
情况：一个气泡。分支在 ID 解析，命中时杀掉一条指令；不命中则零代价。

*`re` gates the whole chain. Load-use is the one case forwarding cannot cover: one
bubble. A taken branch, resolved in ID, kills one instruction; not-taken costs nothing.*

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
5. **ID 是最长的一级。** 寄存器读、前递 mux、比较器、分支加法器全挤在这里，而且前递值是从
   ALU 组合出来的：`ID/EX → ALU → mux → ID/EX`。如果 100 MHz 跑不过，就把分支解析挪到 EX，
   代价是每次跳转多杀一条指令。

## 验证 · Verification

测试放在 [`testbench/`](../testbench/)，写法见该目录下的 README。

一个测试的形状是：把十六进制程序 `$readmemh` 进 `dut.u_cache.imem`，跑若干周期，然后检查
寄存器和数据字。



## 参考文献 · References

[1] Z. Fan, "RISC-V-CPU: a five-stage pipelined RISC-V CPU in Verilog HDL," *GitHub*,
2018. [Online]. Available: https://github.com/Evensgn/RISC-V-CPU

[2] A. Waterman and K. Asanović, Eds., *The RISC-V Instruction Set Manual, Volume I:
Unprivileged ISA*, document version 20191213, RISC-V Foundation, Dec. 2019.
