// JAL in ID while an ST holds MEM.  The JAL must stay in ID until the
// stall clears and then reach EX, or its link write is lost.
        LI   R0, #0
        LI   R3, #0
        ST   R3, 9(R0)        ; MEM stall
        NOP
        JAL  R2, sub          ; R2 = 5
        HALT R1
sub:    HALT R1
