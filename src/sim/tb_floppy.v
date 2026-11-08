`timescale 1ns / 1ps
`default_nettype wire

/*
 tb_floppy.v - the floppy path of the board tops for verilator: fdc1772 (rtl/sv2v, as atarist.v
 wires it: Atari ST image type, 8 MHz enable) + img_sdc (karabas-go-modules) as in
 karabas_minig_top.v. The harness (tb_floppy.cpp) is the cpu on the fdc registers and the mcu
 firmware on the IMG_* ports of img_sdc.
*/

module tb_floppy (
	input wire clk,
	input wire reset,

	// the cpu side of fdc1772
	input wire [1:0] drive_n,     // floppy select, active low (atarist: port A of the YM)
	input wire side_n,            // 1 side 0, 0 side 1 (atarist: port A bit 0)
	input wire [1:0] cpu_addr,
	input wire cpu_sel,
	input wire cpu_rw,
	input wire [7:0] cpu_din,
	output wire [7:0] cpu_dout,
	output wire irq,
	output wire drq,

	// the mcu (kg_mcu IMG_* ports)
	input wire [7:0] img_mounted,
	input wire [63:0] img_size,
	input wire [7:0] img_wp,
	input wire img_data_wr,
	input wire [8:0] img_data_addr,
	input wire [7:0] img_data,
	input wire img_result_wr,
	input wire [7:0] img_result,
	input wire [15:0] img_sum,
	output wire img_q_wr,
	output wire [23:0] img_q_di,
	input wire img_q_ack,

	output wire sdc_busy,
	output wire [1:0] fdc_rd,
	output wire [1:0] fdc_wr
);

reg [1:0] div = 2'd0;
always @(posedge clk) div <= div + 2'd1;
wire clk8m_en = (div == 2'd0);

wire [7:0] sdc_img_mounted;
wire [63:0] sdc_img_size;
wire [31:0] fdc_lba;
wire sdc_done, sdc_error, sdc_byte_in_strobe;
wire [2:0] sdc_slot;
wire [8:0] sdc_byte_addr;
wire [7:0] sdc_byte_in_data, fdc_out_data;

img_sdc #(.OUT_LATENCY(2), .TIMEOUT(24'd2000000)) img_sdc (
	.clk(clk), .reset(reset),
	.img_mounted(img_mounted), .img_size(img_size),
	.img_data_wr(img_data_wr), .img_data_addr(img_data_addr), .img_data(img_data),
	.img_result_wr(img_result_wr), .img_result(img_result), .img_sum(img_sum),
	.img_q_wr(img_q_wr), .img_q_di(img_q_di), .img_q_ack(img_q_ack),
	.sdc_img_mounted(sdc_img_mounted), .sdc_img_size(sdc_img_size),
	.sdc_rd({ 6'd0, fdc_rd }), .sdc_wr({ 6'd0, fdc_wr }), .sdc_sector(fdc_lba),
	.sdc_busy(sdc_busy), .sdc_done(sdc_done), .sdc_error(sdc_error), .sdc_slot(sdc_slot),
	.sdc_byte_in_strobe(sdc_byte_in_strobe), .sdc_byte_addr(sdc_byte_addr),
	.sdc_byte_in_data(sdc_byte_in_data), .sdc_byte_out_data(fdc_out_data),
	.active()
);

fdc1772 fdc1772 (
	.clkcpu(clk), .clk8m_en(clk8m_en),
	.floppy_drive(drive_n), .floppy_side(side_n), .floppy_reset(!reset),
	.floppy_step(), .floppy_motor(1'b0), .floppy_ready(),
	.irq(irq), .drq(drq),
	.cpu_addr(cpu_addr), .cpu_sel(cpu_sel), .cpu_rw(cpu_rw), .cpu_din(cpu_din), .cpu_dout(cpu_dout),
	.img_ds(1'b0), .img_type(3'd1), .img_wp(img_wp[1:0]),
	.img_mounted(sdc_img_mounted[1:0]), .img_size(sdc_img_size[31:0]),
	.sd_lba(fdc_lba), .sd_rd(fdc_rd), .sd_wr(fdc_wr), .sd_ack(sdc_busy),
	.sd_buff_addr(sdc_byte_addr), .sd_dout(sdc_byte_in_data), .sd_din(fdc_out_data),
	.sd_dout_strobe(sdc_byte_in_strobe)
);

endmodule
