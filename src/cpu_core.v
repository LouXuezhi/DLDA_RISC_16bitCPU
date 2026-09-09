`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  cpu_core -- the whole pipeline, plus the cache that feeds it.
//
//  IF -> IF/ID -> ID -> ID/EX -> EX -> EX/MEM -> MEM -> MEM/WB -> regfile
//
//  Branches resolve in ID: id_stage raises id_br, pc_reg takes id_br_addr
//  and answers pc_br_ready one cycle later, if_id_reg flushes on id_br.  ctrl
//  collects the four stall requests into one stall vector; every pipeline
//  register reads its own two bits out of it.
//=========================================================================

module cpu_core #(
    parameter INST_INIT = "",
    parameter DATA_INIT = "",
    parameter LATENCY   = 1
) (
    input wire clk,
    input wire rst
);

    //---- ctrl_stall vector ---------------------------------------------------
    wire [`STALLBUS_LEN] ctrl_stall;
    wire                 if_stallreq;
    wire                 id_stallreq;
    wire                 ex_stallreq;
    wire                 mem_stallreq;

    //---- PC / branch ----------------------------------------------------
    wire [`INSTADDRBUS_LEN] pc;
    wire                    pc_br_ready;
    wire                    id_br;
    wire [`INSTADDRBUS_LEN] id_br_addr;

    //---- IF -> IF/ID ----------------------------------------------------
    wire [`INSTADDRBUS_LEN] if_pc;
    wire [    `INSTBUS_LEN] if_inst;
    wire [`INSTADDRBUS_LEN] id_pc;
    wire [    `INSTBUS_LEN] id_inst;

    //---- ID -> ID/EX ----------------------------------------------------
    wire                     id_rs1_re;
    wire                     id_rs2_re;
    wire [`REGADDRBUS_LEN] id_rs1_raddr;
    wire [`REGADDRBUS_LEN] id_rs2_raddr;
    wire [  `ALUOPBUS_LEN] id_alu_op;
    wire [ `ALUSELBUS_LEN] id_alu_sel;
    wire [    `REGBUS_LEN] id_op1;
    wire [    `REGBUS_LEN] id_op2;
    wire [`REGADDRBUS_LEN] id_reg_waddr;
    wire                     id_reg_we;
    wire [`INSTADDRBUS_LEN] id_link_addr;
    wire [    `REGBUS_LEN] id_ls_offset;

    //---- ID/EX -> EX ----------------------------------------------------
    wire [  `ALUOPBUS_LEN] ex_alu_op_i;
    wire [ `ALUSELBUS_LEN] ex_alu_sel;
    wire [    `REGBUS_LEN] ex_op1;
    wire [    `REGBUS_LEN] ex_op2;
    wire [`REGADDRBUS_LEN] ex_reg_waddr_i;
    wire                     ex_reg_we_i;
    wire [`INSTADDRBUS_LEN] ex_link_addr;
    wire [    `REGBUS_LEN] ex_ls_offset;

    //---- EX -> EX/MEM ---------------------------------------------------
    wire [`REGADDRBUS_LEN] ex_reg_waddr_o;
    wire                     ex_reg_we_o;
    wire [    `REGBUS_LEN] ex_reg_wdata;
    wire [`DATAADDRBUS_LEN] ex_ls_addr;
    wire [  `ALUOPBUS_LEN] ex_alu_op_o;
    wire [    `REGBUS_LEN] ex_st_data;

    //---- EX/MEM -> MEM --------------------------------------------------
    wire [`REGADDRBUS_LEN] mem_reg_waddr_i;
    wire                     mem_reg_we_i;
    wire [    `REGBUS_LEN] mem_reg_wdata_i;
    wire [`DATAADDRBUS_LEN] mem_ls_addr;
    wire [  `ALUOPBUS_LEN] mem_alu_op;
    wire [    `REGBUS_LEN] mem_st_data;

    //---- MEM -> MEM/WB --------------------------------------------------
    wire [`REGADDRBUS_LEN] mem_reg_waddr_o;
    wire                     mem_reg_we_o;
    wire [    `REGBUS_LEN] mem_reg_wdata_o;

    //---- MEM/WB -> regfile ----------------------------------------------
    wire [`REGADDRBUS_LEN] wb_reg_waddr;
    wire                     wb_reg_we;
    wire [    `REGBUS_LEN] wb_reg_wdata;

    //---- regfile read ports ---------------------------------------------
    wire [`REGBUS_LEN] id_rs1_rdata;
    wire [`REGBUS_LEN] id_rs2_rdata;

    //---- cache ports ----------------------------------------------------
    wire                    imem_re;
    wire [`INSTADDRBUS_LEN] imem_addr;
    wire [    `REGBUS_LEN] imem_rdata;
    wire                    imem_busy;
    wire                    imem_done;

    wire                    dmem_re;
    wire                    dmem_we;
    wire [`DATAADDRBUS_LEN] dmem_addr;
    wire [    `REGBUS_LEN] dmem_wdata;
    wire [    `REGBUS_LEN] dmem_rdata;
    wire                    dmem_busy;
    wire                    dmem_done;

    //=====================================================================
    pc_reg u_pc_reg (
        .clk       (clk),
        .rst       (rst),
        .ctrl_stall(ctrl_stall),
        .id_br     (id_br),
        .id_br_addr(id_br_addr),
        .pc        (pc),
        .br_ready  (pc_br_ready)
    );

    if_stage u_if_stage (
        .rst        (rst),
        .clk        (clk),
        .pc         (pc),
        .imem_rdata (imem_rdata),
        .imem_busy  (imem_busy),
        .imem_done  (imem_done),
        .id_br      (id_br),
        .pc_br_ready(pc_br_ready),
        .imem_re    (imem_re),
        .imem_addr  (imem_addr),
        .if_pc      (if_pc),
        .if_inst    (if_inst),
        .stallreq   (if_stallreq)
    );

    if_id_reg u_if_id_reg (
        .rst       (rst),
        .clk       (clk),
        .if_pc     (if_pc),
        .if_inst   (if_inst),
        .ctrl_stall(ctrl_stall),
        .id_br     (id_br),
        .id_pc     (id_pc),
        .id_inst   (id_inst)
    );

    id_stage u_id_stage (
        .rst              (rst),
        .pc               (id_pc),
        .inst             (id_inst),
        .rs1_rdata        (id_rs1_rdata),
        .rs2_rdata        (id_rs2_rdata),
        // forwarding sources
        .fwd_ex_alu_op    (ex_alu_op_o),
        .fwd_ex_reg_we    (ex_reg_we_o),
        .fwd_ex_reg_waddr (ex_reg_waddr_o),
        .fwd_ex_reg_wdata (ex_reg_wdata),
        .fwd_mem_reg_we   (mem_reg_we_o),
        .fwd_mem_reg_wdata(mem_reg_wdata_o),
        .fwd_mem_reg_waddr(mem_reg_waddr_o),
        .rs1_re           (id_rs1_re),
        .rs2_re           (id_rs2_re),
        .rs1_raddr        (id_rs1_raddr),
        .rs2_raddr        (id_rs2_raddr),
        .alu_op           (id_alu_op),
        .alu_sel          (id_alu_sel),
        .op1              (id_op1),
        .op2              (id_op2),
        .reg_waddr        (id_reg_waddr),
        .reg_we           (id_reg_we),
        .stallreq         (id_stallreq),
        .br               (id_br),
        .br_addr          (id_br_addr),
        .link_addr        (id_link_addr),
        .ls_offset        (id_ls_offset)
    );

    regfile u_regfile (
        .clk   (clk),
        .rst   (rst),
        .we    (wb_reg_we),
        .waddr (wb_reg_waddr),
        .wdata (wb_reg_wdata),
        .re1   (id_rs1_re),
        .raddr1(id_rs1_raddr),
        .rdata1(id_rs1_rdata),
        .re2   (id_rs2_re),
        .raddr2(id_rs2_raddr),
        .rdata2(id_rs2_rdata)
    );

    id_ex_reg u_id_ex_reg (
        .clk         (clk),
        .rst         (rst),
        .id_alu_op   (id_alu_op),
        .id_alu_sel  (id_alu_sel),
        .id_op1      (id_op1),
        .id_op2      (id_op2),
        .id_reg_waddr(id_reg_waddr),
        .id_reg_we   (id_reg_we),
        .ctrl_stall  (ctrl_stall),
        .id_link_addr(id_link_addr),
        .id_ls_offset(id_ls_offset),
        .ex_alu_op   (ex_alu_op_i),
        .ex_alu_sel  (ex_alu_sel),
        .ex_op1      (ex_op1),
        .ex_op2      (ex_op2),
        .ex_reg_waddr(ex_reg_waddr_i),
        .ex_reg_we   (ex_reg_we_i),
        .ex_link_addr(ex_link_addr),
        .ex_ls_offset(ex_ls_offset)
    );

    ex_stage u_ex_stage (
        .rst        (rst),
        .alu_op_i   (ex_alu_op_i),
        .alu_sel    (ex_alu_sel),
        .op1        (ex_op1),
        .op2        (ex_op2),
        .reg_waddr_i(ex_reg_waddr_i),
        .reg_we_i   (ex_reg_we_i),
        .link_addr  (ex_link_addr),
        .ls_offset  (ex_ls_offset),
        .reg_waddr_o(ex_reg_waddr_o),
        .reg_we_o   (ex_reg_we_o),
        .reg_wdata  (ex_reg_wdata),
        .stallreq   (ex_stallreq),
        .ls_addr    (ex_ls_addr),
        .alu_op_o   (ex_alu_op_o),
        .st_data    (ex_st_data)
    );

    ex_mem_reg u_ex_mem_reg (
        .clk          (clk),
        .rst          (rst),
        .ex_reg_waddr (ex_reg_waddr_o),
        .ex_reg_we    (ex_reg_we_o),
        .ex_reg_wdata (ex_reg_wdata),
        .ex_ls_addr   (ex_ls_addr),
        .ex_alu_op    (ex_alu_op_o),
        .ex_st_data   (ex_st_data),
        .ctrl_stall   (ctrl_stall),
        .mem_reg_waddr(mem_reg_waddr_i),
        .mem_reg_we   (mem_reg_we_i),
        .mem_reg_wdata(mem_reg_wdata_i),
        .mem_ls_addr  (mem_ls_addr),
        .mem_alu_op   (mem_alu_op),
        .mem_st_data  (mem_st_data)
    );

    mem_stage u_mem_stage (
        .clk        (clk),
        .rst        (rst),
        .reg_waddr_i(mem_reg_waddr_i),
        .reg_we_i   (mem_reg_we_i),
        .reg_wdata_i(mem_reg_wdata_i),
        .ls_addr    (mem_ls_addr),
        .alu_op     (mem_alu_op),
        .st_data    (mem_st_data),
        .dmem_busy  (dmem_busy),
        .dmem_done  (dmem_done),
        .dmem_rdata (dmem_rdata),
        .reg_waddr_o(mem_reg_waddr_o),
        .reg_we_o   (mem_reg_we_o),
        .reg_wdata_o(mem_reg_wdata_o),
        .dmem_re    (dmem_re),
        .dmem_we    (dmem_we),
        .dmem_wdata (dmem_wdata),
        .dmem_addr  (dmem_addr),
        .stallreq   (mem_stallreq)
    );

    mem_wb_reg u_mem_wb_reg (
        .clk          (clk),
        .rst          (rst),
        .mem_reg_waddr(mem_reg_waddr_o),
        .mem_reg_we   (mem_reg_we_o),
        .mem_reg_wdata(mem_reg_wdata_o),
        .ctrl_stall   (ctrl_stall),
        .wb_reg_waddr (wb_reg_waddr),
        .wb_reg_we    (wb_reg_we),
        .wb_reg_wdata (wb_reg_wdata)
    );

    ctrl u_ctrl (
        .rst         (rst),
        .if_stallreq (if_stallreq),
        .id_stallreq (id_stallreq),
        .ex_stallreq (ex_stallreq),
        .mem_stallreq(mem_stallreq),
        .ctrl_stall  (ctrl_stall)
    );

    cache #(
        .INST_INIT(INST_INIT),
        .DATA_INIT(DATA_INIT),
        .LATENCY  (LATENCY)
    ) u_cache (
        .clk    (clk),
        .rst    (rst),
        .imem_re   (imem_re),
        .imem_addr (imem_addr),
        .imem_rdata(imem_rdata),
        .imem_busy (imem_busy),
        .imem_done (imem_done),
        .dmem_re   (dmem_re),
        .dmem_we   (dmem_we),
        .dmem_addr (dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_busy (dmem_busy),
        .dmem_done (dmem_done)
    );

endmodule
