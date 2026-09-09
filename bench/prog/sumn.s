// sumn -- 累加 M[0..31]。就是 doc/ISA.md 的例子放大到 32 个字。
// 每次迭代的 LD 紧接着被用，所以每一圈都吃一个 load-use 气泡；
// 数据存储的延迟也全落在关键路径上。
//   R0 = i   R1 = sum   R2 = 载入值   R3 = 上界
        LI   R0, #0
        LI   R1, #0
        LI   R3, #32
loop:   LD   R2, 0(R0)
        ADD  R1, R1, R2      ; load-use：前递救不了，一个气泡
        ADDI R0, R0, #1
        BLT  R0, R3, loop
        LI   R0, #0
        ST   R1, -1(R0)      ; M[0xFF] = sum -> LED
        HALT R2
