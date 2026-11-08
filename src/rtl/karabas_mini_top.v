`timescale 1ns / 1ps
`default_nettype wire

/*
 Atari ST / STE core for Karabas Mini before rev.G (HDMI, sigma-delta audio). The same as
 karabas_minig_top.v except the pins, the MCU link (MCU_SCK not on a clock pin) and the audio:
 AUDIO_L / AUDIO_R instead of the PCM5102.
 The machine of MiSTeryNano (atarist,
 through sv2v in rtl/sv2v) with the board glue of karabas-go-modules.

 Clocks: one PLL, VCO 800 MHz (50 * 16): clk_sys 32.000 MHz (/25: the machine, the SDRAM, the SRAM,
 the video out, the MCU link, audio), clk_8 8.0 MHz (/100, FT_CLK_OUT). A DCM makes the 160 MHz of
 the HDMI serialiser from clk_sys. MiSTeryNano runs at 32.084988 MHz (8 MHz * 4 of the PAL ST);
 at 32.000 the ST line is 64.0 us, its double 31.25 kHz exactly (576p).

 Memory: the ST RAM (4 MB) in the SDRAM (sdram.v of MiSTeryNano, one access per RAS of the ST),
 the TOS in the SRAM (st_sram): EmuTOS of core.json at 100000 (the ROM loader), a TOS file of the
 FL item at 000000; once a file was loaded, its copy is the TOS (tos_file).

 Video (as MiSTeryNano): video_analyzer finds the mode of the ST and a point of its frame,
 scandoubler doubles its lines, and an output timing of 1024 x 626 at 32 MHz (720 x 576 visible,
 576p50 lines) restarts at that point, so the doubled picture sits in its window.

 Floppies and ACSI disks: the F items A:, B: (sdc slots 0, 1) and HDD 0, HDD 1 (slots 2, 3) through
 img_sdc (the file mounter of the mcu, the sd card interface of MiSTeryNano) to fdc1772 and dma /
 acsi; a floppy image mounted read only is write protected.

 The clock of the ST: the registers of kg_mcu with rtc_mode 3 (st_rtc).

 Soft switches (the index of the item in the osd of core.json, file items included):
   0 A: (F 0)   1 B: (F 1)   2 HDD 0 (F 2)   3 HDD 1 (F 3)   4 TOS (FL 7)
   5 Chipset (ST / Mega ST / STE)   6 Monitor (Color / Mono)   7 Reset
*/

module karabas_mini_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,
	inout wire ESP_RESET_N,
	inout wire ESP_BOOT_N,

	output wire [20:0] MA,
	inout wire [15:0] MD,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N,

	output wire [1:0] SDR_BA,
	output wire [12:0] SDR_A,
	output wire SDR_CLK,
	output wire [1:0] SDR_DQM,
	output wire SDR_WE_N,
	output wire SDR_CAS_N,
	output wire SDR_RAS_N,
	inout wire [15:0] SDR_DQ,

	output wire SD_CS_N,
	output wire SD_CLK,
	output wire SD_DI,
	input wire SD_DO,
	input wire SD_DET_N,

	input wire [7:0] VGA_R,
	input wire [7:0] VGA_G,
	input wire [7:0] VGA_B,
	input wire VGA_HS,
	input wire VGA_VS,

	output wire [3:0] TMDS_P,
	output wire [3:0] TMDS_N,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	input wire FT_DE,
	input wire FT_AUDIO,
	input wire FT_DISP,
	output wire FT_RESET,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire AUDIO_L,
	output wire AUDIO_R,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [3:0] MCU_IO, // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire MIDI_CLK,
	output wire MIDI_RESET_N,

	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);

// ------------------------------------------------------------------ unused

assign WA = 3'b000;
assign WCS_N = 2'b11;
assign WRD_N = 1'b1;
assign WWR_N = 1'b1;
assign WRESET_N = 1'b1;
assign WD = 16'bz;

assign TAPE_OUT = 1'b0;
assign MIDI_TX = 1'b1;
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;

assign FLASH_DI = 1'b1;
assign FLASH_SCK = 1'b0;
assign FLASH_WP_N = 1'b1;
assign FLASH_HOLD_N = 1'b1;

