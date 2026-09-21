// A branch whose operand comes from the LD right before it: ID stalls a
// cycle with op1 forced to 0.  The branch must wait, not act on that 0.
        LI   R0, #0
        LI   R2, #0
        LI   R3, #1
        LD   R1, 0(R0)        ; R1 = M[0] = 5
        BEQ  R1, R2, bad      ; 5 != 0 -> not taken
        HALT R2
bad:    LI   R3, #7
        HALT R2
