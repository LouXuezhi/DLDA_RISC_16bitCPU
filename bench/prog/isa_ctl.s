// JALR 返回、分支不跳/跳、以及三种必须什么都不做的编码：
// funct = 0 的 R 型、保留 funct、保留操作码 1111。
        LI   R0, #0
        LI   R1, #7
        JAL  R3, sub          ; R3 = 3（本条地址 2，链接 PC+1）
        ST   R2, 18(R0)       ; M[12] = JALR 写的链接值 000F
        .WORD 0x1D40          ; ALU R3,R1,R1 funct=000000 -> 不写 R3
        .WORD 0xF3FF          ; 操作码 1111 -> 什么都不做
        .WORD 0x1D4C          ; ALU R3,R1,R1 funct=001100 -> 不写 R3
        LI   R2, #-2          ; R2 = FFFE
        BGE  R2, R1, bad      ; -2 >= 16 不成立，不跳
        BLT  R2, R1, fwd      ; -2 <  16，跳
        LI   R3, #0x55        ; 被跳过
fwd:    ST   R3, 17(R0)       ; M[11] = 0003，R3 没被上面三个字改掉
        HALT R2
sub:    ADDI R1, R1, #9       ; R1 = 0010
        JALR R2, 0(R3)        ; 回到地址 3，R2 = 000F（本条地址 14）
bad:    LI   R3, #-1
        HALT R2
