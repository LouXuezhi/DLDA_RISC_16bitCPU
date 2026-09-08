`timescale 1ns/1ps
`include "define_ISA.v"
`include "define_ctrl.v"

//=========================================================================
//  cpu_core -- the whole pipeline, plus the cache that feeds it.
//
//  IF -> IF/ID -> ID -> ID/EX -> EX -> EX/MEM -> MEM -> MEM/WB -> regfile
//
//  Branches resolve in ID: id_stage raises br, reg_pc takes br_addr and
//  answers br_ready one cycle later, if_id_reg flushes on br.  ctrl
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

    //---- stall vector ---------------------------------------------------
    wire [`STALLBUS_LEN] stall;
    wire                 stallreq_if;
    wire                 stallreq_id;
    wire                 stallreq_ex;
    wire                 stallreq_mem;

    //---- PC / branch ----------------------------------------------------
    wire [`INSTADDRBUS_LEN] pc;
    wire                    br_ready;
    wire                    br;
    wire [`INSTADDRBUS_LEN] br_addr;

    //---- IF -> IF/ID ----------------------------------------------------
    wire [`INSTADDRBUS_LEN] if_pc;
    wire [    `INSTBUS_LEN] if_inst;
    wire [`INSTADDRBUS_LEN] id_pc;
    wire [    `INSTBUS_LEN] id_inst;

    //---- ID -> ID/EX ----------------------------------------------------
    wire                     id_re1;
    wire                     id_re2;
    wire [`REGADDRBUS_LEN] id_reg_addr1;
    wire [`REGADDRBUS_LEN] id_reg_addr2;
    wire [  `ALUOPBUS_LEN] id_aluop;
    wire [ `ALUSELBUS_LEN] id_alusel;
    wire [    `REGBUS_LEN] id_opv1;
    wire [    `REGBUS_LEN] id_opv2;
    wire [`REGADDRBUS_LEN] id_reg_waddr;
    wire                     id_we;
    wire [`INSTADDRBUS_LEN] id_link_addr;
    wire [    `REGBUS_LEN] id_mem_offset;

    //---- ID/EX -> EX ----------------------------------------------------
    wire [  `ALUOPBUS_LEN] ex_aluop_i;
    wire [ `ALUSELBUS_LEN] ex_alusel_i;
    wire [    `REGBUS_LEN] ex_opv1;
    wire [    `REGBUS_LEN] ex_opv2;
    wire [`REGADDRBUS_LEN] ex_reg_waddr_i;
    wire                     ex_we_i;
    wire [`INSTADDRBUS_LEN] ex_link_addr;
    wire [    `REGBUS_LEN] ex_mem_offset;

    //---- EX -> EX/MEM ---------------------------------------------------
    wire [`REGADDRBUS_LEN] ex_reg_waddr_o;
    wire                     ex_we_o;
    wire [    `REGBUS_LEN] ex_reg_wdata;
    wire [`DATAADDRBUS_LEN] ex_mem_addr;
    wire [  `ALUOPBUS_LEN] ex_aluop_o;
    wire [    `REGBUS_LEN] ex_rs2_data;

    //---- EX/MEM -> MEM --------------------------------------------------
    wire [`REGADDRBUS_LEN] mem_reg_waddr_i;
    wire                     mem_we_i;
    wire [    `REGBUS_LEN] mem_reg_wdata_i;
    wire [`DATAADDRBUS_LEN] mem_mem_addr;
    wire [  `ALUOPBUS_LEN] mem_aluop;
    wire [    `REGBUS_LEN] mem_rs2_data;

    //---- MEM -> MEM/WB --------------------------------------------------
    wire [`REGADDRBUS_LEN] mem_reg_waddr_o;
    wire                     mem_we_o;
    wire [    `REGBUS_LEN] mem_reg_wdata_o;

    //---- MEM/WB -> regfile ----------------------------------------------
    wire [`REGADDRBUS_LEN] wb_reg_waddr;
    wire                     wb_we;
    wire [    `REGBUS_LEN] wb_reg_wdata;

    //---- regfile read ports ---------------------------------------------
    wire [`REGBUS_LEN] reg_data1;
    wire [`REGBUS_LEN] reg_data2;

    //---- cache ports ----------------------------------------------------
    wire                    i_re;
    wire [`INSTADDRBUS_LEN] i_addr;
    wire [    `REGBUS_LEN] i_rdata;
    wire                    i_busy;
    wire                    i_done;

    wire                    d_re;
    wire                    d_we;
    wire [`DATAADDRBUS_LEN] d_addr;
    wire [    `REGBUS_LEN] d_wdata;
    wire [    `REGBUS_LEN] d_rdata;
    wire                    d_busy;
    wire                    d_done;

    //=====================================================================
    reg_pc u_reg_pc (
        .clk       (clk),
        .rst       (rst),
        .stall     (stall),
        .br        (br),
        .br_addr   (br_addr),
        .pc_o      (pc),
        .br_ready_o(br_ready)
    );

    if_stage u_if_stage (
        .rst       (rst),
        .clk       (clk),
        .pc_i      (pc),
        .mem_data_i(i_rdata),
        .mem_busy  (i_busy),
        .mem_done  (i_done),
        .br        (br),
        .br_ready  (br_ready),
        .mem_re    (i_re),
        .mem_addr_o(i_addr),
        .pc_o      (if_pc),
        .inst_o    (if_inst),
        .stallreq  (stallreq_if)
    );

    if_id_reg u_if_id_reg (
        .rst    (rst),
        .clk    (clk),
        .if_pc  (if_pc),
        .if_inst(if_inst),
        .stall  (stall),
        .br     (br),
        .id_pc  (id_pc),
        .id_inst(id_inst)
    );

    id_stage u_id_stage (
        .rst          (rst),
        .pc           (id_pc),
        .inst         (id_inst),
        .reg_data1    (reg_data1),
        .reg_data2    (reg_data2),
        // forwarding sources
        .ex_aluop     (ex_aluop_o),
        .ex_we        (ex_we_o),
        .ex_reg_waddr (ex_reg_waddr_o),
        .ex_reg_wdata (ex_reg_wdata),
        .mem_we       (mem_we_o),
        .mem_reg_wdata(mem_reg_wdata_o),
        .mem_reg_waddr(mem_reg_waddr_o),
        .re1          (id_re1),
        .re2          (id_re2),
        .reg_addr1    (id_reg_addr1),
        .reg_addr2    (id_reg_addr2),
        .aluop        (id_aluop),
        .alusel       (id_alusel),
        .opv1         (id_opv1),
        .opv2         (id_opv2),
        .reg_waddr    (id_reg_waddr),
        .we           (id_we),
        .stallreq     (stallreq_id),
        .br           (br),
        .br_addr      (br_addr),
        .link_addr    (id_link_addr),
        .mem_offset   (id_mem_offset)
    );

    regfile u_regfile (
        .clk   (clk),
        .rst   (rst),
        .we    (wb_we),
        .waddr (wb_reg_waddr),
        .wdata (wb_reg_wdata),
        .re1   (id_re1),
        .raddr1(id_reg_addr1),
        .rdata1(reg_data1),
        .re2   (id_re2),
        .raddr2(id_reg_addr2),
        .rdata2(reg_data2)
    );

    id_ex_reg u_id_ex_reg (
        .clk          (clk),
        .rst          (rst),
        .id_aluop     (id_aluop),
        .id_alusel    (id_alusel),
        .id_opv1      (id_opv1),
        .id_opv2      (id_opv2),
        .id_reg_waddr (id_reg_waddr),
        .id_we        (id_we),
        .stall        (stall),
        .id_link_addr (id_link_addr),
        .id_mem_offset(id_mem_offset),
        .ex_aluop     (ex_aluop_i),
        .ex_alusel    (ex_alusel_i),
        .ex_opv1      (ex_opv1),
        .ex_opv2      (ex_opv2),
        .ex_reg_waddr (ex_reg_waddr_i),
        .ex_we        (ex_we_i),
        .ex_link_addr (ex_link_addr),
        .ex_mem_offset(ex_mem_offset)
    );

    ex_stage u_ex_stage (
        .rst        (rst),
        .aluop      (ex_aluop_i),
        .alusel     (ex_alusel_i),
        .opv1       (ex_opv1),
        .opv2       (ex_opv2),
        .reg_waddr_i(ex_reg_waddr_i),
        .we_i       (ex_we_i),
        .link_addr  (ex_link_addr),
        .mem_offset (ex_mem_offset),
        .reg_waddr  (ex_reg_waddr_o),
        .we_o       (ex_we_o),
        .reg_wdata  (ex_reg_wdata),
        .stallreq   (stallreq_ex),
        .mem_addr   (ex_mem_addr),
        .ex_aluop   (ex_aluop_o),
        .rs2_data   (ex_rs2_data)
    );

    ex_mem_reg u_ex_mem_reg (
        .clk          (clk),
        .rst          (rst),
        .ex_reg_waddr (ex_reg_waddr_o),
        .ex_we        (ex_we_o),
        .ex_reg_wdata (ex_reg_wdata),
        .ex_mem_addr  (ex_mem_addr),
        .ex_aluop     (ex_aluop_o),
        .ex_rs2_data  (ex_rs2_data),
        .stall        (stall),
        .mem_reg_waddr(mem_reg_waddr_i),
        .mem_we       (mem_we_i),
        .mem_reg_wdata(mem_reg_wdata_i),
        .mem_mem_addr (mem_mem_addr),
        .mem_aluop    (mem_aluop),
        .mem_rs2_data (mem_rs2_data)
    );

    mem_stage u_mem_stage (
        .clk        (clk),
        .rst        (rst),
        .reg_waddr_i(mem_reg_waddr_i),
        .we_i       (mem_we_i),
        .reg_wdata_i(mem_reg_wdata_i),
        .mem_addr_i (mem_mem_addr),
        .aluop_i    (mem_aluop),
        .rs2_data_i (mem_rs2_data),
        .mem_busy   (d_busy),
        .mem_done   (d_done),
        .mem_data_i (d_rdata),
        .reg_waddr_o(mem_reg_waddr_o),
        .we_o       (mem_we_o),
        .reg_wdata_o(mem_reg_wdata_o),
        .mem_re     (d_re),
        .mem_we     (d_we),
        .mem_data_o (d_wdata),
        .mem_addr_o (d_addr),
        .stallreq   (stallreq_mem)
    );

    mem_rw_reg u_mem_rw_reg (
        .clk          (clk),
        .rst          (rst),
        .mem_reg_waddr(mem_reg_waddr_o),
        .mem_we       (mem_we_o),
        .mem_reg_wdata(mem_reg_wdata_o),
        .stall        (stall),
        .wb_reg_waddr (wb_reg_waddr),
        .wb_we        (wb_we),
        .wb_reg_wdata (wb_reg_wdata)
    );

    ctrl u_ctrl (
        .rst         (rst),
        .stallreq_if (stallreq_if),
        .stallreq_id (stallreq_id),
        .stallreq_ex (stallreq_ex),
        .stallreq_mem(stallreq_mem),
        .stall       (stall)
    );

    cache #(
        .INST_INIT(INST_INIT),
        .DATA_INIT(DATA_INIT),
        .LATENCY  (LATENCY)
    ) u_cache (
        .clk    (clk),
        .rst    (rst),
        .i_re   (i_re),
        .i_addr (i_addr),
        .i_rdata(i_rdata),
        .i_busy (i_busy),
        .i_done (i_done),
        .d_re   (d_re),
        .d_we   (d_we),
        .d_addr (d_addr),
        .d_wdata(d_wdata),
        .d_rdata(d_rdata),
        .d_busy (d_busy),
        .d_done (d_done)
    );

endmodule
