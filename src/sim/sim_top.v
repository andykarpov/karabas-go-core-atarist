`timescale 1ns / 1ps
`default_nettype wire

/*
 sim_top.v - the Atari ST machine with the memory and video glue of the board tops, for verilator:
 atarist + sdram.v (on a model of the MT48LC16M16A2) + st_sram (on a model of the two SRAM chips)
 + st_hid + video_analyzer / scandoubler / st_video_out. The board top differs in the clocks, the
 mcu link, the OSD and HDMI.

 The harness (sim_top.cpp) writes the TOS through the loader port (ld_we, ld_addr, ld_data: the
 ROM loader of the mcu), holds resb low meanwhile, and feeds the keyboard report.
*/

module sim_top (
	input wire clk,
	input wire porb_ext,      // 0 = power-on reset (also waits for the SDRAM)
	input wire resb,

	input wire ld_we,
	input wire [21:0] ld_addr,
	input wire [7:0] ld_data,
	input wire tos_file,      // 1: TOS at 000000 (an FL file), 0: at 100000 (EmuTOS)
	input wire [1:0] chipset,
	input wire mono_detect,   // 0 = monochrome monitor

	input wire [7:0] kb_status,
	input wire [7:0] kb_dat0,

	// the ST output and the doubled output
	output wire [3:0] st_r,
	output wire [3:0] st_g,
	output wire [3:0] st_b,
	output wire st_hs_n,
	output wire st_vs_n,
	output wire st_de,
	output wire [23:0] vid_rgb,
	output wire vid_hs,
	output wire vid_vs,
	output wire vid_de,
	output wire [1:0] vmode,
	output wire ram_ready,
	output wire [15:0] audio_l16,
	// the byte the IKBD sent last to the keyboard ACIA (hierarchical, for the key test)
	output wire [7:0] kbd_rx,

	// the mcu firmware model of the harness on img_sdc (--disk)
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
	input wire img_q_ack,

	// fdc1772, for the trace of the harness
	output wire [7:0] fdc_cmd,
	output wire [7:0] fdc_track,
	output wire [7:0] fdc_sector,
	output wire fdc_busy,
	output wire fdc_irq,
	output wire fdc_motor,
	output wire [1:0] fdc_drive,
	output wire [1:0] fdc_present,
	output wire [1:0] fdc_rd,
	output wire [1:0] fdc_wr,
	output wire [31:0] fdc_lba
);
assign kbd_rx = st.kbd_acia.serial_rx_data;
assign fdc_cmd = st.fdc1772.cmd;
assign fdc_track = st.fdc1772.track;
assign fdc_sector = st.fdc1772.sector;
assign fdc_busy = st.fdc1772.busy;
assign fdc_irq = st.fdc_irq;
assign fdc_motor = st.fdc1772.motor_on;
assign fdc_drive = st.floppy_sel_exclusive;
assign fdc_present = { st.fdc1772.fdn_present[1], st.fdc1772.fdn_present[0] };

// ------------------------------------------------------------------ SRAM: two 2M x 8 chips

wire [20:0] MA;
wire [15:0] MD;
wire [1:0] MWR_N, MRD_N;
reg [7:0] sram_hi [0:2097151];
reg [7:0] sram_lo [0:2097151];
assign MD[15:8] = (!MRD_N[1] && MWR_N[1]) ? sram_hi[MA] : 8'bz;
assign MD[7:0]  = (!MRD_N[0] && MWR_N[0]) ? sram_lo[MA] : 8'bz;
// a write at the rising edge of /WE (the data are held a clock longer)
reg [1:0] mwr_d = 2'b11;
always @(posedge clk) begin
	mwr_d <= MWR_N;
	if (MWR_N[1] && !mwr_d[1]) sram_hi[MA] <= MD[15:8];
	if (MWR_N[0] && !mwr_d[0]) sram_lo[MA] <= MD[7:0];
end

st_sram sram (
	.clk(clk),
	.raddr({ 1'b0, ~tos_file, 2'b00, rom_addr[17:1] }),
	.rdata(rom_data),
	.we(ld_we),
	.waddr(ld_addr),
	.wdata(ld_data),
	.MA(MA),
	.MD(MD),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N)
);

// ------------------------------------------------------------------ SDRAM model

