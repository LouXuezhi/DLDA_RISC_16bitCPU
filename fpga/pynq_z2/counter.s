// counter -- 4-bit counter on LED0-3.  SW0 = 0 counts up, 1 counts down.
//   R0 = 0 base   R1 = count   R2 = switches   R3 = discarded link
        LI   R0, #0
        LI   R1, #0
loop:   LD   R2, -2(R0)      ; R2 = sw          (M[0xFE])
        ANDI R2, R2, #1
        BEQ  R2, R0, up
        ADDI R1, R1, #-1
        J    R3, show
up:     ADDI R1, R1, #1
show:   ST   R1, -1(R0)      ; led = R1         (M[0xFF])
        J    R3, loop
