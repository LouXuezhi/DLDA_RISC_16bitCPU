# 命名规范 · Naming convention

信号名回答三个问题，顺序固定：**在哪一域 → 作用于什么 → 做什么**。

```
<域>_<对象>_<属性>
```

## 域前缀

| 前缀 | 含义 | 谁产生 |
|---|---|---|
| 无 | `clk`、`rst`、`pc` —— 全局或域内唯一 | — |
| `if_` `id_` `ex_` `mem_` `wb_` | 顺流数据通路，前缀 = 该值当前所在的流水级 | 上游流水寄存器 |
| `ctrl_` | 逆流：停顿向量 | `ctrl` |
| `id_br` `id_br_addr` | 逆流：分支重定向 | `id_stage` |
| `pc_br_ready` | 逆流：PC 重定向已完成 | `pc_reg` |
| `fwd_ex_` `fwd_mem_` | 逆流：前递源，前缀 = 数据来自哪一级 | `ex_stage` / `mem_stage` |
| `imem_` `dmem_` | 存储器接口，Harvard 两侧各一 | `cache` |

**世代，不是来源。** 同一个 PC 在同一时刻存在于两个触发器里：`pc_reg` 里的是下一条要取的，`if_id_reg` 里的是正在译码的那条。前缀区分的是这个，不是"谁给我的"。

*The prefix names the generation, not the producer. The same PC lives in two
flip-flops at once; the prefix is what tells them apart.*

## 三类模块，三种端口写法

| 模块类 | 输入端口 | 输出端口 | 例 |
|---|---|---|---|
| 流水寄存器（跨两域） | 上游域前缀 | 下游域前缀 | `id_ex_reg`: `id_op1` → `ex_op1` |
| 组合级（单域） | 不带域前缀 | 不带域前缀 | `ex_stage`: `op1`、`alu_sel` |
| 叶子模块 | 自己的局部词汇 | 同左 | `regfile`: `raddr1`、`rdata1` |

组合级不带域前缀，因为模块本身就是那一域。域前缀属于 **`cpu_core.v` 里的连线**——只有在顶层才需要区分世代。

跨域进入组合级的信号（前递、重定向、握手）例外：它们带产生者前缀，因为在这一级看来它们来自"未来"。

## `_i` / `_o`

只在**一个组合级把同一个值原样透传**时使用，此时域和对象都相同，方向是唯一的区分轴。

```
ex_reg_waddr_i → [ex_stage] → ex_reg_waddr_o
```

不透传就不加。`ex_op1` 没有 `_i`/`_o`，因为 EX 之后它就不存在了。

## 词表

只用这张表里的词。

| 词 | 含义 | | 词 | 含义 |
|---|---|---|---|---|
| `pc` | 程序计数器 | | `re` / `we` | 读 / 写使能 |
| `inst` | 指令字 | | `raddr` / `waddr` | 读 / 写地址 |
| `rs1` `rs2` `rd` | 源 / 目的寄存器号 | | `rdata` / `wdata` | 读 / 写数据 |
| `op1` `op2` | ALU 操作数 | | `busy` / `done` | 存储器握手 |
| `alu_op` | ALU 做什么 | | `stallreq` | 单级的停顿请求 |
| `alu_sel` | 哪个单元的结果写回 | | `ctrl_stall` | 六位停顿向量 |
| `ls_offset` | LD/ST 的立即数偏移 | | `br` / `br_addr` | 分支发生 / 目标 |
| `ls_addr` | LD/ST 算出的数据地址 | | `link_addr` | JAL/JALR 的返回地址 |
| `st_data` | ST 要写的数据 | | `*_next` | 触发器的 D 端 |

`reg_we`/`reg_waddr`/`reg_wdata` 指寄存器堆，`dmem_we`/`dmem_addr`/`dmem_wdata` 指数据存储器。**这两族不共用 `we`**——它们曾经共用，`mem_we` 因此在 `ex_mem_reg` 和 `mem_stage` 里指两个不同的信号。

## 文件与模块

- 文件名 == 模块名（见 `RULE.md`）。
- 流水寄存器叫 `<上游>_<下游>_reg`：`if_id_reg`、`id_ex_reg`、`ex_mem_reg`、`mem_wb_reg`。
- 其余寄存器名词序为 `<对象>_reg`：`pc_reg`。
- 实例名 = `u_` + 模块名。

## 遗留

- `RULE.md` 写复位是 `rst_n`、低有效，`src/` 里全部是高有效 `rst`。二者必须统一，`RULE.md` 只读，需人工裁定。
- 宽度宏 `` `INSTBUS_LEN `` 等的值是位区间（`15:0`）而非长度，名字与内容不符。改名为 `` `*_RANGE ``，或改成宽度宏加显式 `[`INST_W-1:0]`，尚未处理。
