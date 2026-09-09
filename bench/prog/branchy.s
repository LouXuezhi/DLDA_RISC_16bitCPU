// branchy -- 数一数 M[0..31] 里小于 32 的元素。数据是一大一小交替排的，
// 所以那个 BGE 每圈都改方向 —— 一位预测器在这上面是 0% 命中，
// 这正是要留给预测器去打的基线。
//   R0 = i   R1 = 计数   R2 = 载入值   R3 = 上界，同时兼作阈值
        LI   R0, #0
        LI   R1, #0
        LI   R3, #32
loop:   LD   R2, 0(R0)
        BGE  R2, R3, skip    ; v >= 32 -> 不计
        ADDI R1, R1, #1
skip:   ADDI R0, R0, #1
        BLT  R0, R3, loop
        LI   R0, #0
        ST   R1, -1(R0)      ; M[0xFF] = count -> LED
        HALT R2
