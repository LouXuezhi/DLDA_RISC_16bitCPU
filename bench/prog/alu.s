// alu -- 48 条直线 ALU 指令，没有访存也没有分支。
// 每条都依赖前一条的结果，所以整段跑在 EX->ID 前递通路上。
// 这是 CPI 的下界：这里的 CPI 就是纯取指/发射的代价。
//   循环 12 次展开：R1 += 1 ; R2 += R1 ; R3 = (R2 << R1) ^ R2
//   末态 R1 = 12, R2 = 1+..+12 = 78 = 0x004E,
//        R3 = (78 << 12) ^ 78 = 0xE000 ^ 0x004E = 0xE04E
        LI   R1, #0
        LI   R2, #0
        ADDI R1, R1, #1      ; i = 1
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 2
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 3
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 4
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 5
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 6
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 7
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 8
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 9
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 10
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 11
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        ADDI R1, R1, #1      ; i = 12
        ADD  R2, R2, R1
        SLL  R3, R2, R1
        XOR  R3, R3, R2
        HALT R0