assign ADC_CLK = 1'b0;
assign ADC_BCK = 1'bz;
assign ADC_LRCK = 1'bz;
assign ESP_RESET_N = 1'bz;
assign ESP_BOOT_N = 1'bz;
assign FT_RESET = 1'b1;
assign MIDI_CLK = 1'b1;
assign MIDI_RESET_N = 1'b1;

// ------------------------------------------------------------------ clocks

wire clk_sys, clk_8;
wire locked, lockedx5, areset;
wire clk_hdmi, clk_hdmi_n;

wire [5:0] pll_clk;
kg_pll #(
	.CLKIN_PERIOD(20.0),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT(16),
	.CLKOUT0_DIVIDE(25),
	.CLKOUT1_DIVIDE(100),
	.BUFG_MASK(6'b000011)
) pll (
	.clk_in(CLK_50MHZ),
	.rst(1'b0),
	.clk_out(pll_clk),
	.locked(locked)
);
assign clk_sys = pll_clk[0];
assign clk_8 = pll_clk[1];
assign areset = ~locked;

kg_dcm #(
	.CLKIN_PERIOD(31.25),
	.CLKFX_MULTIPLY(5),
	.CLKFX_DIVIDE(1)
) pllx5 (
	.clk_in(clk_sys),
	.rst(areset),
	.clk_fx(clk_hdmi),
	.clk_fx180(clk_hdmi_n),
	.clk_0(),
	.locked(lockedx5)
);

// the clock of the FT812
ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8), .C1(~clk_8), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ MCU

// MCU_SCK is not on a clock pin before rev.G (CLOCK_DEDICATED_ROUTE = FALSE in the ucf)
wire mcu_sck = MCU_SCK, mcu_sck_ibufg = MCU_SCK;

wire mcu_burst_ready;
assign MCU_IO[1] = mcu_burst_ready;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[3:2] = 2'bzz;

wire [7:0] kb_status, kb_dat0, kb_dat1, kb_dat2, kb_dat3, kb_dat4, kb_dat5;
wire [7:0] uart_rx_data, uart_rx_idx, uart_tx_data;
wire uart_tx_wr;
wire [12:0] joy_l, joy_r;
wire [7:0] ms_x, ms_y;
wire [3:0] ms_z;
wire [2:0] ms_b;
wire ms_upd;
wire rom_active, rom_wr;
wire [31:0] rom_addr;
wire [7:0] rom_data;
wire file_active, file_wr;
wire [7:0] file_slot, file_data;
wire [31:0] file_addr;
wire [15:0] softsw_command, osd_command;
wire mcu_busy;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [7:0] img_mounted, img_data, img_result, img_wp;
wire [63:0] img_size;
wire img_data_wr, img_result_wr, img_q_wr, img_q_ack;
wire [8:0] img_data_addr;
wire [15:0] img_sum;
wire [23:0] img_q_di;
wire [7:0] rtc_a, rtc_do;
wire [51:0] st_rtc_digits;

