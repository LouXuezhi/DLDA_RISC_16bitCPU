`timescale 1ns / 1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  pynq_top -- the single-cycle core on a PYNQ-Z2.
//
//  Same wiring as src/cpu_core.v, plus the data-side memory map from
//  define_ctrl.v, which the core leaves to the board:
//      M[0xFF] write -> led[3:0]       (ST Rx, -1(R0))
//      M[0xFE] read  -> {14'b0, sw}    (LD Rx, -2(R0))
//
//  sysclk 125 MHz is divided by 2^22 to ~30 Hz so the program can be
//  watched on the LEDs.  BTN0 resets.  LD4 green blinks with the CPU
//  clock; LD5 red is on while in reset.
//=========================================================================

module pynq_top #(
    parameter INST_INIT = "prog.hex",
    parameter DIV_BIT   = 21
) (
    input  wire       sysclk,
    input  wire [1:0] sw,
    input  wire [3:0] btn,
    output reg [3:0] led,
    output wire       led4_g,
    output wire       led5_r
);

    //---- slow CPU clock --------------------------------------------------
    reg [DIV_BIT:0] div = 0;
    always @(posedge sysclk) div <= div + 1'b1;

    wire clk;
    BUFG u_bufg (.I(div[DIV_BIT]), .O(clk));

    //---- reset: power-on, then BTN0, synchronised to clk -----------------
    reg [3:0] por = 4'hF;
    reg [1:0] btn_sync = 2'b00;
    always @(posedge clk) begin
        btn_sync <= {btn_sync[0], btn[0]};
        if (por != 0) por <= por - 1'b1;
    end
    wire rst = (por != 0) | btn_sync[1];

    assign led4_g = clk;
    assign led5_r = rst;

    //---- core wiring (as cpu_core.v) -------------------------------------
    wire [`INSTADDRBUS_LEN] pc, pc_plus1, pc_rel, next_pc;
    wire [    `INSTBUS_LEN] inst;
    wire                  reg_we, mem_we, src_a, src_b;
    wire [`IMMSELBUS_LEN] imm_sel;
    wire [ `ALUOPBUS_LEN] alu_op;
    wire [ `WBSELBUS_LEN] wb_sel;
    wire [ `PCSELBUS_LEN] pc_sel;
    wire [   `REGBUS_LEN] rdata1, rdata2, imm, alu_a, alu_b, alu_result;
    wire [   `REGBUS_LEN] dmem_rdata, mem_rdata, wb_data;
    wire [  `FLAGBUS_LEN] alu_flags;
    wire                  eq, lt;

    pc_reg u_pc_reg (.clk(clk), .rst(rst), .next_pc(next_pc), .pc(pc));
    adder u_add_pc1 (.a(pc), .b(`PC_STEP), .y(pc_plus1));
    adder u_add_rel (.a(pc), .b(imm), .y(pc_rel));
    mux3 u_mux_pc (.sel(pc_sel), .d0(pc_plus1), .d1(pc_rel), .d2(alu_result), .y(next_pc));

    imem #(.INIT(INST_INIT)) u_imem (.addr(pc), .inst(inst));

    control_unit u_control_unit (
        .rst(rst), .inst(inst), .eq(eq), .lt(lt),
        .reg_we(reg_we), .mem_we(mem_we), .src_a(src_a), .src_b(src_b),
        .imm_sel(imm_sel), .alu_op(alu_op), .wb_sel(wb_sel), .pc_sel(pc_sel)
    );

    regfile u_regfile (
        .clk(clk), .we(reg_we), .waddr(inst[`F_RD]), .wdata(wb_data),
        .raddr1(inst[`F_RS1]), .rdata1(rdata1),
        .raddr2(inst[`F_RS2]), .rdata2(rdata2)
    );

    imm_ext u_imm_ext (.inst(inst), .imm_sel(imm_sel), .imm(imm));
    branch_cmp u_branch_cmp (.a(rdata1), .b(rdata2), .eq(eq), .lt(lt));

    mux2 u_mux_a (.sel(src_a), .d0(rdata1), .d1(`ZEROWORD), .y(alu_a));
    mux2 u_mux_b (.sel(src_b), .d0(rdata2), .d1(imm), .y(alu_b));

    alu u_alu (
        .alu_op(alu_op), .a(alu_a), .b(alu_b), .result(alu_result),
        .zero(alu_flags[`FLAG_Z]), .negative(alu_flags[`FLAG_N]),
        .carry(alu_flags[`FLAG_C]), .overflow(alu_flags[`FLAG_V])
    );

    //---- memory map ------------------------------------------------------
    wire [`DATAADDRBUS_LEN] daddr = alu_result[`DATAADDRBUS_LEN];

    dmem u_dmem (
        .clk(clk), .we(mem_we), .addr(daddr), .wdata(rdata2), .rdata(dmem_rdata)
    );

    always @(posedge clk) begin
        if (rst) led <= 4'h0;
        else if (mem_we && daddr == `MMIO_LED) led <= rdata2[3:0];
    end

    assign mem_rdata = (daddr == `MMIO_SW) ? {14'b0, sw} : dmem_rdata;

    mux3 u_mux_wb (.sel(wb_sel), .d0(alu_result), .d1(mem_rdata), .d2(pc_plus1), .y(wb_data));

endmodule
