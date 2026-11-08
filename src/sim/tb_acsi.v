`timescale 1ns / 1ps
`default_nettype wire

/*
 tb_acsi.v - the ACSI path of the board tops for verilator: dma + acsi (rtl/sv2v) + img_sdc wired
 as in karabas_minig_top.v (slots 2, 3). The harness (tb_acsi.cpp) is the cpu on the dma registers,
 the ST RAM on the dma bus (rdy_o / rdy_i / ram_din / cpu_dout) and the mcu firmware on IMG_*.
*/

module tb_acsi (
	input wire clk,
	input wire reset,

	input wire [15:0] cpu_din,
	input wire cpu_sel,
	input wire cpu_a1,
	input wire cpu_rw,
	output wire [15:0] cpu_dout,
	output wire irq,

	input wire rdy_i,
	output wire rdy_o,
	input wire [15:0] ram_din,

	input wire [7:0] img_mounted,
	input wire [63:0] img_size,
	input wire img_data_wr,
	input wire [8:0] img_data_addr,
	input wire [7:0] img_data,
	input wire img_result_wr,
	input wire [7:0] img_result,
	input wire [15:0] img_sum,
	output wire img_q_wr,
	output wire [23:0] img_q_di,
	input wire img_q_ack
);

reg [1:0] div = 2'd0;
always @(posedge clk) div <= div + 2'd1;
wire clk_en = (div == 2'd0);

wire [7:0] sdc_img_mounted;
wire [63:0] sdc_img_size;
wire sdc_busy, sdc_done, sdc_strobe;
wire [2:0] sdc_slot;
wire [8:0] sdc_addr;
wire [7:0] sdc_in, acsi_out;
wire [1:0] acsi_rd, acsi_wr;
wire [31:0] acsi_lba;
wire sdc_acsi = (sdc_slot[2:1] == 2'b01);

img_sdc #(.OUT_LATENCY(2), .TIMEOUT(24'd2000000)) img_sdc (
	.clk(clk), .reset(reset),
	.img_mounted(img_mounted), .img_size(img_size),
	.img_data_wr(img_data_wr), .img_data_addr(img_data_addr), .img_data(img_data),
	.img_result_wr(img_result_wr), .img_result(img_result), .img_sum(img_sum),
	.img_q_wr(img_q_wr), .img_q_di(img_q_di), .img_q_ack(img_q_ack),
	.sdc_img_mounted(sdc_img_mounted), .sdc_img_size(sdc_img_size),
	.sdc_rd({ 4'd0, acsi_rd, 2'b00 }), .sdc_wr({ 4'd0, acsi_wr, 2'b00 }), .sdc_sector(acsi_lba),
	.sdc_busy(sdc_busy), .sdc_done(sdc_done), .sdc_error(), .sdc_slot(sdc_slot),
	.sdc_byte_in_strobe(sdc_strobe), .sdc_byte_addr(sdc_addr),
	.sdc_byte_in_data(sdc_in), .sdc_byte_out_data(acsi_out),
	.active()
);

dma dma (
	.clk(clk), .clk_en(clk_en), .reset(reset),
	.cpu_din(cpu_din), .cpu_sel(cpu_sel), .cpu_a1(cpu_a1), .cpu_rw(cpu_rw), .cpu_dout(cpu_dout),
	.img_mounted(sdc_img_mounted[3:2]), .img_size(sdc_img_size),
	.acsi_rd_req(acsi_rd), .acsi_wr_req(acsi_wr), .acsi_lba(acsi_lba),
	.sd_busy(sdc_busy && sdc_acsi), .sd_done(sdc_done && sdc_acsi),
	.sd_rd_byte_strobe(sdc_strobe && sdc_acsi), .sd_rd_byte(sdc_in), .sd_wr_byte(acsi_out),
	.sd_byte_addr(sdc_addr),
	.acsi_irq(irq),
	.fdc_sel(), .fdc_addr(), .fdc_rw(), .fdc_din(), .fdc_dout(8'd0), .fdc_drq(1'b0),
	.rdy_i(rdy_i), .rdy_o(rdy_o), .ram_din(ram_din), .hdd_leds()
);

endmodule
