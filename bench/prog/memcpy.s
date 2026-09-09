// memcpy -- M[0..31] 复制到 M[64..95]。每次迭代一次 LD 一次 ST，
// 是套件里访存最密的核：LATENCY 一涨，这里涨得最狠。
//   R0 = i   R1 = 载入值   R3 = 上界
        LI   R0, #0
        LI   R3, #32
loop:   LD   R1, 0(R0)
        ST   R1, 64(R0)      ; load-use：地址和数据都要等 LD
        ADDI R0, R0, #1
        BLT  R0, R3, loop
        HALT R2
