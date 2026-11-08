module fdc1772 (
	clkcpu,
	clk8m_en,
	floppy_drive,
	floppy_side,
	floppy_reset,
	floppy_step,
	floppy_motor,
	floppy_ready,
	irq,
	drq,
	cpu_addr,
	cpu_sel,
	cpu_rw,
	cpu_din,
	cpu_dout,
	img_type,
	img_mounted,
	img_wp,
	img_ds,
	img_size,
	sd_lba,
	sd_rd,
	sd_wr,
	sd_ack,
	sd_buff_addr,
	sd_dout,
	sd_din,
	sd_dout_strobe
);
	input clkcpu;
	input clk8m_en;
	parameter FD_NUM = 2;
	localparam W = FD_NUM - 1;
	input [W:0] floppy_drive;
	input floppy_side;
	input floppy_reset;
	output wire floppy_step;
	input floppy_motor;
	output wire floppy_ready;
	output reg irq;
	output reg drq;
	input [1:0] cpu_addr;
	input cpu_sel;
	input cpu_rw;
	input [7:0] cpu_din;
	output reg [7:0] cpu_dout;
	input [2:0] img_type;
	input [W:0] img_mounted;
	input [W:0] img_wp;
	input img_ds;
	input [31:0] img_size;
	output reg [31:0] sd_lba;
	output reg [W:0] sd_rd;
	output reg [W:0] sd_wr;
	input sd_ack;
	input [8:0] sd_buff_addr;
	input [7:0] sd_dout;
	output wire [7:0] sd_din;
	input sd_dout_strobe;
	parameter CLK_EN = 16'd8000;
	parameter MODEL = 2;
	parameter EXT_MOTOR = 1'b0;
	parameter INVERT_HEAD_RA = 1'b0;
	localparam IMG_ARCHIE = 0;
	localparam IMG_ST = 1;
	localparam IMG_BBC = 2;
	localparam IMG_TI99 = 3;
	localparam IMG_BETA = 4;
	localparam IMG_PLUSD_IMG = 5;
	localparam WIDX = (FD_NUM > 2 ? 2 : 1);
	reg [5:0] fdn_spt [0:FD_NUM - 1];
	reg [9:0] fdn_gap_len [0:FD_NUM - 1];
	reg fdn_doubleside [0:FD_NUM - 1];
	reg fdn_hd [0:FD_NUM - 1];
	reg fdn_ed [0:FD_NUM - 1];
	reg fdn_fm [0:FD_NUM - 1];
	reg fdn_present [0:FD_NUM - 1];
	reg [1:0] fdn_sector_size_code [0:FD_NUM - 1];
	reg fdn_sector_base [0:FD_NUM - 1];
	reg [2:0] fdn_type [0:FD_NUM - 1];
	reg [12:0] image_sectors;
	reg [12:0] image_sps;
	reg [5:0] image_spt;
	reg [9:0] image_gap_len;
	reg image_doubleside;
	wire image_hd = img_size[20];
	wire image_ed = img_size[21];
	reg image_fm;
	reg [1:0] image_sector_size_code;
	reg image_sector_base;
	always @(*) begin
		image_sps = 0;
		case (img_type)
			IMG_ARCHIE: begin
				image_sector_size_code = 2'd3;
				image_sector_base = 0;
				image_fm = 0;
				image_sectors = img_size[22:10];
				image_doubleside = 1'b1;
				image_spt = (image_hd ? 6'd10 : 6'd5);
				image_gap_len = 10'd220;
			end
			IMG_ST, IMG_PLUSD_IMG: begin
				image_sector_size_code = 2'd2;
				image_sector_base = 1;
				image_fm = 0;
				image_sectors = img_size[21:9];
				image_doubleside = 1'b0;
				image_sps = image_sectors;
				if (image_sectors > 1020) begin
					image_doubleside = 1'b1;
					image_sps = image_sectors >> 1'b1;
				end
				if (image_ed)
					image_sps = image_sps >> 2'd2;
				else if (image_hd)
					image_sps = image_sps >> 1'd1;
				case (image_sps)
					711, 720, 729, 738, 747, 756, 765: image_spt = 6'd9;
					790, 800, 810, 820, 830, 840, 850: image_spt = 6'd10;
					948, 960, 972, 984, 996, 1008, 1020: image_spt = 6'd12;
					default: image_spt = 6'd11;
				endcase
				if (image_ed)
					image_spt = image_spt << 2'd2;
				else if (image_hd)
					image_spt = image_spt << 2'd1;
				case (image_spt)
					6'd9, 6'd18, 6'd36: image_gap_len = 10'd176;
					6'd10, 6'd20, 6'd40: image_gap_len = 10'd107;
					6'd11, 6'd22, 6'd44: image_gap_len = 10'd50;
					default: image_gap_len = 10'd2;
				endcase
			end
			IMG_BBC, IMG_TI99, IMG_BETA: begin
				image_sector_size_code = 2'd1;
				image_sector_base = 0;
				image_fm = 1;
				if (img_type == IMG_BBC)
					image_spt = 10;
				else if (img_type == IMG_TI99)
					image_spt = 9;
				else begin
					image_sector_base = 1;
					image_spt = 16;
					image_fm = 0;
				end
				image_sectors = img_size[19:8];
				image_doubleside = img_ds;
				image_gap_len = 10'd50;
			end
			default: begin
				image_sector_size_code = 2'd0;
				image_sector_base = 0;
				image_fm = 0;
				image_sectors = 0;
				image_doubleside = 0;
				image_spt = 0;
				image_gap_len = 0;
			end
		endcase
	end
	reg [WIDX:0] fdn;
	wire fd_doubleside = fdn_doubleside[fdn];
	wire [5:0] fd_spt = fdn_spt[fdn];
	wire [2:0] fd_type = fdn_type[fdn];
	reg s_odd;
	reg [7:0] sector;
	reg [7:0] track;
	always @(*)
		case (fd_type)
			IMG_ARCHIE: sd_lba = {(((16'd0 + (fd_spt * track[6:0])) << fd_doubleside) + (floppy_side ? 5'd0 : fd_spt)) + sector[5:0], s_odd};
			IMG_ST: sd_lba = ((((fd_spt * track[6:0]) << fd_doubleside) + (floppy_side ? 6'd0 : fd_spt)) + sector[5:0]) - 1'd1;
			IMG_PLUSD_IMG: sd_lba = (((floppy_side ? 16'd0 : 16'd800) + (fd_spt * track[6:0])) + sector[5:0]) - 1'd1;
			IMG_BBC: sd_lba = ((((fd_spt * track[6:0]) << fd_doubleside) + (floppy_side ? 5'd0 : fd_spt)) + sector[5:0]) >> 1;
			IMG_TI99: sd_lba = ((fd_spt * (floppy_side ? track[5:0] : 79 - track[5:0])) + sector[5:0]) >> 1;
			IMG_BETA: sd_lba = (((((fd_spt * track[6:0]) << fd_doubleside) + (floppy_side ? 5'd0 : fd_spt)) + sector[5:0]) - 1'd1) >> 1;
			default: sd_lba = 0;
		endcase
	always @(posedge clkcpu) begin : sv2v_autoblock_1
		integer i;
		for (i = 0; i < FD_NUM; i = i + 1'd1)
			if (img_mounted[i]) begin
				fdn_present[i] <= |img_size;
				fdn_sector_size_code[i] <= image_sector_size_code;
				fdn_spt[i] <= image_spt;
				fdn_gap_len[i] <= image_gap_len;
				fdn_doubleside[i] <= image_doubleside;
				fdn_hd[i] <= image_hd;
				fdn_ed[i] <= image_ed;
				fdn_fm[i] <= image_fm;
				fdn_sector_base[i] <= image_sector_base;
				fdn_type[i] <= img_type;
			end
	end
	reg cpu_selD;
	reg cpu_rwD;
	always @(posedge clkcpu) begin
		cpu_rwD <= cpu_sel & ~cpu_rw;
		cpu_selD <= cpu_sel;
	end
	wire cpu_we = (cpu_sel & ~cpu_rw) & ~cpu_rwD;
	reg irq_set;
	reg cpu_rw_cmdstatus;
	localparam FDC_REG_CMDSTATUS = 0;
	always @(posedge clkcpu) cpu_rw_cmdstatus <= (~cpu_selD && cpu_sel) && (cpu_addr == FDC_REG_CMDSTATUS);
	wire irq_clr = !floppy_reset || cpu_rw_cmdstatus;
	always @(posedge clkcpu)
		if (irq_clr)
			irq <= 1'b0;
		else if (irq_set)
			irq <= 1'b1;
	reg drq_set;
	reg cpu_rw_data;
	localparam FDC_REG_DATA = 3;
	always @(posedge clkcpu) cpu_rw_data <= (~cpu_selD && cpu_sel) && (cpu_addr == FDC_REG_DATA);
	wire drq_clr = !floppy_reset || cpu_rw_data;
	always @(posedge clkcpu)
		if (drq_clr)
			drq <= 1'b0;
		else if (drq_set)
			drq <= 1'b1;
	always begin : sv2v_autoblock_2
		integer i;
		fdn = 0;
		for (i = FD_NUM - 1; i >= 0; i = i - 1)
			if (!floppy_drive[i])
				fdn = i[WIDX:0];
	end
	wire fd_any = ~&floppy_drive;
	wire fdn_index [0:FD_NUM - 1];
	wire fd_index = (fd_any ? fdn_index[fdn] : 1'b0);
	wire fdn_ready [0:FD_NUM - 1];
	wire fd_ready = (fd_any ? fdn_ready[fdn] : 1'b0);
	wire [6:0] fdn_track [0:FD_NUM - 1];
	wire [6:0] fd_track = (fd_any ? fdn_track[fdn] : 7'd0);
	wire [5:0] fdn_sector [0:FD_NUM - 1];
	wire [5:0] fd_sector = (fd_any ? fdn_sector[fdn] : 5'd0);
	wire fdn_sector_hdr [0:FD_NUM - 1];
	wire fd_sector_hdr = (fd_any ? fdn_sector_hdr[fdn] : 1'b0);
	wire fdn_sector_data [0:FD_NUM - 1];
	wire fd_sector_data = (fd_any ? fdn_sector_data[fdn] : 1'b0);
	wire fdn_dclk [0:FD_NUM - 1];
	wire fd_dclk_en = (fd_any ? fdn_dclk[fdn] : 1'b0);
	wire fd_present = (fd_any ? fdn_present[fdn] : 1'b0);
	wire fd_writeprot = (fd_any ? img_wp[fdn] : 1'b1);
	wire [1:0] fd_sector_size_code = fdn_sector_size_code[fdn];
	wire [10:0] fd_sector_size = 11'd128 << fdn_sector_size_code[fdn];
	wire fd_sector_base = fdn_sector_base[fdn];
	assign floppy_ready = fd_ready && fd_present;
	wire fd_motor;
	reg step_in;
	reg step_out;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < FD_NUM; _gv_i_1 = _gv_i_1 + 1) begin : fdd
			localparam i = _gv_i_1;
			floppy #(.CLK_EN(CLK_EN)) floppy(
				.clk(clkcpu),
				.clk8m_en(clk8m_en),
				.select(fd_any && (fdn == i)),
				.motor_on(fd_motor),
				.step_in(step_in),
				.step_out(step_out),
				.inserted(fdn_present[i]),
				.sector_size_code(fdn_sector_size_code[i]),
				.spt(fdn_spt[i]),
				.sector_gap_len(fdn_gap_len[i]),
				.sector_base(fdn_sector_base[i]),
				.hd(fdn_hd[i]),
				.ed(fdn_ed[i]),
				.fm(fdn_fm[i]),
				.dclk_en(fdn_dclk[i]),
				.track(fdn_track[i]),
				.sector(fdn_sector[i]),
				.sector_hdr(fdn_sector_hdr[i]),
				.sector_data(fdn_sector_data[i]),
				.ready(fdn_ready[i]),
				.index(fdn_index[i])
			);
		end
	endgenerate
	localparam MOTOR_IDLE_COUNTER = 4'd10;
	reg [3:0] motor_timeout_index;
	reg indexD;
	reg busy;
	reg [3:0] motor_spin_up_sequence;
	reg motor_on = 1'b0;
	assign fd_motor = (EXT_MOTOR ? floppy_motor : motor_on);
	wire motor_spin_up_done = !motor_on || (motor_on && (motor_spin_up_sequence == 0));
	localparam STEP_PULSE_LEN = 16'd1;
	localparam STEP_PULSE_CLKS = STEP_PULSE_LEN * CLK_EN;
	reg [15:0] step_pulse_cnt;
	reg [7:0] cmd;
	wire [19:0] step_rate_clk = (cmd[1:0] == 2'b00 ? (16'd6 * CLK_EN) - 1'd1 : (cmd[1:0] == 2'b01 ? (16'd12 * CLK_EN) - 1'd1 : ((MODEL == 2) && (cmd[1:0] == 2'b10) ? (16'd2 * CLK_EN) - 1'd1 : (cmd[1:0] == 2'b10 ? (16'd20 * CLK_EN) - 1'd1 : (MODEL == 2 ? (16'd3 * CLK_EN) - 1'd1 : (16'd30 * CLK_EN) - 1'd1)))));
	reg [19:0] step_rate_cnt;
	reg [23:0] delay_cnt;
	assign floppy_step = step_in | step_out;
	wire step_busy = step_rate_cnt != 0;
	wire delaying = delay_cnt != 0;
	wire fd_track0 = fd_track == 0;
	reg [7:0] step_to;
	reg RNF;
	reg sector_inc_strobe;
	reg track_inc_strobe;
	reg track_dec_strobe;
	reg track_clear_strobe;
	localparam SD_IDLE = 0;
	reg cmd_rx;
	wire cmd_type_1 = cmd[7] == 1'b0;
	wire cmd_type_2 = cmd[7:6] == 2'b10;
	wire cmd_type_3 = (cmd[7:5] == 3'b111) || (cmd[7:4] == 4'b1100);
	wire cmd_type_4 = cmd[7:4] == 4'b1101;
	reg data_transfer_done;
	reg data_transfer_start;
	reg [10:0] fifo_cpuptr;
	reg sd_card_read;
	reg sd_card_write;
	reg [2:0] sd_state;
	reg step_dir;
	always @(posedge clkcpu) begin : sv2v_autoblock_3
		reg [1:0] seek_state;
		reg notready_wait;
		reg sector_not_found;
		reg irq_at_index;
		reg [1:0] data_transfer_state;
		reg fd_sector_hdrD;
		sector_inc_strobe <= 1'b0;
		track_inc_strobe <= 1'b0;
		track_dec_strobe <= 1'b0;
		track_clear_strobe <= 1'b0;
		irq_set <= 1'b0;
		if (!floppy_reset) begin
			motor_on <= 1'b0;
			busy <= 1'b0;
			step_in <= 1'b0;
			step_out <= 1'b0;
			sd_card_read <= 0;
			sd_card_write <= 0;
			data_transfer_start <= 1'b0;
			seek_state <= 0;
			notready_wait <= 1'b0;
			sector_not_found <= 1'b0;
			irq_at_index <= 1'b0;
			data_transfer_state <= 2'b00;
			RNF <= 1'b0;
			fd_sector_hdrD <= 1'b0;
		end
		else if (clk8m_en) begin
			sd_card_read <= 0;
			sd_card_write <= 0;
			data_transfer_start <= 1'b0;
			fd_sector_hdrD <= fd_sector_hdr;
			if (step_pulse_cnt != 0)
				step_pulse_cnt <= step_pulse_cnt - 16'd1;
			else begin
				step_in <= 1'b0;
				step_out <= 1'b0;
			end
			if (step_rate_cnt != 0)
				step_rate_cnt <= step_rate_cnt - 16'd1;
			if (delay_cnt != 0)
				delay_cnt <= delay_cnt - 1'd1;
			if (cmd_rx) begin
				busy <= 1'b1;
				notready_wait <= 1'b0;
				sector_not_found <= 1'b0;
				data_transfer_state <= 2'b00;
				if ((cmd_type_1 || cmd_type_2) || cmd_type_3) begin
					RNF <= 1'b0;
					motor_on <= 1'b1;
					if (!motor_on && !cmd[3])
						motor_spin_up_sequence <= 6;
				end
				if (cmd_type_4) begin
					busy <= 1'b0;
					if (cmd[3])
						irq_set <= 1'b1;
					if (cmd[3:2] == 2'b01)
						irq_at_index <= 1'b1;
					if (!busy)
						motor_on <= 1'b1;
				end
			end
			if (((busy && motor_spin_up_done) && !step_busy) && !delaying) begin
				if (cmd_type_1) begin
					if (!fd_present) begin
						if (!notready_wait) begin
							delay_cnt <= 16'd6 * CLK_EN;
							notready_wait <= 1'b1;
						end
						else begin
							RNF <= 1'b1;
							busy <= 1'b0;
							irq_set <= 1'b1;
						end
					end
					else
						case (seek_state)
							0: begin
								if (cmd[7:4] == 4'b0000) begin
									if (fd_track0) begin
										track_clear_strobe <= 1'b1;
										seek_state <= 2;
									end
									else begin
										step_dir <= 1'b1;
										seek_state <= 1;
									end
								end
								if (cmd[7:4] == 4'b0001) begin
									if (track == step_to)
										seek_state <= 2;
									else begin
										step_dir <= step_to < track;
										seek_state <= 1;
									end
								end
								if (cmd[7:5] == 3'b001)
									seek_state <= 1;
								if (cmd[7:5] == 3'b010) begin
									step_dir <= 1'b0;
									seek_state <= 1;
								end
								if (cmd[7:5] == 3'b011) begin
									step_dir <= 1'b1;
									seek_state <= 1;
								end
							end
							1: begin
								if (step_dir)
									step_in <= 1'b1;
								else
									step_out <= 1'b1;
								if ((!cmd[6] && !cmd[5]) || ((cmd[6] || cmd[5]) && cmd[4])) begin
									if (step_dir)
										track_dec_strobe <= 1'b1;
									else
										track_inc_strobe <= 1'b1;
								end
								step_pulse_cnt <= STEP_PULSE_CLKS - 1'd1;
								step_rate_cnt <= step_rate_clk;
								seek_state <= (!cmd[6] && !cmd[5] ? 0 : 2);
							end
							2: begin
								if (cmd[2])
									delay_cnt <= 16'd3 * CLK_EN;
								seek_state <= 3;
							end
							3: begin
								busy <= 1'b0;
								irq_set <= 1'b1;
								seek_state <= 0;
							end
						endcase
				end
				if (cmd_type_2) begin
					if (!fd_present) begin
						if (!notready_wait) begin
							delay_cnt <= 16'd6 * CLK_EN;
							notready_wait <= 1'b1;
						end
						else begin
							RNF <= 1'b1;
							busy <= 1'b0;
							irq_set <= 1'b1;
						end
					end
					else if (sector_not_found) begin
						busy <= 1'b0;
						irq_set <= 1'b1;
						RNF <= 1'b1;
					end
					else if (cmd[2] && !notready_wait) begin
						delay_cnt <= 16'd15 * CLK_EN;
						notready_wait <= 1'b1;
					end
					else begin
						if (cmd[7:5] == 3'b100) begin
							if ((sector - fd_sector_base) >= fd_spt) begin
								sector_not_found <= 1'b1;
								delay_cnt <= 24'd1000 * CLK_EN;
							end
							else if (sd_state == SD_IDLE)
								case (data_transfer_state)
									2'b00:
										if (fifo_cpuptr == 0) begin
											sd_card_read <= 1;
											data_transfer_state <= 2'b01;
										end
									2'b01: begin
										if (((fd_ready && fd_sector_hdrD) && !fd_sector_hdr) && (fd_sector == sector))
											data_transfer_start <= 1'b1;
										if (data_transfer_done) begin
											data_transfer_state <= 2'b00;
											if (cmd[4])
												sector_inc_strobe <= 1'b1;
											else begin
												busy <= 1'b0;
												irq_set <= 1'b1;
											end
										end
									end
									default:
										;
								endcase
						end
						if (cmd[7:5] == 3'b101) begin
							if (fd_writeprot) begin
								busy <= 1'b0;
								irq_set <= 1'b1;
							end
							else if ((sector - fd_sector_base) >= fd_spt) begin
								sector_not_found <= 1'b1;
								delay_cnt <= 24'd1000 * CLK_EN;
							end
							else if (sd_state == SD_IDLE)
								case (data_transfer_state)
									2'b00: begin
										if (fd_sector_size_code < 2)
											sd_card_read <= 1;
										data_transfer_state <= 2'b10;
									end
									2'b10: begin
										if (((((fifo_cpuptr == 0) && fd_ready) && fd_sector_hdrD) && !fd_sector_hdr) && (fd_sector == sector))
											data_transfer_start <= 1'b1;
										if (data_transfer_done) begin
											sd_card_write <= 1;
											data_transfer_state <= 2'b11;
										end
									end
									2'b11: begin
										data_transfer_state <= 2'b00;
										if (cmd[4])
											sector_inc_strobe <= 1'b1;
										else begin
											busy <= 1'b0;
											irq_set <= 1'b1;
										end
									end
									default:
										;
								endcase
						end
					end
				end
				if (cmd_type_3) begin
					if (!fd_present) begin
						RNF <= 1'b1;
						busy <= 1'b0;
						irq_set <= 1'b1;
					end
					else begin
						if (cmd[7:4] == 4'b1110) begin
							busy <= 1'b0;
							irq_set <= 1'b1;
						end
						if (cmd[7:4] == 4'b1111) begin
							busy <= 1'b0;
							irq_set <= 1'b1;
						end
						if (cmd[7:4] == 4'b1100) begin
							if ((fd_ready && !fd_sector_hdrD) && fd_sector_hdr)
								data_transfer_start <= 1'b1;
							if (data_transfer_done) begin
								busy <= 1'b0;
								irq_set <= 1'b1;
							end
						end
					end
				end
			end
			indexD <= fd_index;
			if (indexD && !fd_index) begin
				irq_at_index <= 1'b0;
				if (irq_at_index)
					irq_set <= 1'b1;
				if (!busy && motor_spin_up_done) begin
					if (motor_timeout_index != 0)
						motor_timeout_index <= motor_timeout_index - 4'd1;
					else if (motor_on)
						motor_timeout_index <= MOTOR_IDLE_COUNTER;
					if (motor_timeout_index == 1)
						motor_on <= 1'b0;
				end
				if (motor_spin_up_sequence != 0)
					motor_spin_up_sequence <= motor_spin_up_sequence - 4'd1;
			end
			if (busy)
				motor_timeout_index <= 0;
		end
	end
	reg [9:0] fifo_cpuptr_adj;
	wire [7:0] fifo_q;
	reg [9:0] fifo_sdptr;
	always @(*) begin
		if (fd_sector_size_code == 3)
			fifo_sdptr = {s_odd, sd_buff_addr};
		else
			fifo_sdptr = {1'b0, sd_buff_addr};
		if (fd_sector_size_code == 1)
			fifo_cpuptr_adj = {1'b0, ((fd_spt[0] & (track[0] ^ !floppy_side)) ^ sector[0]) ^ fd_sector_base, fifo_cpuptr[7:0]};
		else
			fifo_cpuptr_adj = fifo_cpuptr[9:0];
	end
	reg data_in_strobe;
	reg [7:0] data_in;
	fdc_dpram fifo(
		.clka(clkcpu),
		.reseta(1'b0),
		.cea(1'b1),
		.ada(fifo_sdptr),
		.wrea(sd_dout_strobe & sd_ack),
		.dina(sd_dout),
		.ocea(1'b1),
		.douta(sd_din),
		.clkb(clkcpu),
		.resetb(1'b0),
		.ceb(1'b1),
		.adb(fifo_cpuptr_adj),
		.wreb(data_in_strobe),
		.dinb(data_in),
		.oceb(1'b1),
		.doutb(fifo_q)
	);
	localparam SD_READ_WAIT = 1;
	localparam SD_WRITE_WAIT = 2;
	localparam SD_READ = 3;
	localparam SD_WRITE = 4;
	always @(posedge clkcpu) begin : sv2v_autoblock_4
		reg sd_ackD;
		reg sd_card_readD;
		reg sd_card_writeD;
		sd_card_readD <= sd_card_read;
		sd_card_writeD <= sd_card_write;
		sd_ackD <= sd_ack;
		if (sd_ack)
			{sd_rd, sd_wr} <= 0;
		case (sd_state)
			SD_IDLE: begin
				s_odd <= 1'b0;
				if (~sd_card_readD & sd_card_read)
					sd_state <= SD_READ_WAIT;
				else if (~sd_card_writeD & sd_card_write)
					sd_state <= SD_WRITE_WAIT;
			end
			SD_READ_WAIT:
				if (!sd_ack) begin
					sd_rd[fdn] <= 1;
					sd_state <= SD_READ;
				end
			SD_READ:
				if (sd_ackD & ~sd_ack) begin
					if (s_odd || (fd_sector_size_code != 3))
						sd_state <= SD_IDLE;
					else begin
						s_odd <= 1;
						sd_rd[fdn] <= 1;
					end
				end
			SD_WRITE_WAIT:
				if (!sd_ack) begin
					sd_wr[fdn] <= 1;
					sd_state <= SD_WRITE;
				end
			SD_WRITE:
				if (sd_ackD & ~sd_ack) begin
					if (s_odd || (fd_sector_size_code != 3))
						sd_state <= SD_IDLE;
					else begin
						s_odd <= 1;
						sd_wr[fdn] <= 1;
					end
				end
			default:
				;
		endcase
	end
	reg data_in_valid;
	function [15:0] crc;
		input [15:0] curcrc;
		input [7:0] val;
		reg [3:0] i;
		begin
			crc = {curcrc[15:8] ^ val, 8'h00};
			for (i = 0; i < 8; i = i + 1'd1)
				if (crc[15]) begin
					crc = crc << 1;
					crc = crc ^ 16'h1021;
				end
				else
					crc = crc << 1;
			crc = {curcrc[7:0] ^ crc[15:8], crc[7:0]};
		end
	endfunction
	reg data_lost;
	reg [7:0] data_out;
	always @(posedge clkcpu) begin : sv2v_autoblock_5
		reg data_transfer_startD;
		reg [10:0] data_transfer_cnt;
		reg [15:0] crcval;
		reg crc_en;
		crc_en <= 0;
		if (crc_en)
			crcval <= crc(crcval, data_out);
		if (cpu_we && (cpu_addr == FDC_REG_DATA)) begin
			data_out <= data_in;
			data_in_valid <= 1;
		end
		if (cmd_rx || sector_inc_strobe) begin
			data_in_valid <= 0;
			data_transfer_cnt <= 0;
			fifo_cpuptr <= 0;
		end
		drq_set <= 1'b0;
		if (clk8m_en)
			data_transfer_done <= 0;
		data_transfer_startD <= data_transfer_start;
		if (~data_transfer_startD & data_transfer_start) begin
			if (cmd[7:4] == 4'b1100) begin
				crcval <= 16'hb230;
				data_transfer_cnt <= 11'd6 + 11'd1;
			end
			if (cmd[7:6] == 2'b10)
				data_transfer_cnt <= fd_sector_size + 1'd1;
			if (cmd[7:5] == 3'b101)
				drq_set <= !data_in_valid;
		end
		data_in_strobe <= 1'b0;
		if ((cmd[7:5] == 3'b101) && data_in_strobe)
			fifo_cpuptr <= fifo_cpuptr + 1'd1;
		if (fd_dclk_en) begin
			if (data_transfer_cnt != 0) begin
				if (data_transfer_cnt != 1) begin
					data_lost <= 1'b0;
					if (drq)
						data_lost <= 1'b1;
					if ((cmd[7:5] != 3'b101) || (data_transfer_cnt != 2))
						drq_set <= 1'b1;
					if (cmd[7:4] == 4'b1100)
						case (data_transfer_cnt)
							7: begin
								data_out <= fd_track;
								crc_en <= 1;
							end
							6: begin
								data_out <= {7'b0000000, (INVERT_HEAD_RA != 0) ^ floppy_side};
								crc_en <= 1;
							end
							5: begin
								data_out <= fd_sector;
								crc_en <= 1;
							end
							4: begin
								data_out <= fd_sector_size_code[1:0];
								crc_en <= 1;
							end
							3: data_out <= crcval[15:8];
							2: data_out <= crcval[7:0];
						endcase
					if ((cmd[7:5] == 3'b100) && (fifo_cpuptr != fd_sector_size)) begin
						data_out <= fifo_q;
						fifo_cpuptr <= fifo_cpuptr + 1'd1;
					end
					if ((cmd[7:5] == 3'b101) && (fifo_cpuptr != fd_sector_size)) begin
						data_in_strobe <= 1;
						data_in_valid <= 0;
					end
				end
				data_transfer_cnt <= data_transfer_cnt - 11'd1;
				if (data_transfer_cnt == 1)
					data_transfer_done <= 1'b1;
			end
		end
	end
	wire [7:0] status = {((MODEL == 1) || (MODEL == 3) ? !floppy_ready : motor_on), (((cmd[7:5] == 3'b101) || (cmd[7:4] == 4'b1111)) || cmd_type_1) && fd_writeprot, (cmd_type_1 ? motor_spin_up_done : 1'b0), RNF, 1'b0, (cmd_type_1 | cmd_type_4 ? fd_track0 : data_lost), (cmd_type_1 | cmd_type_4 ? ~fd_index : drq), busy};
	localparam FDC_REG_TRACK = 1;
	localparam FDC_REG_SECTOR = 2;
	always @(*) begin
		cpu_dout = 8'h00;
		if (cpu_sel && cpu_rw)
			case (cpu_addr)
				FDC_REG_CMDSTATUS: cpu_dout = status;
				FDC_REG_TRACK: cpu_dout = track;
				FDC_REG_SECTOR: cpu_dout = sector;
				FDC_REG_DATA: cpu_dout = data_out;
			endcase
	end
	reg cmd_rx_i;
	always @(posedge clkcpu)
		if (!floppy_reset) begin
			cmd <= 8'h00;
			track <= 8'h00;
			sector <= 8'h00;
			cmd_rx_i <= 1'b0;
			cmd_rx <= 1'b0;
		end
		else begin
			cmd_rx <= cmd_rx_i;
			if ((!cmd_type_4 && busy) || ((clk8m_en && cmd_type_4) && !busy))
				cmd_rx_i <= 1'b0;
			if (cpu_we) begin
				if (cpu_addr == FDC_REG_CMDSTATUS) begin
					cmd <= cpu_din;
					cmd_rx_i <= 1'b1;
					if (cpu_din[7:4] == 4'b0000) begin
						step_to <= 8'd0;
						track <= 8'hff;
					end
					if (cpu_din[7:4] == 4'b0001)
						step_to <= data_in;
					if (cpu_din[7:5] == 3'b001)
						;
					if (cpu_din[7:5] == 3'b010)
						;
					if (cpu_din[7:5] == 3'b011)
						;
					if (cpu_din[7:5] == 3'b100)
						;
					if (cpu_din[7:5] == 3'b101)
						;
					if (cpu_din[7:4] == 4'b1100)
						;
					if (cpu_din[7:4] == 4'b1110)
						;
					if (cpu_din[7:4] == 4'b1111)
						;
					if (cpu_din[7:4] == 4'b1101)
						;
				end
				if (cpu_addr == FDC_REG_TRACK)
					track <= cpu_din;
				if (cpu_addr == FDC_REG_SECTOR)
					sector <= cpu_din;
				if (cpu_addr == FDC_REG_DATA)
					data_in <= cpu_din;
			end
			if (sector_inc_strobe)
				sector <= sector + 1'd1;
			if (track_inc_strobe)
				track <= track + 1'd1;
			if (track_dec_strobe)
				track <= track - 1'd1;
			if (track_clear_strobe)
				track <= 8'd0;
		end
endmodule