kg_mcu #(
	.BURST_MAX_MHZ(0),   // MCU_SCK is not on a clock pin: bursts at the link clock
	.CS_FILTER(3),
	.ENABLE_RTC(1),       // the clock: rtc_mode 3, see st_rtc
	.ENABLE_UART(0),
	.ENABLE_MATRIX(0),
	.ENABLE_DEBUG(0),
	.ENABLE_IMG(1),      // the floppies A: and B: (slots 0, 1)
	.ENABLE_IMG_WP(1),   // read only images: write protected disks
	.ENABLE_FILE(1),
	.FILE_CMDS(0),       // the ioctl commands of the FL items
	.FILE_WR_EACH(1),
	.FILE_TO_ROM(0),
	.ENABLE_FT(1),
	.ENABLE_SD2(1)
) mcu (
	.CLK(clk_sys),
	.N_RESET(~areset),

	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SCK(mcu_sck),
	.MCU_SS(MCU_CS_N),
	.MCU_SPI_FT_SS(MCU_IO[3]),
	.MCU_SPI_SD2_SS(MCU_IO[2]),
	.MCU_BURST_CS_N(MCU_IO[0]),
	.MCU_BURST_READY(mcu_burst_ready),

	.KB_STATUS(kb_status),
	.KB_DAT0(kb_dat0),
	.KB_DAT1(kb_dat1),
	.KB_DAT2(kb_dat2),
	.KB_DAT3(kb_dat3),
	.KB_DAT4(kb_dat4),
	.KB_DAT5(kb_dat5),
	.KB_SCANCODE(),
	.KB_SCANCODE_UPD(),
	.JOY_L(joy_l),
	.JOY_R(joy_r),
	.MS_X(ms_x),
	.MS_Y(ms_y),
	.MS_Z(ms_z),
	.MS_B(ms_b),
	.MS_UPD(ms_upd),

	.ROMLOADER_ACTIVE(rom_active),
	.ROMLOAD_ADDR(rom_addr),
	.ROMLOAD_DATA(rom_data),
	.ROMLOAD_WR(rom_wr),

	.FILELOAD_ACTIVE(file_active),
	.FILELOAD_ADDR(file_addr),
	.FILELOAD_DATA(file_data),
	.FILELOAD_WR(file_wr),
	.FILELOAD_SLOT(file_slot),

	.SOFTSW_COMMAND(softsw_command),
	.OSD_COMMAND(osd_command),
	.BUSY(mcu_busy),

	.FT_SPI_ON(ft_spi_on),
	.FT_CS_N(ft_cs_n),
	.FT_MOSI(ft_mosi),
	.FT_MISO(FT_SPI_MISO),
	.FT_SCK(),
	.SD2_CS_N(sd2_cs_n),
	.SD2_MOSI(sd2_mosi),
	.SD2_MISO(SD_DO),
	.SD2_SCK(),

	.DVI_ONLY(dvi_only),

	// not used by this core (yet)
	.PS2_COMMAND(16'h0000),
	.PS2_COMMAND_WR(1'b0),
	.RTC_A(rtc_a),
	.RTC_DI(8'd0),
	.RTC_DO(rtc_do),
	.RTC_CS(1'b0),
	.RTC_WR_N(1'b1),
	.UART_RX_DATA(uart_rx_data),
	.UART_RX_IDX(uart_rx_idx),
	.UART_TX_DATA(uart_tx_data),
	.UART_TX_WR(uart_tx_wr),
	.UART_TX_MODE(1'b0),
	.UART_DLM(8'h00),
	.UART_DLL(8'h00),
	.UART_DLM_WR(1'b0),
	.UART_DLL_WR(1'b0),
	.MATRIX_CMD(24'h000000),
	.MATRIX_CMD_WR(1'b0),
	.DEBUG_ADDR(16'h0000),
	.DEBUG_DATA(16'h0000),
	.IMG_MOUNTED(img_mounted),
	.IMG_SIZE(img_size),
	.IMG_WP(img_wp),
	.IMG_DATA_WR(img_data_wr),
	.IMG_DATA_ADDR(img_data_addr),
	.IMG_DATA(img_data),
	.IMG_RESULT_WR(img_result_wr),
	.IMG_RESULT(img_result),
	.IMG_SUM(img_sum),
	.IMG_Q_WR(img_q_wr),
	.IMG_Q_DI(img_q_di),
	.IMG_Q_ACK(img_q_ack),
	.ESP_UART_RX_DATA(8'h00),
	.ESP_UART_RX_WR(1'b0),
	.FLASHBOOT_START(1'b0),
	.FLASHBOOT_COREID(5'd0)
);

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;
assign SD_CS_N = sd2_cs_n;
assign SD_DI = sd2_mosi;
assign SD_CLK = mcu_sck_ibufg;

// ------------------------------------------------------------------ soft switches

wire [8*8-1:0] sw;
kg_soft_switches #(.N(8)) soft_switches (
	.clk(clk_sys),
	.command(softsw_command),
	.regs(sw),
	.upd()
);
wire [1:0] sw_chipset = sw[5*8 +: 2];   // 0 ST, 1 Mega ST (Blitter), 2 STE
wire sw_mono = sw[6*8];                 // the monitor: 0 colour, 1 monochrome
wire sw_reset = sw[7*8];

// ------------------------------------------------------------------ TOS in the SRAM

// a TOS file of the FL item (slot 7) at 000000, the bytes past 256 KB dropped; EmuTOS of core.json
// at 100000 (the ROM loader). The machine is held in reset while either loads.
reg tos_file = 1'b0;
wire tos_file_wr = file_wr && file_slot == 8'd7 && file_addr[31:18] == 14'd0;
always @(posedge clk_sys)
	if (tos_file_wr)
		tos_file <= 1'b1;

wire st_rom_n;
wire [23:1] st_rom_addr;
wire [15:0] st_rom_data;

st_sram sram (
	.clk(clk_sys),
	.raddr({ 1'b0, ~tos_file, 2'b00, st_rom_addr[17:1] }),
	.rdata(st_rom_data),
	.we(rom_wr || tos_file_wr),
	.waddr(rom_wr ? rom_addr[21:0] : { 4'd0, file_addr[17:0] }),
	.wdata(rom_wr ? rom_data : file_data),
	.MA(MA),
	.MD(MD),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N)
);

// ------------------------------------------------------------------ reset

// the SDRAM gets 200 us after the PLL locks before its initialisation (sdram.v starts at once)
reg [12:0] sdr_wait = 13'd0;
always @(posedge clk_sys)
	if (areset)
		sdr_wait <= 13'd0;
	else if (sdr_wait != 13'h1FFF)
		sdr_wait <= sdr_wait + 13'd1;
wire sdr_reset_n = sdr_wait == 13'h1FFF;
wire ram_ready;

// a change of the chipset or the monitor is a power-on reset (TOS sizes the machine and reads
// the monitor type at a cold start)
reg [2:0] chipset_d = 3'd0;
reg [7:0] chip_rst = 8'hFF;
always @(posedge clk_sys) begin
	chipset_d <= { sw_mono, sw_chipset };
	if ({ sw_mono, sw_chipset } != chipset_d || areset)
		chip_rst <= 8'hFF;
	else if (chip_rst != 8'd0)
		chip_rst <= chip_rst - 8'd1;
end

wire kb_reset;
wire tos_loading = rom_active || (file_active && file_slot == 8'd7);
wire porb = !(areset || !ram_ready || chip_rst != 8'd0);
wire resb = !(sw_reset || kb_reset || mcu_busy || tos_loading || !porb);   // porb low also resets the cpu and the peripherals (as upstream)

// ------------------------------------------------------------------ the machine

wire [3:0] st_r, st_g, st_b;
wire st_hs_n, st_vs_n, st_de;
wire [14:0] audio_l, audio_r;
wire [14:0] kbd_matrix_out;
wire [7:0] kbd_matrix_in;
wire [5:0] joy0;
wire [4:0] joy1;
wire ram_ras_n, ram_cash_n, ram_casl_n, ram_we_n, ram_ref;
wire [23:1] ram_addr;
wire [15:0] ram_din, ram_dout;

// ------------------------------------------------------------------ floppies

// img_sdc (the file mounter of the mcu) has the sd card interface of MiSTeryNano that fdc1772 of
// atarist uses: a request bit per drive held until sdc_busy, the sector bytes as strobes with an
// address while busy; for a write it copies the sector out of the fifo of fdc1772, whose read data
// come a clock after the address (OUT_LATENCY 2 as the floppy of nanomig)
wire [7:0] sdc_img_mounted;
wire [63:0] sdc_img_size;
wire [31:0] fdc_lba;
wire [1:0] fdc_rd, fdc_wr;
wire sdc_busy, sdc_done, sdc_error, sdc_byte_in_strobe;
wire [2:0] sdc_slot;
wire [8:0] sdc_byte_addr;
wire [7:0] sdc_byte_in_data, fdc_out_data;
wire img_active;
wire [1:0] acsi_rd, acsi_wr;
wire [31:0] acsi_lba;
wire [7:0] acsi_out_data;
// img_sdc serves one slot at a time, the lowest first: each side takes busy, done and the bytes of
// its own slots only (the floppy would take the ack of an ACSI request as its own)
wire sdc_fdc = (sdc_slot[2:1] == 2'b00);
wire sdc_acsi = (sdc_slot[2:1] == 2'b01);

img_sdc #(.OUT_LATENCY(2)) img_sdc (
	.clk(clk_sys),
	.reset(areset),

	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_data_wr(img_data_wr),
	.img_data_addr(img_data_addr),
	.img_data(img_data),
	.img_result_wr(img_result_wr),
	.img_result(img_result),
	.img_sum(img_sum),
	.img_q_wr(img_q_wr),
	.img_q_di(img_q_di),
	.img_q_ack(img_q_ack),

	.sdc_img_mounted(sdc_img_mounted),
	.sdc_img_size(sdc_img_size),
	.sdc_rd({ 4'd0, acsi_rd, fdc_rd }),
	.sdc_wr({ 4'd0, acsi_wr, fdc_wr }),
	.sdc_sector((fdc_rd != 2'd0 || fdc_wr != 2'd0) ? fdc_lba : acsi_lba),
	.sdc_busy(sdc_busy),
	.sdc_done(sdc_done),
	.sdc_error(sdc_error),
	.sdc_slot(sdc_slot),
	.sdc_byte_in_strobe(sdc_byte_in_strobe),
	.sdc_byte_addr(sdc_byte_addr),
	.sdc_byte_in_data(sdc_byte_in_data),
	.sdc_byte_out_data(sdc_acsi ? acsi_out_data : fdc_out_data),

	.active(img_active)
);

// a change of disk: on the ST the write protect line of the drive is set while a disk goes in or
// out, and TOS finds a new disk by that (it polls the line in its VBL routine: 8 frames per drive,
// so 2^25 clocks = 1 s is enough for both). fdc1772 has no such pulse: without it TOS kept reading
// the directory of the old disk from its cache.
reg [1:0] disk_chg = 2'b00;
reg [24:0] disk_chg_cnt = 25'd0;
always @(posedge clk_sys) begin
	if (|sdc_img_mounted[1:0]) begin
		disk_chg <= disk_chg | sdc_img_mounted[1:0];
		disk_chg_cnt <= 25'h1FFFFFF;
	end
	else if (disk_chg_cnt != 25'd0)
		disk_chg_cnt <= disk_chg_cnt - 25'd1;
	else
		disk_chg <= 2'b00;
end

atarist st (
	.clk_32(clk_sys),
	.porb(porb),
	.resb(resb),

	.mono_detect(!sw_mono),
	.r(st_r),
	.g(st_g),
	.b(st_b),
	.hsync_n(st_hs_n),
	.vsync_n(st_vs_n),
	.de(st_de),
	.blank_n(),

	.keyboard_matrix_out(kbd_matrix_out),
	.keyboard_matrix_in(kbd_matrix_in),
	.joy0(joy0),
	.joy1(joy1),

	.audio_mix_l(audio_l),
	.audio_mix_r(audio_r),

	// the floppies (img_sdc)
	.sd_lba(fdc_lba),
	.sd_rd(fdc_rd),
	.sd_wr(fdc_wr),
	.sd_ack(sdc_busy && sdc_fdc),
	.sd_buff_addr(sdc_byte_addr),
	.sd_dout(sdc_byte_in_data),
	.sd_din(fdc_out_data),
	.sd_dout_strobe(sdc_byte_in_strobe && sdc_fdc),
	.sd_img_mounted(sdc_img_mounted[3:0]),
	.sd_img_size(sdc_img_size),

	// ACSI (img_sdc slots 2, 3)
	.acsi_rd_req(acsi_rd),
	.acsi_wr_req(acsi_wr),
	.acsi_sd_lba(acsi_lba),
	.acsi_sd_done(sdc_done && sdc_acsi),
	.acsi_sd_busy(sdc_busy && sdc_acsi),
	.acsi_sd_rd_byte_strobe(sdc_byte_in_strobe && sdc_acsi),
	.acsi_sd_rd_byte(sdc_byte_in_data),
	.acsi_sd_wr_byte(acsi_out_data),
	.acsi_sd_byte_addr(sdc_byte_addr),

	.rtc(st_rtc_digits),

	.serial_status(),
	.serial_tx_available(),
	.serial_tx_strobe(1'b0),
	.serial_tx_data(),
	.serial_rx_available(),
	.serial_rx_strobe(1'b0),
	.serial_rx_data(8'd0),

	.midi_rx(1'b1),
	.midi_tx(),

	.parallel_strobe_oe(),
	.parallel_strobe_in(1'b1),
	.parallel_strobe_out(),
	.parallel_data_oe(),
	.parallel_data_in(8'hFF),
	.parallel_data_out(),
	.parallel_busy(1'b0),

	.ste(sw_chipset == 2'd2),
	.enable_extra_ram(1'b0),
	.blitter_en(sw_chipset != 2'd0),
	.floppy_protected(img_wp[1:0] | disk_chg),  // read only images; a disk being changed
	.cubase_en(1'b0),

	.ram_ras_n(ram_ras_n),
	.ram_cash_n(ram_cash_n),
	.ram_casl_n(ram_casl_n),
	.ram_we_n(ram_we_n),
	.ram_ref(ram_ref),
	.ram_addr(ram_addr),
	.ram_data_in(ram_din),
	.ram_data_out(ram_dout),

	.rom_n(st_rom_n),
	.rom_addr(st_rom_addr),
	.rom_data_out(st_rom_data),

	.leds()
);

// the clock of the ST from the registers of the mcu
st_rtc st_rtc (
	.clk(clk_sys),
	.rtc_a(rtc_a),
	.rtc_do(rtc_do),
	.digits(st_rtc_digits)
);

st_hid hid (
	.clk(clk_sys),
	.reset(areset),
	.kb_status(kb_status),
	.kb_dat0(kb_dat0),
	.kb_dat1(kb_dat1),
	.kb_dat2(kb_dat2),
	.kb_dat3(kb_dat3),
	.kb_dat4(kb_dat4),
	.kb_dat5(kb_dat5),
	.ms_x(ms_x),
	.ms_y(ms_y),
	.ms_b(ms_b),
	.ms_upd(ms_upd),
	.joy_l(joy_l),
	.joy_r(joy_r),
	.matrix_out(kbd_matrix_out),
	.matrix_in(kbd_matrix_in),
	.joy0(joy0),
	.joy1(joy1),
	.kb_reset(kb_reset)
);

// ------------------------------------------------------------------ ST RAM in the SDRAM

// one access per RAS of the ST (ram_addr[23] is the extra RAM, off); SDR_CLK is clk_sys inverted
// (an ODDR2): a command is in the middle of its SDRAM clock. FLASH_CS_N (T3) is the SDRAM /CS of
// Mini G2 (rev G: tied low on the board, the pin goes to the unpopulated config flash).
wire sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n;
sdram sdram (
	.clk(clk_sys),
	.reset_n(sdr_reset_n),
	.ready(ram_ready),
	.sd_clk(),
	.sd_cke(),
	.sd_data(SDR_DQ),
	.sd_addr(SDR_A),
	.sd_dqm(SDR_DQM),
	.sd_ba(SDR_BA),
	.sd_cs(sdr_cs_n),
	.sd_we(sdr_we_n),
	.sd_ras(sdr_ras_n),
	.sd_cas(sdr_cas_n),
	.refresh(ram_ref),
	.din(ram_din),
	.dout(ram_dout),
	.addr(ram_addr[22:1]),
	.ds({ ram_cash_n, ram_casl_n }),
	.cs(!ram_ras_n && !ram_addr[23]),
	.we(!ram_we_n)
);
assign SDR_RAS_N = sdr_ras_n;
assign SDR_CAS_N = sdr_cas_n;
assign SDR_WE_N = sdr_we_n;
assign FLASH_CS_N = sdr_cs_n;
ODDR2 oddr_sdr_clk (.Q(SDR_CLK), .C0(clk_sys), .C1(~clk_sys), .CE(1'b1), .D0(1'b0), .D1(1'b1), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ video

wire [1:0] vmode;   // 0 NTSC, 1 PAL, 2 mono
wire vreset;
video_analyzer analyzer (
	.clk(clk_sys),
	.hs(st_hs_n),
	.vs(st_vs_n),
	.de(st_de),
	.screen(2'd0),
	.mode(vmode),
	.vreset(vreset)
);

wire [5:0] sd_r, sd_g, sd_b;
scandoubler #(10) doubler (
	.clk_sys(clk_sys),
	.bypass(vmode == 2'd2),
	.ce_divider(1'b1),
	.pixel_ena(),
	.scanlines(2'b00),
	.hs_in(st_hs_n),
	.vs_in(st_vs_n),
	.r_in(st_r),
	.g_in(st_g),
	.b_in(st_b),
	.hs_out(),
	.vs_out(),
	.r_out(sd_r),
	.g_out(sd_g),
	.b_out(sd_b)
);

wire [23:0] vid_rgb;
wire vid_hs, vid_vs, vid_de;
st_video_out vout (
	.clk(clk_sys),
	.vmode(vmode),
	.vreset(vreset),
	.r(sd_r),
	.g(sd_g),
	.b(sd_b),
	.rgb(vid_rgb),
	.hs(vid_hs),
	.vs(vid_vs),
	.de(vid_de)
);

// the OSD of the mcu: 1024-clock lines (a step per 2 clocks), 626 lines (a step per 2 lines). The
// counters start at the leading edge of the syncs: the 720 x 576 window starts 280 clocks / 45
// lines after them, the OSD (512 x 416) in its middle: 280 + 104 clocks, 45 + 80 lines.
reg [15:0] osd_cmd = 16'd0;
always @(posedge clk_sys)
	osd_cmd <= osd_command;
wire [23:0] osd_rgb;
kg_osd_overlay #(.H_OFFSET(192), .V_OFFSET(62), .H_DIV4_WIDTH(1100)) osd (
	.clk(clk_sys),
	.rgb_i(vid_rgb),
	.rgb_o(osd_rgb),
	.hsync_i(vid_hs),
	.vsync_i(vid_vs),
	.v_offset(11'd0),
	.h_offset(11'd0),
	.osd_command(osd_cmd)
);

// ------------------------------------------------------------------ audio

// the YM2149 and DMA sound mix of atarist: 15 bits, signed
wire [15:0] aud_l = { audio_l[14], audio_l };
wire [15:0] aud_r = { audio_r[14], audio_r };

// no I2S DAC on this board: sigma-delta outputs into an RC filter, offset binary input
kg_sigma_delta_dac dac_l (.clk(clk_sys), .reset(areset), .din({ ~aud_l[15], aud_l[14:0] }), .dout(AUDIO_L));
kg_sigma_delta_dac dac_r (.clk(clk_sys), .reset(areset), .din({ ~aud_r[15], aud_r[14:0] }), .dout(AUDIO_R));

// 48 kHz for hdmi_tx: + 3 per clock of 32 MHz, modulo 2000
reg [10:0] aud_acc = 11'd0;
reg aud_stb = 1'b0;
reg [23:0] hdmi_l = 24'd0, hdmi_r = 24'd0;
always @(posedge clk_sys) begin
	aud_stb <= 1'b0;
	if (aud_acc >= 11'd2000 - 11'd3) begin
		aud_acc <= aud_acc + 11'd3 - 11'd2000;
		aud_stb <= 1'b1;
		hdmi_l <= { aud_l, 8'd0 };
		hdmi_r <= { aud_r, 8'd0 };
	end
	else
		aud_acc <= aud_acc + 11'd3;
end

// ------------------------------------------------------------------ HDMI

// 576p: negative syncs
hdmi_tx #(.SAMPLE_FREQ(48000)) hdmi (
	.clk(clk_sys),
	.sclk(clk_hdmi),
	.sclk_n(clk_hdmi_n),
	.reset(~lockedx5),
	.rgb(osd_rgb),
	.vsync(~vid_vs),
	.hsync(~vid_hs),
	.de(vid_de),
	.audio_en(~dvi_only),
	.audio_l(hdmi_l),
	.audio_r(hdmi_r),
	.audio_clk(aud_stb),
	.tx_clk_n(TMDS_N[3]),
	.tx_clk_p(TMDS_P[3]),
	.tx_d_n(TMDS_N[2:0]),
	.tx_d_p(TMDS_P[2:0])
);

endmodule
