// 基准没覆盖到的 ALU 类指令：LUI ORI ANDI SLT SLTU NOR SRA SRL。
// 期望值照 doc/ISA.md 手算，写在每行注释里。
        LUI  R0, #0x12        ; R0 = 1200
        ORI  R0, R0, #0x80    ; R0 = 1280   零扩展，不是 FF80
        ANDI R1, R0, #0xF0    ; R1 = 0080   零扩展，不是 FFF0 掩码
        LI   R2, #-1          ; R2 = FFFF
        SLT  R3, R2, R1       ; -1 < 128          -> R3 = 0001
        SLTU R2, R2, R1       ; 65535 < 128 ?     -> R2 = 0000
        NOR  R2, R2, R2       ; ~0                -> R2 = FFFF
        SRA  R2, R2, R3       ; FFFF >>> 1        -> R2 = FFFF
        SRL  R2, R2, R3       ; FFFF >>  1        -> R2 = 7FFF
        ADD  R3, R3, R2       ; 0001 + 7FFF       -> R3 = 8000
        ST   R0, 0(R1)        ; M[80] = 1280
        ST   R2, 1(R1)        ; M[81] = 7FFF
        ST   R3, 2(R1)        ; M[82] = 8000
        HALT R0
