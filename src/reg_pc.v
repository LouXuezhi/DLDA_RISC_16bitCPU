`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module reg_pc (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [   `STALLBUS_LEN] stall,
    input  wire                    br,
    input  wire [`INSTADDRBUS_LEN] br_addr,
    output reg  [`INSTADDRBUS_LEN] pc_o,
    output reg                     br_ready_o
);

    reg [`INSTADDRBUS_LEN] pc_next;
    reg                    br_ready_next;

    always @(posedge clk) begin
        if (rst) begin
            pc_o       <= 0;
            br_ready_o <= 0;
        end else begin
            pc_o       <= pc_next;
            br_ready_o <= br_ready_next;
        end
    end

    // update pc_next and br_ready_next
    always @(*) begin
        pc_next       = pc_o;
        br_ready_next = br_ready_o;
        if (br) begin
            pc_next       = br_addr;
            br_ready_next = 1;
        end else if (!stall[`STALL_PC]) begin
            pc_next       = pc_o + 1;
            br_ready_next = 0;
        end
    end

    // br      -> jump to br_addr
    // stall   -> do nothing
    // no br   -> pc = pc + 1
    // stall[`STALL_PC] and br -> still jump
    //
    // | br | stall[`STALL_PC] | PC                 |
    // |---:|-----------------:|--------------------|
    // |  0 |                0 | PC + 1             |
    // |  0 |                1 | hold PC            |
    // |  1 |                0 | PC = br_addr       |
    // |  1 |                1 | PC = br_addr       |
endmodule