// commands at the rising edge of SDR_CLK = the falling edge of clk; CL 2: the data of a READ at
// edge n are on DQ from edge n + 2 until edge n + 3; auto precharge; one bank used
wire [15:0] SDR_DQ;
wire [12:0] SDR_A;
wire [1:0] SDR_BA, SDR_DQM;
wire sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n;
reg [15:0] sdr_mem [0:4194303] /*verilator public_flat_rw*/;
reg [12:0] sdr_row = 13'd0;
reg [15:0] sdr_q1 = 16'd0, sdr_q2 = 16'd0, sdr_q3 = 16'd0;
reg sdr_rd1 = 1'b0, sdr_rd2 = 1'b0, sdr_rd3 = 1'b0;
assign SDR_DQ = sdr_rd3 ? sdr_q3 : 16'bz;
wire [3:0] sdr_cmd = { sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n };
wire [21:0] sdr_waddr = { sdr_row, SDR_A[8:0] };
always @(negedge clk) begin
	sdr_rd3 <= sdr_rd2;
	sdr_q3 <= sdr_q2;
	sdr_rd2 <= sdr_rd1;
	sdr_q2 <= sdr_q1;
	sdr_rd1 <= 1'b0;
	if (sdr_cmd == 4'b0011)            // ACTIVE
		sdr_row <= SDR_A;
	if (sdr_cmd == 4'b0101) begin      // READ
		sdr_rd1 <= 1'b1;
		sdr_q1 <= sdr_mem[sdr_waddr];
	end
	if (sdr_cmd == 4'b0100) begin      // WRITE
		if (!SDR_DQM[1]) sdr_mem[sdr_waddr][15:8] <= SDR_DQ[15:8];
		if (!SDR_DQM[0]) sdr_mem[sdr_waddr][7:0] <= SDR_DQ[7:0];
	end
end

// ------------------------------------------------------------------ the machine

wire [23:1] rom_addr;
wire [15:0] rom_data;
wire rom_n;
wire [14:0] audio_l, audio_r;
wire [14:0] kbd_matrix_out;
wire [7:0] kbd_matrix_in;
wire [5:0] joy0;
wire [4:0] joy1;
wire ram_ras_n, ram_cash_n, ram_casl_n, ram_we_n, ram_ref;
wire [23:1] ram_addr;
wire [15:0] ram_din, ram_dout;
assign audio_l16 = { audio_l[14], audio_l };

atarist st (
	.clk_32(clk), .porb(porb_ext && ram_ready), .resb(resb),
	.mono_detect(mono_detect),
	.r(st_r), .g(st_g), .b(st_b), .hsync_n(st_hs_n), .vsync_n(st_vs_n), .de(st_de), .blank_n(),
	.keyboard_matrix_out(kbd_matrix_out), .keyboard_matrix_in(kbd_matrix_in), .joy0(joy0), .joy1(joy1),
	.audio_mix_l(audio_l), .audio_mix_r(audio_r),
	.sd_lba(fdc_lba), .sd_rd(fdc_rd), .sd_wr(fdc_wr), .sd_ack(sdc_busy), .sd_buff_addr(sdc_byte_addr),
	.sd_dout(sdc_byte_in_data), .sd_din(fdc_out_data), .sd_dout_strobe(sdc_byte_in_strobe),
	.sd_img_mounted({ 2'b00, sdc_img_mounted[1:0] }), .sd_img_size(sdc_img_size),
	.acsi_rd_req(), .acsi_wr_req(), .acsi_sd_lba(), .acsi_sd_done(1'b0), .acsi_sd_busy(1'b0),
	.acsi_sd_rd_byte_strobe(1'b0), .acsi_sd_rd_byte(8'd0), .acsi_sd_wr_byte(), .acsi_sd_byte_addr(9'd0),
	.rtc(52'd0),
	.serial_status(), .serial_tx_available(), .serial_tx_strobe(1'b0), .serial_tx_data(),
	.serial_rx_available(), .serial_rx_strobe(1'b0), .serial_rx_data(8'd0),
	.midi_rx(1'b1), .midi_tx(),
	.parallel_strobe_oe(), .parallel_strobe_in(1'b1), .parallel_strobe_out(), .parallel_data_oe(),
	.parallel_data_in(8'hFF), .parallel_data_out(), .parallel_busy(1'b0),
	.ste(chipset == 2'd2), .enable_extra_ram(1'b0), .blitter_en(chipset != 2'd0),
	.floppy_protected(2'b00), .cubase_en(1'b0),
	.ram_ras_n(ram_ras_n), .ram_cash_n(ram_cash_n), .ram_casl_n(ram_casl_n), .ram_we_n(ram_we_n),
	.ram_ref(ram_ref), .ram_addr(ram_addr), .ram_data_in(ram_din), .ram_data_out(ram_dout),
	.rom_n(rom_n), .rom_addr(rom_addr), .rom_data_out(rom_data),
	.leds()
);

wire [7:0] sdc_img_mounted;
wire [63:0] sdc_img_size;
wire sdc_busy, sdc_byte_in_strobe;
wire [8:0] sdc_byte_addr;
wire [7:0] sdc_byte_in_data, fdc_out_data;
img_sdc #(.OUT_LATENCY(2)) img_sdc (
	.clk(clk), .reset(!porb_ext),
	.img_mounted(img_mounted), .img_size(img_size),
	.img_data_wr(img_data_wr), .img_data_addr(img_data_addr), .img_data(img_data),
	.img_result_wr(img_result_wr), .img_result(img_result), .img_sum(img_sum),
	.img_q_wr(img_q_wr), .img_q_di(img_q_di), .img_q_ack(img_q_ack),
	.sdc_img_mounted(sdc_img_mounted), .sdc_img_size(sdc_img_size),
	.sdc_rd({ 6'd0, fdc_rd }), .sdc_wr({ 6'd0, fdc_wr }), .sdc_sector(fdc_lba),
	.sdc_busy(sdc_busy), .sdc_done(), .sdc_error(), .sdc_slot(),
	.sdc_byte_in_strobe(sdc_byte_in_strobe), .sdc_byte_addr(sdc_byte_addr),
	.sdc_byte_in_data(sdc_byte_in_data), .sdc_byte_out_data(fdc_out_data),
	.active()
);

st_hid hid (
	.clk(clk), .reset(!porb_ext),
	.kb_status(kb_status), .kb_dat0(kb_dat0), .kb_dat1(8'd0), .kb_dat2(8'd0), .kb_dat3(8'd0),
	.kb_dat4(8'd0), .kb_dat5(8'd0),
	.ms_x(8'd0), .ms_y(8'd0), .ms_b(3'd0), .ms_upd(1'b0),
	.joy_l(13'd0), .joy_r(13'd0),
	.matrix_out(kbd_matrix_out), .matrix_in(kbd_matrix_in), .joy0(joy0), .joy1(joy1),
	.kb_reset()
);

sdram sdram (
	.clk(clk), .reset_n(porb_ext), .ready(ram_ready),
	.sd_clk(), .sd_cke(),
	.sd_data(SDR_DQ), .sd_addr(SDR_A), .sd_dqm(SDR_DQM), .sd_ba(SDR_BA),
	.sd_cs(sdr_cs_n), .sd_we(sdr_we_n), .sd_ras(sdr_ras_n), .sd_cas(sdr_cas_n),
	.refresh(ram_ref), .din(ram_din), .dout(ram_dout), .addr(ram_addr[22:1]),
	.ds({ ram_cash_n, ram_casl_n }), .cs(!ram_ras_n && !ram_addr[23]), .we(!ram_we_n)
);

// ------------------------------------------------------------------ video

wire vreset;
video_analyzer analyzer (
	.clk(clk), .hs(st_hs_n), .vs(st_vs_n), .de(st_de), .screen(2'd0), .mode(vmode), .vreset(vreset)
);
wire [5:0] sd_r, sd_g, sd_b;
scandoubler #(10) doubler (
	.clk_sys(clk), .bypass(vmode == 2'd2), .ce_divider(1'b1), .pixel_ena(), .scanlines(2'b00),
	.hs_in(st_hs_n), .vs_in(st_vs_n), .r_in(st_r), .g_in(st_g), .b_in(st_b),
	.hs_out(), .vs_out(), .r_out(sd_r), .g_out(sd_g), .b_out(sd_b)
);
st_video_out vout (
	.clk(clk), .vmode(vmode), .vreset(vreset), .r(sd_r), .g(sd_g), .b(sd_b),
	.rgb(vid_rgb), .hs(vid_hs), .vs(vid_vs), .de(vid_de)
);

endmodule
