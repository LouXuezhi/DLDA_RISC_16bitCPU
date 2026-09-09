`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module pc_reg (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [   `STALLBUS_LEN] ctrl_stall,
    input  wire                    id_br,
    input  wire [`INSTADDRBUS_LEN] id_br_addr,
    output reg  [`INSTADDRBUS_LEN] pc,
    output reg                     br_ready
);

    reg [`INSTADDRBUS_LEN] pc_next;
    reg                    br_ready_next;

    always @(posedge clk) begin
        if (rst) begin
            pc       <= 0;
            br_ready <= 0;
        end else begin
            pc       <= pc_next;
            br_ready <= br_ready_next;
        end
    end

    // update pc_next and br_ready_next
    always @(*) begin
        pc_next       = pc;
        br_ready_next = br_ready;
        if (id_br) begin
            pc_next       = id_br_addr;
            br_ready_next = 1;
        end else if (!ctrl_stall[`STALL_PC]) begin
            pc_next       = pc + 1;
            br_ready_next = 0;
        end
    end

    // id_br      -> jump to id_br_addr
    // ctrl_stall -> do nothing
    // no id_br   -> pc = pc + 1
    // ctrl_stall[`STALL_PC] and id_br -> still jump
    //
    // | id_br | ctrl_stall[`STALL_PC] | PC             |
    // |------:|----------------------:|----------------|
    // |     0 |                     0 | PC + 1         |
    // |     0 |                     1 | hold PC        |
    // |     1 |                     0 | PC = id_br_addr|
    // |     1 |                     1 | PC = id_br_addr|
endmodule
