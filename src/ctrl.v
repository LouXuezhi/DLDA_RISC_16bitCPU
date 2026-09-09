`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module ctrl (
    input  wire                 rst,
    input  wire                 if_stallreq,
    input  wire                 id_stallreq,
    input  wire                 ex_stallreq,
    input  wire                 mem_stallreq,
    output reg  [`STALLBUS_LEN] ctrl_stall
);

    // A request from stage N freezes N and everything upstream of it; the
    // stages downstream keep moving, so the gap they leave behind is the
    // bubble.  Index order is `STALL_PC .. `STALL_WB, see define_ctrl.v.
    always @(*) begin
        if (rst) begin
            ctrl_stall = `NOSTALL;
        end else if (mem_stallreq) begin
            ctrl_stall = 6'b011111;
        end else if (ex_stallreq) begin
            ctrl_stall = 6'b001111;
        end else if (id_stallreq) begin
            ctrl_stall = 6'b000111;
        end else if (if_stallreq) begin
            ctrl_stall = 6'b000011;
        end else begin
            ctrl_stall = `NOSTALL;
        end
    end

endmodule
