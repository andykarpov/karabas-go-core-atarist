module atarist (
	clk_32,
	porb,
	resb,
	mono_detect,
	r,
	g,
	b,
	hsync_n,
	vsync_n,
	de,
	blank_n,
	keyboard_matrix_out,
	keyboard_matrix_in,
	joy0,
	joy1,
	audio_mix_l,
	audio_mix_r,
	sd_lba,
	sd_rd,
	sd_wr,
	sd_ack,
	sd_buff_addr,
	sd_dout,
	sd_din,
	sd_dout_strobe,
	sd_img_mounted,
	sd_img_size,
	acsi_rd_req,
	acsi_wr_req,
	acsi_sd_lba,
	acsi_sd_done,
	acsi_sd_busy,
	acsi_sd_rd_byte_strobe,
	acsi_sd_rd_byte,
	acsi_sd_wr_byte,
	acsi_sd_byte_addr,
	rtc,
	serial_status,
	serial_tx_available,
	serial_tx_strobe,
	serial_tx_data,
	serial_rx_available,
	serial_rx_strobe,
	serial_rx_data,
	midi_rx,
	midi_tx,
	parallel_strobe_oe,
	parallel_strobe_in,
	parallel_strobe_out,
	parallel_data_oe,
	parallel_data_in,
	parallel_data_out,
	parallel_busy,
	ste,
	enable_extra_ram,
	blitter_en,
	floppy_protected,
	cubase_en,
	ram_ras_n,
	ram_cash_n,
	ram_casl_n,
	ram_we_n,
	ram_ref,
	ram_addr,
	ram_data_in,
	ram_data_out,
	rom_n,
	rom_addr,
	rom_data_out,
	leds
);
	input wire clk_32;
	input wire porb;
	input wire resb;
	input wire mono_detect;
	output wire [3:0] r;
	output wire [3:0] g;
	output wire [3:0] b;
	output wire hsync_n;
	output wire vsync_n;
	output wire de;
	output wire blank_n;
	output wire [14:0] keyboard_matrix_out;
	input wire [7:0] keyboard_matrix_in;
	input wire [5:0] joy0;
	input wire [4:0] joy1;
	output wire [14:0] audio_mix_l;
	output wire [14:0] audio_mix_r;
	output wire [31:0] sd_lba;
	output wire [1:0] sd_rd;
	output wire [1:0] sd_wr;
	input sd_ack;
	input [8:0] sd_buff_addr;
	input [7:0] sd_dout;
	output wire [7:0] sd_din;
	input sd_dout_strobe;
	input [3:0] sd_img_mounted;
	input [63:0] sd_img_size;
	output wire [1:0] acsi_rd_req;
	output wire [1:0] acsi_wr_req;
	output wire [31:0] acsi_sd_lba;
	input acsi_sd_done;
	input acsi_sd_busy;
	input acsi_sd_rd_byte_strobe;
	input [7:0] acsi_sd_rd_byte;
	output wire [7:0] acsi_sd_wr_byte;
	input [8:0] acsi_sd_byte_addr;
	input [11:0] rtc;
	output wire [31:0] serial_status;
	output wire [7:0] serial_tx_available;
	input serial_tx_strobe;
	output wire [7:0] serial_tx_data;
	output wire [7:0] serial_rx_available;
	input serial_rx_strobe;
	input [7:0] serial_rx_data;
	input wire midi_rx;
	output wire midi_tx;
	output wire parallel_strobe_oe;
	input parallel_strobe_in;
	output wire parallel_strobe_out;
	output wire parallel_data_oe;
	input [7:0] parallel_data_in;
	output wire [7:0] parallel_data_out;
	input parallel_busy;
	input wire ste;
	input wire enable_extra_ram;
	input wire blitter_en;
	input [1:0] floppy_protected;
	input cubase_en;
	output wire ram_ras_n;
	output wire ram_cash_n;
	output wire ram_casl_n;
	output wire ram_we_n;
	output wire ram_ref;
	output wire [23:1] ram_addr;
	output wire [15:0] ram_data_in;
	input wire [15:0] ram_data_out;
	output wire rom_n;
	output wire [23:1] rom_addr;
	input wire [15:0] rom_data_out;
	output wire [3:0] leds;
	reg reset;
	reg peripheral_reset;
	reg mcu_reset_n = 1'b1;
	reg [6:0] reset_cnt = 7'h7f;
	reg cpu_reset_n_d;
	wire ext_reset = !resb;
	wire cart_n;
	wire [15:0] cart_data_out;
	wire cpu_reset_n_o;
	always @(posedge clk_32) begin
		cpu_reset_n_d <= cpu_reset_n_o;
		reset <= reset_cnt != 0;
		if (reset_cnt != 0)
			reset_cnt <= reset_cnt - 1'd1;
		if (ext_reset)
			reset_cnt <= 7'h7f;
		peripheral_reset <= reset | ~cpu_reset_n_o;
		if (reset_cnt == 10)
			mcu_reset_n <= 0;
		else if (reset_cnt < 8)
			mcu_reset_n <= 1;
		if (~cpu_reset_n_o & cpu_reset_n_d)
			mcu_reset_n <= 0;
	end
	reg [31:0] clk_cnt_mfp;
	reg clk_mfp_en;
	localparam SYSTEM_CLOCK = 32'd32084988;
	localparam MFP_CLOCK = 32'd2457600;
	always @(posedge clk_32)
		if (!porb) begin
			clk_cnt_mfp <= 32'd0;
			clk_mfp_en <= 1'b0;
		end
		else begin
			clk_mfp_en <= 1'b0;
			if (clk_cnt_mfp < SYSTEM_CLOCK)
				clk_cnt_mfp <= clk_cnt_mfp + MFP_CLOCK;
			else begin
				clk_cnt_mfp <= (clk_cnt_mfp - SYSTEM_CLOCK) + MFP_CLOCK;
				clk_mfp_en <= 1'b1;
			end
		end
	wire mhz4;
	wire mhz4_en;
	wire clk16;
	wire mcu_dtack_n;
	wire ras0_n;
	wire ras1_n;
	wire cas0h_n;
	wire cas0l_n;
	wire cas1h_n;
	wire cas1l_n;
	assign ram_cash_n = cas0h_n & cas1h_n;
	assign ram_casl_n = cas0l_n & cas1l_n;
	wire mfpint_n;
	wire mfpcs_n;
	wire mfpiack_n;
	wire sndir;
	wire sndcs;
	wire n6850;
	wire fcs_n;
	wire rtccs_n;
	wire rtcrd_n;
	wire rtcwr_n;
	wire sint;
	wire [15:0] mcu_dout;
	wire mcu_oe_l;
	wire mcu_oe_h;
	assign ram_ras_n = ras0_n & ras1_n;
	wire button_n;
	wire joywe_n;
	wire joyrl_n;
	wire joywl;
	wire joyrh_n;
	wire rdy_o;
	wire rdy_i;
	wire mcu_bg_n;
	wire mcu_br_n;
	wire mcu_bgack_n;
	wire blitter_as_n;
	wire blitter_has_bus;
	wire cpu_as_n;
	wire as_n = (blitter_has_bus ? blitter_as_n : cpu_as_n);
	wire blitter_fc0 = 1'b1;
	wire cpu_fc0;
	wire fc0 = (blitter_has_bus ? blitter_fc0 : cpu_fc0);
	wire blitter_fc1 = 1'b0;
	wire cpu_fc1;
	wire fc1 = (blitter_has_bus ? blitter_fc1 : cpu_fc1);
	wire blitter_fc2 = 1'b1;
	wire cpu_fc2;
	wire fc2 = (blitter_has_bus ? blitter_fc2 : cpu_fc2);
	wire [23:1] blitter_addr;
	wire [23:1] cpu_a;
	wire [23:1] mbus_a = (blitter_has_bus ? blitter_addr : cpu_a);
	wire iodevice = ((~as_n & fc2) & (fc0 ^ fc1)) & (mbus_a[23:16] == 8'hff);
	wire mhz8;
	wire mhz8_en1;
	wire mhz8_en2;
	wire berr_n;
	wire ipl0_n;
	wire ipl1_n;
	wire ipl2_n;
	wire cpu_rw;
	wire cpu_uds_n;
	wire cpu_lds_n;
	wire vma_n;
	wire vpa_n;
	wire cpu_E;
	wire [15:0] cpu_din;
	wire [15:0] cpu_dout;
	wire blitter_br_n;
	wire blitter_bgack_n;
	wire blitter_bg_n;
	wire blitter_sel;
	wire [15:0] blitter_data_out;
	wire [15:0] dma_data_out;
	assign rom_addr = mbus_a;
	wire [7:0] snd_data_out;
	wire [7:0] kbd_acia_data_out;
	wire [7:0] mfp_data_out;
	wire [7:0] midi_acia_data_out;
	wire rdat_n;
	reg [3:0] rtc_data_out;
	wire blitter_rw_n;
	wire rw = (blitter_has_bus ? blitter_rw_n : cpu_rw);
	wire [15:0] shifter_dout;
	wire snd_data_oe_l;
	assign cpu_din = (((((((((~fcs_n & rw ? dma_data_out : 16'hffff) & (blitter_sel ? blitter_data_out : 16'hffff)) & (rdat_n ? 16'hffff : shifter_dout)) & {8'hff, (mfpcs_n & mfpiack_n ? 8'hff : mfp_data_out)}) & (cart_n ? 16'hffff : cart_data_out)) & (rom_n ? 16'hffff : rom_data_out)) & {(n6850 & rw ? (mbus_a[2] ? midi_acia_data_out : kbd_acia_data_out) : 8'hff), 8'hff}) & {(snd_data_oe_l ? 8'hff : snd_data_out), 8'hff}) & {12'hfff, (rtccs_n & rw ? 4'hf : rtc_data_out)}) & {(mcu_oe_h ? mcu_dout[15:8] : 8'hff), (mcu_oe_l ? mcu_dout[7:0] : 8'hff)};
	wire cmpcs_n;
	wire latch;
	wire wdat_n;
	wire dcyc_n;
	wire sreq;
	wire sload_n;
	wire mono;
	wire [7:0] dma_snd_l;
	wire [7:0] dma_snd_r;
	wire blitter_ds_n;
	wire uds_n = (blitter_has_bus ? blitter_ds_n : cpu_uds_n);
	wire lds_n = (blitter_has_bus ? blitter_ds_n : cpu_lds_n);
	wire [15:0] mbus_dout = (!rdat_n ? shifter_dout : (!rom_n ? rom_data_out : (blitter_sel ? blitter_data_out : (~rdy_i ? dma_data_out : cpu_dout))));
	wire blitter_dtack_n;
	reg [3:0] as_n_cnt;
	wire cpu_16mhz_enable = 1'b0;
	wire mcu_dtack_n_adj = (!cpu_16mhz_enable ? mcu_dtack_n : (as_n_cnt < 7 ? 1'b1 : mcu_dtack_n));
	wire mfp_dtack;
	wire dtack_n = (mcu_dtack_n_adj & ~mfp_dtack) & blitter_dtack_n;
	reg rom_nD;
	reg rom192k;
	always @(posedge clk_32)
		if (!porb) begin
			rom192k <= 1'b1;
			rom_nD <= 1'b1;
		end
		else begin
			rom_nD <= rom_n;
			if ((rom_n == 1'b1) && (rom_nD == 1'b0)) begin
				if (rom_addr == 23'd2)
					rom192k <= rom_data_out == 16'h00fc;
			end
		end
	gstmcu gstmcu(
		.clk32(clk_32),
		.resb(mcu_reset_n),
		.porb(porb),
		.FC0(fc0),
		.FC1(fc1),
		.FC2(fc2),
		.AS_N(as_n),
		.RW(rw),
		.UDS_N(uds_n),
		.LDS_N(lds_n),
		.VMA_N(vma_n),
		.MFPINT_N(mfpint_n),
		.A(mbus_a),
		.ADDR(ram_addr),
		.DIN((~rdy_i ? dma_data_out : (blitter_sel ? blitter_data_out : (!rdat_n ? shifter_dout : cpu_dout)))),
		.DOUT(mcu_dout),
		.OE_L(mcu_oe_l),
		.OE_H(mcu_oe_h),
		.CLK_O(clk16),
		.MHZ8(mhz8),
		.MHZ8_EN1(mhz8_en1),
		.MHZ8_EN2(mhz8_en2),
		.MHZ4(mhz4),
		.MHZ4_EN(mhz4_en),
		.RDY_N_I(rdy_o),
		.RDY_N_O(rdy_i),
		.BG_N(mcu_bg_n),
		.BR_N_I(blitter_br_n),
		.BR_N_O(mcu_br_n),
		.BGACK_N_I(1'b1),
		.BGACK_N_O(mcu_bgack_n),
		.BERR_N(berr_n),
		.IPL0_N(ipl0_n),
		.IPL1_N(ipl1_n),
		.IPL2_N(ipl2_n),
		.DTACK_N_I(dtack_n),
		.DTACK_N_O(mcu_dtack_n),
		.IACK_N(mfpiack_n),
		.ROM0_N(),
		.ROM1_N(),
		.ROM2_N(rom_n),
		.ROM3_N(cart_n),
		.ROM4_N(),
		.ROM5_N(),
		.ROM6_N(),
		.ROMP_N(),
		.RAM_N(),
		.RAS0_N(ras0_n),
		.RAS1_N(ras1_n),
		.CAS0L_N(cas0l_n),
		.CAS0H_N(cas0h_n),
		.CAS1L_N(cas1l_n),
		.CAS1H_N(cas1h_n),
		.RAM_LDS(),
		.RAM_UDS(),
		.REF(ram_ref),
		.VPA_N(vpa_n),
		.MFPCS_N(mfpcs_n),
		.SNDIR(sndir),
		.SNDCS(sndcs),
		.N6850(n6850),
		.FCS_N(fcs_n),
		.RTCCS_N(rtccs_n),
		.RTCRD_N(rtcrd_n),
		.RTCWR_N(rtcwr_n),
		.LATCH(latch),
		.HSYNC_N(hsync_n),
		.VSYNC_N(vsync_n),
		.DE(de),
		.BLANK_N(blank_n),
		.RDAT_N(rdat_n),
		.WE_N(ram_we_n),
		.WDAT_N(wdat_n),
		.CMPCS_N(cmpcs_n),
		.DCYC_N(dcyc_n),
		.SREQ(sreq),
		.SLOAD_N(sload_n),
		.SINT(sint),
		.BUTTON_N(button_n),
		.JOYWE_N(joywe_n),
		.JOYRL_N(joyrl_n),
		.JOYWL(joywl),
		.JOYRH_N(joyrh_n),
		.st(~ste),
		.extra_ram(enable_extra_ram),
		.tos192k(rom192k),
		.turbo(1'b0),
		.viking_at_c0(1'b0),
		.viking_at_e8(1'b0),
		.bus_cycle()
	);
	gstshifter gstshifter(
		.clk32(clk_32),
		.ste(ste),
		.resb(~peripheral_reset),
		.CS(~cmpcs_n),
		.A(mbus_a[6:1]),
		.DIN(mbus_dout),
		.DOUT(shifter_dout),
		.LATCH(latch),
		.RDAT_N(rdat_n),
		.WDAT_N(wdat_n),
		.RW(rw),
		.MDIN(ram_data_out),
		.MDOUT(ram_data_in),
		.MONO_OUT(mono),
		.LOAD_N(dcyc_n),
		.DE(de),
		.BLANK_N(blank_n),
		.R(r),
		.G(g),
		.B(b),
		.SLOAD_N(sload_n),
		.SREQ(sreq),
		.audio_left(dma_snd_l),
		.audio_right(dma_snd_r)
	);
	wire clk16_en = ~clk16;
	wire phi1 = (cpu_16mhz_enable ? clk16_en : mhz8_en1);
	wire phi2 = (cpu_16mhz_enable ? ~clk16_en : mhz8_en2);
	reg as_n_D;
	always @(posedge clk_32) begin
		as_n_D <= cpu_as_n;
		if (!cpu_as_n) begin
			if (as_n_D)
				as_n_cnt <= 4'd0;
			else if ((as_n_cnt != 4'd15) && !((cpu_a[23:22] == 2'b00) && (ram_ref || !dcyc_n)))
				as_n_cnt <= as_n_cnt + 4'd1;
		end
		else
			as_n_cnt <= 4'd0;
	end
	wire rom = !cpu_as_n && (cpu_a[23:18] == 6'b111111);
	wire ram = !cpu_as_n && (cpu_a[23:22] == 2'b00);
	fx68k fx68k(
		.clk(clk_32),
		.extReset(reset),
		.pwrUp(!porb),
		.enPhi1(phi1),
		.enPhi2(phi2),
		.eRWn(cpu_rw),
		.ASn(cpu_as_n),
		.LDSn(cpu_lds_n),
		.UDSn(cpu_uds_n),
		.E(cpu_E),
		.VMAn(vma_n),
		.FC0(cpu_fc0),
		.FC1(cpu_fc1),
		.FC2(cpu_fc2),
		.BGn(blitter_bg_n),
		.oRESETn(cpu_reset_n_o),
		.oHALTEDn(),
		.DTACKn(dtack_n),
		.VPAn(vpa_n),
		.BERRn(berr_n),
		.HALTn(1'b1),
		.BRn(blitter_br_n & mcu_br_n),
		.BGACKn(blitter_bgack_n),
		.IPL0n(ipl0_n),
		.IPL1n(ipl1_n),
		.IPL2n(ipl2_n),
		.iEdb(cpu_din),
		.oEdb(cpu_dout),
		.eab(cpu_a)
	);
	wire kbd_acia_irq;
	wire midi_acia_irq;
	wire acia_irq = kbd_acia_irq || midi_acia_irq;
	wire xsint = ~sint;
	reg [7:0] xsint_delay;
	reg clk_2_en;
	always @(posedge clk_32 or negedge xsint)
		if (!xsint)
			xsint_delay <= 8'h00;
		else if (clk_2_en)
			xsint_delay <= {xsint_delay[6:0], xsint};
	wire xsint_delayed = xsint_delay[7];
	wire mfp_io7 = mono_detect ^ (ste ? xsint : 1'b0);
	wire acsi_irq;
	wire fdc_irq;
	wire blitter_irq_n;
	wire [7:0] mfp_gpio_in = {mfp_io7, 1'b1, !(acsi_irq | fdc_irq), !acia_irq, blitter_irq_n, 2'b11, parallel_busy};
	wire [1:0] mfp_timer_in = {de, (ste ? xsint_delayed : parallel_busy)};
	wire mfp_int;
	wire mfp_iack = ~mfpiack_n;
	assign mfpint_n = ~mfp_int;
	mfp mfp(
		.clk(clk_32),
		.clk_en(mhz4_en),
		.reset(peripheral_reset),
		.din(mbus_dout[7:0]),
		.sel(~mfpcs_n),
		.addr(mbus_a[5:1]),
		.ds(lds_n),
		.rw(rw),
		.dout(mfp_data_out),
		.irq(mfp_int),
		.iack(mfp_iack),
		.dtack(mfp_dtack),
		.serial_status_out(serial_status),
		.serial_data_out_available(serial_tx_available),
		.serial_strobe_out(serial_tx_strobe),
		.serial_data_out(serial_tx_data),
		.serial_data_in_free(serial_rx_available),
		.serial_strobe_in(serial_rx_strobe),
		.serial_data_in(serial_rx_data),
		.clk_ext(clk_mfp_en),
		.t_i(mfp_timer_in),
		.i(mfp_gpio_in)
	);
	wire ikbd_tx;
	wire ikbd_rx;
	ikbd #(.DIV(4)) ikbd(
		.clk(clk_32),
		.res(peripheral_reset),
		.tx(ikbd_tx),
		.rx(ikbd_rx),
		.matrix_out(keyboard_matrix_out),
		.matrix_in(keyboard_matrix_in),
		.caps_lock(),
		.joystick0({joy0[5:4], joy0[0], joy0[1], joy0[2], joy0[3]}),
		.joystick1({joy1[4], joy1[0], joy1[1], joy1[2], joy1[3]})
	);
	acia #(.INPUT_FILTER(0)) kbd_acia(
		.clk(clk_32),
		.E(cpu_E),
		.reset(reset),
		.din(mbus_dout[15:8]),
		.sel(n6850 & ~mbus_a[2]),
		.rs(mbus_a[1]),
		.rw(rw),
		.dout(kbd_acia_data_out),
		.irq(kbd_acia_irq),
		.rxtxclk_sel(1'b0),
		.dout_strobe(),
		.rx(ikbd_tx),
		.tx(ikbd_rx)
	);
	acia midi_acia(
		.clk(clk_32),
		.E(cpu_E),
		.reset(reset),
		.din(mbus_dout[15:8]),
		.sel(n6850 & mbus_a[2]),
		.rs(mbus_a[1]),
		.rw(rw),
		.dout(midi_acia_data_out),
		.irq(midi_acia_irq),
		.rxtxclk_sel(1'b0),
		.rx(midi_rx),
		.tx(midi_tx),
		.dout_strobe()
	);
	wire [7:0] ym_a_out;
	wire [7:0] ym_b_out;
	wire [7:0] ym_c_out;
	wire [9:0] ym_audio_out_l;
	wire [9:0] ym_audio_out_r;
	always @(posedge clk_32) begin : sv2v_autoblock_1
		reg [3:0] cnt;
		clk_2_en <= cnt == 0;
		cnt <= cnt + 1'd1;
	end
	wire [7:0] port_a_out;
	wire [7:0] port_a_in = {port_a_out[7:6], parallel_strobe_in, port_a_out[4:0]};
	wire port_a_oe;
	wire [7:0] port_b_in = parallel_data_in;
	wire [7:0] port_b_out;
	wire port_b_oe;
	wire floppy_side = port_a_out[0];
	wire [1:0] floppy_sel = port_a_out[2:1];
	assign parallel_strobe_oe = port_a_oe;
	assign parallel_strobe_out = port_a_out[5];
	assign parallel_data_oe = port_b_oe;
	assign parallel_data_out = port_b_out;
	assign ym_audio_out_r = ym_audio_out_l;
	assign snd_data_oe_l = !((sndir == 1'b0) && (sndcs == 1'b1));
	jt49_bus jt49_bus(
		.rst_n(~peripheral_reset),
		.clk(clk_32),
		.clk_en(clk_2_en),
		.bdir(sndir),
		.bc1(sndcs),
		.din(mbus_dout[15:8]),
		.sel(1'b1),
		.dout(snd_data_out),
		.sound(ym_audio_out_l),
		.A(),
		.B(),
		.C(),
		.sample(),
		.IOA_in(port_a_in),
		.IOA_out(port_a_out),
		.IOA_oe(port_a_oe),
		.IOB_in(port_b_in),
		.IOB_out(port_b_out),
		.IOB_oe(port_b_oe)
	);
	wire [9:0] ym_audio_out_l_signed = ym_audio_out_l - 10'h200;
	wire [9:0] ym_audio_out_r_signed = ym_audio_out_r - 10'h200;
	wire [7:0] ste_audio_out_l_signed = dma_snd_l - 8'h80;
	wire [7:0] ste_audio_out_r_signed = dma_snd_r - 8'h80;
	assign audio_mix_l = {ym_audio_out_l_signed[9], ym_audio_out_l_signed, ym_audio_out_l_signed[9:6]} + {ste_audio_out_l_signed[7], ste_audio_out_l_signed, ste_audio_out_l_signed[7:2]};
	assign audio_mix_r = {ym_audio_out_r_signed[9], ym_audio_out_r_signed, ym_audio_out_r_signed[9:6]} + {ste_audio_out_r_signed[7], ste_audio_out_r_signed, ste_audio_out_r_signed[7:2]};
	wire mblit_selected;
	wire mblit_oBGACKn;
	stBlitter stBlitter(
		.clk(clk_32),
		.aRESETn(!peripheral_reset),
		.pwrUp(!porb),
		.enPhi1((cpu_16mhz_enable ? clk16_en : mhz8_en1)),
		.enPhi2((cpu_16mhz_enable ? ~clk16_en : mhz8_en2)),
		.ASn(as_n | ~blitter_en),
		.RWn(cpu_rw),
		.LDSn(lds_n),
		.UDSn(uds_n),
		.FC0(fc0),
		.FC1(fc1),
		.FC2(fc2),
		.BERRn(berr_n),
		.iDTACKn(dtack_n),
		.ctrlOe(blitter_has_bus),
		.dataOe(blitter_sel),
		.oASn(blitter_as_n),
		.oDSn(blitter_ds_n),
		.oRWn(blitter_rw_n),
		.oDTACKn(blitter_dtack_n),
		.selected(mblit_selected),
		.iBRn(mcu_br_n),
		.BGIn(blitter_bg_n),
		.iBGACKn(mcu_bgack_n),
		.oBRn(blitter_br_n),
		.oBGACKn(mblit_oBGACKn),
		.INTn(blitter_irq_n),
		.BGOn(mcu_bg_n),
		.dmaInput(mbus_dout),
		.iABUS(mbus_a),
		.oABUS(blitter_addr),
		.iDBUS(cpu_dout),
		.oDBUS(blitter_data_out)
	);
	assign blitter_bgack_n = mblit_oBGACKn & mcu_bgack_n;
	assign {blitter_fc2, blitter_fc1, blitter_fc0} = 3'b101;
	wire [15:0] ste_joy_in;
	wire [3:0] ste_buttons;
	reg [7:0] ste_joy_out;
	wire [7:0] ste_joy_out_pins = (joywe_n ? 8'hff : ste_joy_out);
	always @(posedge clk_32)
		if (joywl)
			ste_joy_out <= mbus_dout[7:0];
	ste_joypad ste_joypad0(
		.joy(16'd0),
		.din(ste_joy_out_pins[3:0]),
		.dout({ste_joy_in[11:8], ste_joy_in[3:0]}),
		.buttons(ste_buttons[1:0])
	);
	ste_joypad ste_joypad1(
		.joy(16'd0),
		.din(ste_joy_out_pins[7:4]),
		.dout({ste_joy_in[15:12], ste_joy_in[7:4]}),
		.buttons(ste_buttons[3:2])
	);
	reg rtc_present = 1'b0;
	reg rtc_bank;
	reg [3:0] rtc_bank1 [0:15];
	reg [3:0] rtc_reg_0;
	reg [3:0] rtc_reg_1;
	reg [3:0] rtc_reg_2;
	reg [3:0] rtc_reg_3;
	reg [3:0] rtc_reg_4;
	reg [3:0] rtc_reg_5;
	reg [3:0] rtc_reg_6;
	reg [3:0] rtc_reg_7;
	reg [3:0] rtc_reg_8;
	reg [3:0] rtc_reg_9;
	reg [3:0] rtc_reg_A;
	reg [3:0] rtc_reg_B;
	reg [3:0] rtc_reg_C;
	always @(*) begin
		casez ({rtc_bank, mbus_a[4:1]})
			5'b00000: rtc_data_out = rtc_reg_0;
			5'b00001: rtc_data_out = rtc_reg_1;
			5'b00010: rtc_data_out = rtc_reg_2;
			5'b00011: rtc_data_out = rtc_reg_3;
			5'b00100: rtc_data_out = rtc_reg_4;
			5'b00101: rtc_data_out = rtc_reg_5;
			5'b00110: rtc_data_out = rtc_reg_C;
			5'b00111: rtc_data_out = rtc_reg_6;
			5'b01000: rtc_data_out = rtc_reg_7;
			5'b01001: rtc_data_out = rtc_reg_8;
			5'b01010: rtc_data_out = rtc_reg_9;
			5'b01011: rtc_data_out = rtc_reg_A;
			5'b01100: rtc_data_out = rtc_reg_B;
			5'bz1101: rtc_data_out = {3'b100, rtc_bank};
			5'bz1110: rtc_data_out = 4'h0;
			5'bz1111: rtc_data_out = 4'hc;
			5'b1zzzz: rtc_data_out = rtc_bank1[mbus_a[4:1]];
			default: rtc_data_out = 4'hf;
		endcase
		if (!rtc_present)
			rtc_data_out = 4'hf;
	end
	wire [7:0] b2c_in = (rtc[10:8] == 3'd0 ? rtc[7:0] - 80 : (rtc[10:8] == 3'd1 ? rtc[7:0] + 1 : (rtc[10:8] == 3'd2 ? {3'd0, rtc[4:0]} : rtc[7:0])));
	reg [7:0] bcd;
	always @(*) begin : sv2v_autoblock_2
		integer i;
		bcd = 8'h00;
		for (i = 7; i >= 0; i = i - 1)
			begin
				if (bcd[3:0] >= 5)
					bcd[3:0] = bcd[3:0] + 4'd3;
				bcd = {bcd[6:0], b2c_in[i]};
			end
	end
	reg rtc_old_flg = 1'b0;
	reg [31:0] rtc_cnt;
	always @(posedge clk_32) begin
		rtc_old_flg <= rtc[11];
		if (rtc_old_flg ^ rtc[11]) begin
			rtc_present <= 1'b1;
			if (rtc[10:8] == 3'd0)
				{rtc_reg_B, rtc_reg_A} <= bcd;
			if (rtc[10:8] == 3'd1)
				{rtc_reg_9, rtc_reg_8} <= bcd;
			if (rtc[10:8] == 3'd2)
				{rtc_reg_7, rtc_reg_6} <= bcd;
			if (rtc[10:8] == 3'd3)
				{rtc_reg_5, rtc_reg_4} <= bcd;
			if (rtc[10:8] == 3'd4)
				{rtc_reg_3, rtc_reg_2} <= bcd;
			if (rtc[10:8] == 3'd5)
				{rtc_reg_1, rtc_reg_0} <= bcd;
			if (rtc[10:8] == 3'd2)
				rtc_reg_C <= {1'b0, rtc[7:5]};
		end
		else if (rtc_cnt < 32'd32000000)
			rtc_cnt <= rtc_cnt + 32'd1;
		else begin
			rtc_cnt <= 32'd0;
			if (rtc_reg_0 < 9)
				rtc_reg_0 <= rtc_reg_0 + 4'd1;
			else begin
				rtc_reg_0 <= 4'h0;
				if (rtc_reg_1 < 5)
					rtc_reg_1 <= rtc_reg_1 + 4'd1;
				else begin
					rtc_reg_1 <= 4'h0;
					if (rtc_reg_2 < 9)
						rtc_reg_2 <= rtc_reg_2 + 4'd1;
					else begin
						rtc_reg_2 <= 4'h0;
						if (rtc_reg_2 < 5)
							rtc_reg_2 <= rtc_reg_2 + 4'd1;
						else begin
							rtc_reg_2 <= 4'h0;
							if (rtc_reg_3 < 9)
								rtc_reg_3 <= rtc_reg_3 + 4'd1;
							else begin
								rtc_reg_3 <= 4'h0;
								if (rtc_reg_4 < 5)
									rtc_reg_4 <= rtc_reg_4 + 4'd1;
								else
									rtc_reg_4 <= 4'h0;
							end
						end
					end
				end
			end
		end
	end
	always @(posedge clk_32)
		if (peripheral_reset)
			rtc_bank <= 0;
		else if (!(rtccs_n | rtcwr_n)) begin
			if (mbus_a[4:1] == 4'hd)
				rtc_bank <= cpu_dout[0];
			else
				rtc_bank1[mbus_a[4:1]] <= cpu_dout[3:0];
		end
	assign leds[1:0] = floppy_sel ^ 2'b11;
	wire fdc_drq;
	wire [1:0] fdc_addr;
	wire fdc_sel;
	wire fdc_rw;
	wire [7:0] fdc_din;
	wire [7:0] fdc_dout;
	wire dma_write;
	wire dma_read;
	dma dma(
		.clk(clk_32),
		.clk_en(mhz8_en1),
		.reset(reset),
		.cpu_din(mbus_dout),
		.cpu_sel(~fcs_n),
		.cpu_a1(mbus_a[1]),
		.cpu_rw(rw),
		.cpu_dout(dma_data_out),
		.img_mounted(sd_img_mounted[3:2]),
		.img_size(sd_img_size),
		.acsi_rd_req(acsi_rd_req),
		.acsi_wr_req(acsi_wr_req),
		.acsi_lba(acsi_sd_lba),
		.sd_done(acsi_sd_done),
		.sd_busy(acsi_sd_busy),
		.sd_rd_byte_strobe(acsi_sd_rd_byte_strobe),
		.sd_rd_byte(acsi_sd_rd_byte),
		.sd_wr_byte(acsi_sd_wr_byte),
		.sd_byte_addr(acsi_sd_byte_addr),
		.acsi_irq(acsi_irq),
		.fdc_drq(fdc_drq),
		.fdc_addr(fdc_addr),
		.fdc_sel(fdc_sel),
		.fdc_rw(fdc_rw),
		.fdc_din(fdc_din),
		.fdc_dout(fdc_dout),
		.rdy_i(rdy_i),
		.rdy_o(rdy_o),
		.ram_din(shifter_dout),
		.hdd_leds(leds[3:2])
	);
	wire [1:0] floppy_sel_exclusive = (floppy_sel == 2'b00 ? 2'b10 : floppy_sel);
	fdc1772 fdc1772(
		.clkcpu(clk_32),
		.clk8m_en(mhz8_en1),
		.floppy_drive(floppy_sel_exclusive),
		.floppy_side(floppy_side),
		.floppy_reset(~peripheral_reset),
		.floppy_step(),
		.floppy_motor(1'b0),
		.irq(fdc_irq),
		.drq(fdc_drq),
		.cpu_addr(fdc_addr),
		.cpu_sel(fdc_sel),
		.cpu_rw(fdc_rw),
		.cpu_din(fdc_din),
		.cpu_dout(fdc_dout),
		.img_ds(1'b0),
		.img_type(3'd1),
		.img_wp(floppy_protected),
		.img_mounted(sd_img_mounted[1:0]),
		.img_size(sd_img_size[31:0]),
		.sd_lba(sd_lba),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_ack(sd_ack),
		.sd_buff_addr(sd_buff_addr),
		.sd_dout(sd_dout),
		.sd_din(sd_din),
		.sd_dout_strobe(sd_dout_strobe)
	);
	wire [7:0] cubase2_dout;
	wire cubase3_d8;
	reg cubase_sel;
	wire [7:0] cubase_dout = (cubase_sel ? cubase2_dout : {7'h7f, cubase3_d8});
	assign cart_data_out = {(cubase_en ? cubase_dout : 8'hff), 8'hff};
	reg cubase_lock;
	always @(posedge clk_32)
		if (peripheral_reset) begin
			cubase_sel <= 0;
			cubase_lock <= 0;
		end
		else if ((cubase_en & !cart_n) & !cubase_lock) begin
			cubase_sel <= |mbus_a[7:1];
			cubase_lock <= 1;
		end
	cubase2_dongle cubase2_dongle(
		.clk(clk_32),
		.reset(peripheral_reset),
		.uds_n(uds_n),
		.A(mbus_a[8:1]),
		.D(cubase2_dout)
	);
	cubase3_dongle cubase3_dongle(
		.clk(clk_32),
		.reset(peripheral_reset),
		.rom3_n(cart_n),
		.a8(mbus_a[8]),
		.d8(cubase3_d8)
	);
endmodule
