module dma (
	clk,
	clk_en,
	reset,
	cpu_din,
	cpu_sel,
	cpu_a1,
	cpu_rw,
	cpu_dout,
	img_mounted,
	img_size,
	acsi_rd_req,
	acsi_wr_req,
	acsi_lba,
	sd_busy,
	sd_done,
	sd_rd_byte_strobe,
	sd_rd_byte,
	sd_wr_byte,
	sd_byte_addr,
	acsi_irq,
	fdc_sel,
	fdc_addr,
	fdc_rw,
	fdc_din,
	fdc_dout,
	fdc_drq,
	rdy_i,
	rdy_o,
	ram_din,
	hdd_leds
);
	input clk;
	input clk_en;
	input reset;
	input [15:0] cpu_din;
	input cpu_sel;
	input cpu_a1;
	input cpu_rw;
	output reg [15:0] cpu_dout;
	input [1:0] img_mounted;
	input [63:0] img_size;
	output wire [1:0] acsi_rd_req;
	output reg [1:0] acsi_wr_req;
	output wire [31:0] acsi_lba;
	input sd_busy;
	input sd_done;
	input sd_rd_byte_strobe;
	input [7:0] sd_rd_byte;
	output wire [7:0] sd_wr_byte;
	input [8:0] sd_byte_addr;
	output wire acsi_irq;
	output wire fdc_sel;
	output wire [1:0] fdc_addr;
	output wire fdc_rw;
	output wire [7:0] fdc_din;
	input [7:0] fdc_dout;
	input fdc_drq;
	input rdy_i;
	output wire rdy_o;
	input [15:0] ram_din;
	output wire [1:0] hdd_leds;
	reg cpu_rdy;
	reg fifo_read_in_progress;
	reg fifo_write_in_progress;
	wire ram_br = fifo_read_in_progress || fifo_write_in_progress;
	assign rdy_o = (cpu_sel ? cpu_rdy : ram_br);
	reg cpu_selD;
	always @(posedge clk)
		if (clk_en)
			cpu_selD <= cpu_sel;
	wire cpu_req = ~cpu_selD & cpu_sel;
	always @(posedge clk)
		if (!cpu_sel)
			cpu_rdy <= 1'b0;
		else if (clk_en && cpu_req)
			cpu_rdy <= 1'b1;
	reg [7:0] dma_scnt;
	reg [15:0] dma_mode;
	reg fdc_dma_sel;
	assign fdc_sel = fdc_dma_sel | ((cpu_sel && !cpu_a1) && (dma_mode[4:3] == 2'b00));
	reg fdc_bs;
	reg [15:0] fifo_data_out;
	assign fdc_din = (fdc_dma_sel ? (fdc_bs ? fifo_data_out[7:0] : fifo_data_out[15:8]) : cpu_din[7:0]);
	reg dma_direction_out;
	wire fdc_dma_rw = ~dma_direction_out;
	assign fdc_rw = (fdc_dma_sel ? fdc_dma_rw : cpu_rw);
	assign fdc_addr = (fdc_dma_sel ? 2'b11 : dma_mode[2:1]);
	reg [15:0] fdc_fifo_in;
	reg fdc_fifo_strobe;
	reg cpu_dma_mode_direction_toggle;
	wire fifo_reset = cpu_dma_mode_direction_toggle;
	always @(posedge clk) begin : sv2v_autoblock_1
		reg fdc_drqD;
		reg fdc_state;
		if (reset | fifo_reset) begin
			fdc_fifo_strobe <= 1'b0;
			fdc_state <= 1'b0;
			fdc_bs <= 1'b0;
			fdc_dma_sel <= 1'b0;
		end
		else begin
			fdc_drqD <= fdc_drq;
			fdc_fifo_strobe <= 1'b0;
			case (fdc_state)
				0:
					if (~fdc_drqD & fdc_drq) begin
						fdc_dma_sel <= 1'b1;
						fdc_state <= 1'b1;
					end
				1:
					if (clk_en) begin
						fdc_dma_sel <= 1'b0;
						fdc_bs <= ~fdc_bs;
						if (fdc_bs) begin
							fdc_fifo_in[7:0] <= fdc_dout;
							fdc_fifo_strobe <= 1'b1;
						end
						else
							fdc_fifo_in[15:8] <= fdc_dout;
						fdc_state <= 1'b0;
					end
			endcase
		end
	end
	reg buf_wr_pend;
	reg [8:0] buf_wr_addr;
	reg [7:0] buf_wr_data;
	wire [15:0] acsi_length;
	reg [2:0] acsi_io_state;
	reg [127:0] acsi_image_size;
	wire acsi_inserted_0 = acsi_image_size[64+:64] != 0;
	wire acsi_inserted_1 = acsi_image_size[0+:64] != 0;
	wire [7:0] acsi_enable = {6'b000000, acsi_inserted_1, acsi_inserted_0};
	wire [15:0] acsi_reply_data;
	wire acsi_reply_req;
	reg acsi_read_strobe;
	reg [3:0] fifo_rptr;
	reg [3:0] fifo_wptr;
	wire [3:0] fifo_fill = fifo_wptr - fifo_rptr;
	reg rdy_iD;
	wire ram_access_strobe = ~rdy_iD & rdy_i;
	wire fifo_data_in_strobe = (dma_direction_out ? ram_access_strobe : (fdc_fifo_strobe || acsi_read_strobe) || (acsi_reply_req && (fifo_fill < 8)));
	wire acsi_reply_ack = fifo_data_in_strobe;
	always @(posedge clk) begin
		if (img_mounted[0])
			acsi_image_size[64+:64] <= img_size;
		if (img_mounted[1])
			acsi_image_size[0+:64] <= img_size;
	end
	wire buf_sd_we = (acsi_io_state == 3'd1) && sd_rd_byte_strobe;
	wire buf_we = buf_sd_we || buf_wr_pend;
	wire [8:0] buf_waddr = (buf_sd_we ? sd_byte_addr : buf_wr_addr);
	wire [7:0] buf_wdata = (buf_sd_we ? sd_rd_byte : buf_wr_data);
	wire [15:0] acsi_read_data;
	kg_sdpram #(
		.DW(8),
		.AW(9)
	) buffer_sd(
		.clka(clk),
		.wea(buf_we),
		.addra(buf_waddr),
		.dina(buf_wdata),
		.clkb(clk),
		.enb(acsi_io_state == 3'd7),
		.addrb(sd_byte_addr),
		.doutb(sd_wr_byte)
	);
	reg [8:0] acsi_io_counter;
	kg_sdpram #(
		.DW(8),
		.AW(9)
	) buffer_hi(
		.clka(clk),
		.wea(buf_we),
		.addra(buf_waddr),
		.dina(buf_wdata),
		.clkb(clk),
		.enb((acsi_io_state == 3'd2) && !acsi_io_counter[0]),
		.addrb(acsi_io_counter),
		.doutb(acsi_read_data[15:8])
	);
	kg_sdpram #(
		.DW(8),
		.AW(9)
	) buffer_lo(
		.clka(clk),
		.wea(buf_we),
		.addra(buf_waddr),
		.dina(buf_wdata),
		.clkb(clk),
		.enb((acsi_io_state == 3'd2) && acsi_io_counter[0]),
		.addrb(acsi_io_counter),
		.doutb(acsi_read_data[7:0])
	);
	wire acsi_reg_sel = (cpu_sel && !cpu_a1) && (dma_mode[4:3] == 2'b01);
	wire [7:0] acsi_dout;
	reg acsi_write_strobe;
	reg acsi_dma_done;
	reg acsi_request_next;
	wire [1:0] acsi_wr_req_int;
	localparam [2:0] IDLE = 3'd0;
	localparam [2:0] READ_WAIT4SD = 3'd1;
	localparam [2:0] READING = 3'd2;
	localparam [2:0] READ_WAIT4DMA = 3'd3;
	localparam [2:0] READ_CHECK_NEXT = 3'd4;
	localparam [2:0] WRITING = 3'd5;
	localparam [2:0] WRITE_START_SD = 3'd6;
	localparam [2:0] WRITE_WAIT4SD = 3'd7;
	wire acsi_is_reading = (acsi_io_state >= READ_WAIT4SD) && (acsi_io_state <= READ_CHECK_NEXT);
	wire acsi_is_writing = (acsi_io_state >= WRITING) && (acsi_io_state <= WRITE_WAIT4SD);
	wire fifo_is_full = fifo_fill == 15;
	reg sector_strobe;
	always @(posedge clk)
		if (reset) begin
			acsi_io_state <= IDLE;
			acsi_read_strobe <= 1'b0;
			acsi_write_strobe <= 1'b0;
			acsi_dma_done <= 1'b0;
			acsi_request_next <= 1'b0;
			acsi_wr_req <= 2'b00;
			buf_wr_pend <= 1'b0;
		end
		else begin
			acsi_read_strobe <= 1'b0;
			acsi_write_strobe <= 1'b0;
			acsi_dma_done <= 1'b0;
			acsi_request_next <= 1'b0;
			buf_wr_pend <= 1'b0;
			case (acsi_io_state)
				IDLE: begin
					if (acsi_rd_req)
						acsi_io_state <= READ_WAIT4SD;
					if (acsi_wr_req_int) begin
						acsi_io_state <= WRITING;
						acsi_io_counter <= 9'd0;
					end
				end
				WRITING:
					if (!acsi_io_counter[0]) begin
						if ((!acsi_io_counter[3:0] && (fifo_fill == 8)) || (acsi_io_counter[3:0] && fifo_fill)) begin
							buf_wr_pend <= 1'b1;
							buf_wr_addr <= acsi_io_counter;
							buf_wr_data <= fifo_data_out[15:8];
							acsi_io_counter <= acsi_io_counter + 9'd1;
							acsi_write_strobe <= 1'b1;
						end
					end
					else if (!acsi_write_strobe) begin
						buf_wr_pend <= 1'b1;
						buf_wr_addr <= acsi_io_counter;
						buf_wr_data <= fifo_data_out[7:0];
						acsi_io_counter <= acsi_io_counter + 9'd1;
						if (acsi_io_counter == 9'd511) begin
							acsi_io_state <= WRITE_START_SD;
							acsi_wr_req <= acsi_wr_req_int;
						end
					end
				WRITE_START_SD:
					if (sd_busy) begin
						acsi_io_state <= WRITE_WAIT4SD;
						acsi_wr_req <= 2'b00;
					end
				WRITE_WAIT4SD:
					if (sd_done) begin
						if ((dma_scnt != 0) && (acsi_length > 1))
							acsi_request_next <= 1'b1;
						else
							acsi_dma_done <= 1'b1;
						acsi_io_state <= IDLE;
					end
				READ_WAIT4SD:
					if (sd_done) begin
						acsi_io_state <= READING;
						acsi_io_counter <= 9'd0;
					end
				READING:
					if (!acsi_io_counter[0])
						acsi_io_counter <= acsi_io_counter + 9'd1;
					else if (!fifo_is_full) begin
						acsi_read_strobe <= 1'b1;
						acsi_io_counter <= acsi_io_counter + 9'd1;
						if (acsi_io_counter == 9'd511)
							acsi_io_state <= READ_WAIT4DMA;
					end
				READ_WAIT4DMA:
					if (sector_strobe)
						acsi_io_state <= READ_CHECK_NEXT;
				READ_CHECK_NEXT: begin
					if ((dma_scnt != 0) && (acsi_length > 1))
						acsi_request_next <= 1'b1;
					else
						acsi_dma_done <= 1'b1;
					acsi_io_state <= IDLE;
				end
			endcase
		end
	acsi acsi(
		.clk(clk),
		.clk_en(clk_en),
		.reset(reset),
		.dma_done(acsi_dma_done),
		.irq(acsi_irq),
		.enable(acsi_enable),
		.img_size(acsi_image_size),
		.data_rd_req(acsi_rd_req),
		.data_wr_req(acsi_wr_req_int),
		.data_lba(acsi_lba),
		.data_length(acsi_length),
		.data_busy(sd_busy),
		.data_done(sd_done),
		.data_next(acsi_request_next),
		.reply_data(acsi_reply_data),
		.reply_req(acsi_reply_req),
		.reply_ack(acsi_reply_ack),
		.cpu_sel(acsi_reg_sel),
		.cpu_a1(dma_mode[1]),
		.cpu_rw(cpu_rw),
		.cpu_din(cpu_din[7:0]),
		.cpu_dout(acsi_dout),
		.leds(hdd_leds)
	);
	wire [15:0] ram_dout;
	always @(cpu_sel or cpu_rw or cpu_a1 or dma_mode or dma_scnt or fdc_dout or acsi_dout or ram_dout) begin
		cpu_dout = ram_dout;
		if (cpu_sel && cpu_rw) begin
			if (!cpu_a1) begin
				if (dma_mode[4] == 1'b0) begin
					if (dma_mode[3] == 1'b0)
						cpu_dout = {8'h00, fdc_dout};
					else
						cpu_dout = {8'h00, acsi_dout};
				end
				else
					cpu_dout = {8'h00, dma_scnt};
			end
			if (cpu_a1)
				cpu_dout = {14'd0, dma_scnt != 0, 1'b1};
		end
	end
	reg cpu_scnt_write_strobe;
	always @(posedge clk)
		if (reset) begin
			cpu_scnt_write_strobe <= 1'b0;
			cpu_dma_mode_direction_toggle <= 1'b0;
		end
		else begin
			cpu_scnt_write_strobe <= 1'b0;
			cpu_dma_mode_direction_toggle <= 1'b0;
			if ((clk_en && cpu_req) && !cpu_rw) begin
				if (!cpu_a1 && (dma_mode[4] == 1'b1))
					cpu_scnt_write_strobe <= 1'b1;
				if (cpu_a1) begin
					dma_mode <= cpu_din;
					if (dma_mode[8] != cpu_din[8])
						cpu_dma_mode_direction_toggle <= 1'b1;
				end
			end
		end
	reg [15:0] fifo [15:0];
	always @(posedge clk) rdy_iD <= rdy_i;
	reg dma_in_progress;
	wire fifo_write_start = ((dma_in_progress && dma_direction_out) && !fifo_write_in_progress) && ((fifo_wptr - fifo_rptr) < 4'd8);
	wire fifo_write_stop = (dma_direction_out && fifo_write_in_progress) && (ram_access_strobe && ((fifo_wptr == 4'd7) || (fifo_wptr == 4'd15)));
	always @(posedge clk or posedge fifo_reset)
		if (fifo_reset == 1'b1)
			fifo_write_in_progress <= 1'b0;
		else if (fifo_write_start)
			fifo_write_in_progress <= 1'b1;
		else if (fifo_write_stop)
			fifo_write_in_progress <= 1'b0;
	wire [15:0] fifo_data_in = (dma_direction_out ? ram_din : (fdc_fifo_strobe ? fdc_fifo_in : (acsi_is_reading ? acsi_read_data : acsi_reply_data)));
	always @(posedge clk or posedge fifo_reset)
		if (fifo_reset == 1'b1)
			fifo_wptr <= 4'd0;
		else if (fifo_data_in_strobe) begin
			fifo[fifo_wptr] <= fifo_data_in;
			fifo_wptr <= fifo_wptr + 1'd1;
		end
	wire fifo_full_8 = fifo_fill >= 8;
	wire fifo_read_start = ((dma_in_progress && !dma_direction_out) && !fifo_read_in_progress) && fifo_full_8;
	wire fifo_read_stop = ((!dma_direction_out && fifo_read_in_progress) && ram_access_strobe) && ((fifo_rptr == 4'd7) || (fifo_rptr == 4'd15));
	always @(posedge clk or posedge fifo_reset)
		if (fifo_reset == 1'b1)
			fifo_read_in_progress <= 1'b0;
		else if (fifo_read_start)
			fifo_read_in_progress <= 1'b1;
		else if (fifo_read_stop)
			fifo_read_in_progress <= 1'b0;
	wire fifo_data_out_strobe = (acsi_is_writing ? acsi_write_strobe : (dma_direction_out ? fdc_fifo_strobe : ram_access_strobe));
	always @(posedge clk) fifo_data_out <= fifo[fifo_rptr];
	always @(posedge clk or posedge fifo_reset)
		if (fifo_reset == 1'b1)
			fifo_rptr <= 4'd0;
		else if (fifo_data_out_strobe)
			fifo_rptr <= fifo_rptr + 1'd1;
	assign ram_dout = fifo_data_out;
	reg [7:0] word_out_cnt;
	reg sector_done;
	reg sector_strobe_prepare;
	wire dma_scnt_write_strobe = cpu_scnt_write_strobe || sector_strobe;
	always @(posedge clk)
		if (dma_scnt_write_strobe) begin
			word_out_cnt <= 8'd0;
			sector_strobe <= 1'b0;
			sector_done <= 1'b0;
		end
		else begin
			sector_strobe <= 1'b0;
			if (sector_done) begin
				sector_done <= 1'b0;
				sector_strobe <= 1'b1;
			end
			if (ram_access_strobe) begin
				word_out_cnt <= word_out_cnt + 8'd1;
				if (word_out_cnt == 8'd255)
					sector_done <= 1'b1;
			end
		end
	wire [7:0] dma_scnt_dec = (dma_scnt != 0 ? dma_scnt - 8'd1 : 8'd0);
	wire [7:0] dma_scnt_next = (cpu_scnt_write_strobe ? cpu_din[7:0] : dma_scnt_dec);
	always @(posedge clk)
		if (dma_scnt_write_strobe)
			dma_scnt <= dma_scnt_next;
	wire dma_stop = cpu_dma_mode_direction_toggle;
	wire cpu_starts_dma = (cpu_scnt_write_strobe && (cpu_din[7:0] != 0)) && !dma_mode[6];
	always @(posedge clk or posedge dma_stop)
		if (dma_stop)
			dma_in_progress <= 1'b0;
		else if (dma_scnt_write_strobe)
			dma_in_progress <= cpu_starts_dma || (sector_strobe && (dma_scnt_next != 0));
	always @(posedge clk)
		if (cpu_dma_mode_direction_toggle)
			dma_direction_out <= cpu_din[8];
endmodule
