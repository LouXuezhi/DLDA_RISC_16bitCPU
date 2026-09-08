`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

module ctrl (
    input  wire                 rst,
    input  wire                 stallreq_if,
    input  wire                 stallreq_id,
    input  wire                 stallreq_ex,
    input  wire                 stallreq_mem,
    output reg  [`STALLBUS_LEN] stall
);

    // A request from stage N freezes N and everything upstream of it; the
    // stages downstream keep moving, so the gap they leave behind is the
    // bubble.  Index order is `STALL_PC .. `STALL_WB, see define_ctrl.v.
    always @(*) begin
        if (rst) begin
            stall = `NOSTALL;
        end else if (stallreq_mem) begin
            stall = 6'b011111;
        end else if (stallreq_ex) begin
            stall = 6'b001111;
        end else if (stallreq_id) begin
            stall = 6'b000111;
        end else if (stallreq_if) begin
            stall = 6'b000011;
        end else begin
            stall = `NOSTALL;
        end
    end

endmodule
