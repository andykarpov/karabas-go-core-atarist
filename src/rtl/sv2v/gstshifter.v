module gstshifter (
	clk32,
	ste,
	resb,
	CS,
	A,
	DIN,
	DOUT,
	LATCH,
	RDAT_N,
	WDAT_N,
	RW,
	MDIN,
	MDOUT,
	MONO_OUT,
	LOAD_N,
	DE,
	BLANK_N,
	R,
	G,
	B,
	SLOAD_N,
	SREQ,
	audio_left,
	audio_right
);
	input clk32;
	input ste;
	input resb;
	input CS;
	input [6:1] A;
	input [15:0] DIN;
	output wire [15:0] DOUT;
	input LATCH;
	input RDAT_N;
	input WDAT_N;
	input RW;
	input [15:0] MDIN;
	output wire [15:0] MDOUT;
	output wire MONO_OUT;
	input LOAD_N;
	input DE;
	input BLANK_N;
	output reg [3:0] R;
	output reg [3:0] G;
	output reg [3:0] B;
	input SLOAD_N;
	output wire SREQ;
	output reg [7:0] audio_left;
	output reg [7:0] audio_right;
	reg [15:0] s_dout;
	wire [15:0] mbus_in = (CS ? s_dout : MDIN);
	mlatch #(.WIDTH(16)) dout_l(
		.clock(clk32),
		.s(1'b0),
		.r(1'b0),
		.g(LATCH),
		.d(mbus_in),
		.q(DOUT)
	);
	mlatch #(.WIDTH(16)) mdout_l(
		.clock(clk32),
		.s(1'b0),
		.r(1'b0),
		.g(!WDAT_N),
		.d(DIN),
		.q(MDOUT)
	);
	parameter DEFAULT_MODE = 2'd0;
	reg [1:0] shmode;
	wire mono = shmode == 2'd2;
	assign MONO_OUT = mono;
	wire mid = shmode == 2'd1;
	wire low = shmode == 2'd0;
	reg [3:0] palette_r [15:0];
	reg [3:0] palette_g [15:0];
	reg [3:0] palette_b [15:0];
	reg monocolor;
	reg [3:0] pixel_offset;
	reg [15:0] mw_data_reg;
	reg [15:0] mw_mask_reg;
	reg [2:0] sndmode;
	always @(*) begin
		s_dout = 16'h0000;
		if (CS && RW) begin
			if (ste) begin
				if (A == 6'h32)
					s_dout = {12'h000, pixel_offset};
			end
			if (A[6:5] == 2'b10) begin
				s_dout[3:0] = palette_b[A[4:1]];
				s_dout[7:4] = palette_g[A[4:1]];
				s_dout[11:8] = palette_r[A[4:1]];
				if (!ste) begin
					s_dout[3] = 1'b0;
					s_dout[7] = 1'b0;
					s_dout[11] = 1'b0;
				end
			end
			if (A == 6'h30)
				s_dout = {6'h00, shmode, 8'h00};
			if (ste) begin
				if (A == 6'h10)
					s_dout[7:0] = {sndmode[2], 5'd0, sndmode[1:0]};
				if (A == 6'h11)
					s_dout = mw_data_reg;
				if (A == 6'h12)
					s_dout = mw_mask_reg;
			end
		end
	end
	reg CS_d;
	wire write = (CS_d & ~CS) & ~RW;
	always @(posedge clk32) CS_d <= CS;
	always @(posedge clk32) begin : sv2v_autoblock_1
		reg [1:0] shmode_d;
		if (!resb) begin
			shmode_d <= DEFAULT_MODE;
			pixel_offset <= 4'h0;
			monocolor <= 1'b1;
		end
		else begin
			shmode <= shmode_d;
			if (write) begin
				if (ste) begin
					if (A == 6'h10)
						sndmode <= {MDOUT[7], MDOUT[1:0]};
					if (A == 6'h32)
						pixel_offset <= MDOUT[3:0];
				end
				if (A == 6'h30)
					shmode_d <= MDOUT[9:8];
			end
			if (CS & ~RW) begin
				if (A[6:5] == 2'b10) begin
					if (A[4:1] == 4'h0)
						monocolor <= MDOUT[0];
					if (!ste) begin
						palette_r[A[4:1]] <= {1'b0, MDOUT[10:8]};
						palette_g[A[4:1]] <= {1'b0, MDOUT[6:4]};
						palette_b[A[4:1]] <= {1'b0, MDOUT[2:0]};
					end
					else begin
						palette_r[A[4:1]] <= MDOUT[11:8];
						palette_g[A[4:1]] <= MDOUT[7:4];
						palette_b[A[4:1]] <= MDOUT[3:0];
					end
				end
			end
		end
	end
	reg [1:0] t;
	always @(posedge clk32 or negedge resb)
		if (!resb)
			t <= 2'b01;
		else
			t <= t + 1'd1;
	wire pclk_en = (mono ? 1'b1 : (mid ? ~t[0] : (low ? t == 2'b01 : 1'b0)));
	wire reload;
	wire [3:0] color_index;
	shifter_video shifter_video(
		.clk32(clk32),
		.nReset(resb),
		.pixClkEn(pclk_en),
		.DE(DE),
		.LOAD(LOAD_N),
		.rez(shmode),
		.monocolor(~monocolor),
		.scroll(|pixel_offset),
		.DIN(MDIN),
		.Reload(reload),
		.color_index(color_index)
	);
	wire [3:0] shifted_color_index;
	wire [3:0] mono_rgb = {4 {shifted_color_index[0] ^ monocolor}};
	reg [3:0] color_addr;
	reg [3:0] color_addr_d;
	reg [3:0] color_addr_d2;
	reg [3:0] color_r_pal;
	wire [3:0] color_r = {color_r_pal[2:0], color_r_pal[3]};
	reg [3:0] color_g_pal;
	wire [3:0] color_g = {color_g_pal[2:0], color_g_pal[3]};
	reg [3:0] color_b_pal;
	wire [3:0] color_b = {color_b_pal[2:0], color_b_pal[3]};
	wire [3:0] stvid_r = (mono ? mono_rgb : color_r);
	wire [3:0] stvid_g = (mono ? mono_rgb : color_g);
	wire [3:0] stvid_b = (mono ? mono_rgb : color_b);
	always @(posedge clk32)
		if (resb) begin
			if (pclk_en) begin
				color_addr <= (mid ? {2'b00, shifted_color_index[1:0]} : shifted_color_index);
				color_addr_d <= color_addr;
				color_addr_d2 <= color_addr_d;
				color_r_pal <= palette_r[color_addr_d2];
				color_g_pal <= palette_g[color_addr_d2];
				color_b_pal <= palette_b[color_addr_d2];
				R <= (BLANK_N | mono ? stvid_r : 4'b0000);
				G <= (BLANK_N | mono ? stvid_g : 4'b0000);
				B <= (BLANK_N | mono ? stvid_b : 4'b0000);
			end
		end
	reg [14:0] ste_shifted_0;
	reg [14:0] ste_shifted_1;
	reg [14:0] ste_shifted_2;
	reg [14:0] ste_shifted_3;
	reg [5:0] pix_cntr;
	reg pix_cntr_en;
	always @(posedge clk32)
		if (pclk_en) begin
			ste_shifted_0 <= {color_index[0], ste_shifted_0[14:1]};
			ste_shifted_1 <= {color_index[1], ste_shifted_1[14:1]};
			ste_shifted_2 <= {color_index[2], ste_shifted_2[14:1]};
			ste_shifted_3 <= {color_index[3], ste_shifted_3[14:1]};
			if (((pix_cntr == 6'h00) && !DE) || ((pix_cntr == 6'h0f) && DE))
				pix_cntr_en <= 1'b0;
			else if (pix_cntr_en) begin
				if (DE)
					pix_cntr <= pix_cntr + 1'd1;
				else
					pix_cntr <= pix_cntr - 1'd1;
			end
			if (((pix_cntr == 6'h00) && DE) && reload)
				pix_cntr_en <= 1'b1;
			if (((pix_cntr == 6'h0f) && !DE) && reload) begin
				pix_cntr_en <= 1'b1;
				if (mid)
					pix_cntr <= 6'h1f;
				if (mono)
					pix_cntr <= 6'h3f;
			end
		end
	assign shifted_color_index[0] = (pixel_offset == 4'd0 ? color_index[0] : (((pix_cntr == 6'h0f) && DE) || ((pix_cntr != 6'h00) && !DE) ? ste_shifted_0[pixel_offset - 1'd1] : 1'b0));
	assign shifted_color_index[1] = (pixel_offset == 4'd0 ? color_index[1] : (((pix_cntr == 6'h0f) && DE) || ((pix_cntr != 6'h00) && !DE) ? ste_shifted_1[pixel_offset - 1'd1] : 1'b0));
	assign shifted_color_index[2] = (pixel_offset == 4'd0 ? color_index[2] : (((pix_cntr == 6'h0f) && DE) || ((pix_cntr != 6'h00) && !DE) ? ste_shifted_2[pixel_offset - 1'd1] : 1'b0));
	assign shifted_color_index[3] = (pixel_offset == 4'd0 ? color_index[3] : (((pix_cntr == 6'h0f) && DE) || ((pix_cntr != 6'h00) && !DE) ? ste_shifted_3[pixel_offset - 1'd1] : 1'b0));
	wire clk_8_en = t == 0;
	reg [15:0] mw_data_in;
	reg [6:0] mw_cnt;
	reg mw_clk;
	reg mw_data;
	reg mw_done;
	reg mw_data_write;
	reg mw_mask_write;
	always @(posedge clk32)
		if (!resb)
			mw_cnt <= 7'h00;
		else begin
			if (clk_8_en) begin
				if (mw_data_write || (mw_cnt != 0)) begin
					if (mw_cnt != 0)
						mw_cnt <= mw_cnt - 7'd1;
					if (mw_data_write) begin
						mw_data_reg <= {mw_data_in[14:0], 1'b0};
						mw_data <= mw_data_in[15];
						mw_cnt <= 7'h7f;
					end
					else if (mw_cnt[2:0] == 3'b000) begin
						mw_data_reg <= {mw_data_reg[14:0], 1'b0};
						mw_data <= mw_data_reg[15];
					end
					if (mw_data_write || (mw_cnt[2:0] == 3'b000)) begin
						mw_mask_reg <= {mw_mask_reg[14:0], mw_mask_reg[15]};
						mw_clk <= mw_mask_reg[15];
					end
					mw_done <= mw_cnt == 7'h01;
				end
				if (mw_mask_write) begin
					mw_mask_reg <= mw_data_in;
					mw_cnt <= 0;
				end
				mw_data_write <= 0;
				mw_mask_write <= 0;
			end
			if (write) begin
				mw_data_in <= MDOUT;
				mw_data_write <= A == 6'h11;
				mw_mask_write <= A == 6'h12;
			end
		end
	reg a2base;
	reg [9:0] a2base_cnt;
	reg a2base_en;
	always @(posedge clk32) begin
		a2base_cnt <= a2base_cnt + 1'd1;
		if (a2base_cnt == 639)
			a2base_cnt <= 0;
		a2base_en <= a2base_cnt == 0;
	end
	reg [2:0] aclk_cnt;
	always @(posedge clk32)
		if (a2base_en)
			aclk_cnt <= aclk_cnt + 3'd1;
	reg aclk_en;
	always @(posedge clk32) aclk_en <= a2base_en & (sndmode[1:0] == 2'b11 ? a2base_en : (sndmode[1:0] == 2'b10 ? aclk_cnt[0] == 0 : (sndmode[1:0] == 2'b01 ? aclk_cnt[1:0] == 0 : aclk_cnt == 0)));
	localparam FIFO_ADDR_BITS = 3;
	localparam FIFO_DEPTH = 8;
	reg [15:0] fifo [7:0];
	reg [2:0] writeP;
	reg [2:0] readP;
	wire fifo_empty = readP == writeP;
	wire fifo_full = readP == (writeP + 2'd1);
	assign SREQ = !fifo_full;
	reg bytesel;
	wire [15:0] fifo_out = fifo[readP];
	wire [7:0] mono_byte = (!bytesel ? fifo_out[15:8] : fifo_out[7:0]);
	always @(posedge clk32)
		if (!resb)
			readP <= 0;
		else if (aclk_en) begin
			if (!fifo_empty) begin
				if (!sndmode[2]) begin
					audio_left <= fifo_out[15:8] + 8'd128;
					audio_right <= fifo_out[7:0] + 8'd128;
				end
				else begin
					audio_left <= mono_byte + 8'd128;
					audio_right <= mono_byte + 8'd128;
					bytesel <= !bytesel;
				end
				if (!sndmode[2] || bytesel)
					readP <= readP + 1'd1;
			end
		end
	always @(posedge clk32) begin : sv2v_autoblock_2
		reg sload_d;
		if (!resb)
			writeP <= 0;
		else begin
			sload_d <= SLOAD_N;
			if (~sload_d & SLOAD_N) begin
				fifo[writeP] <= MDIN;
				writeP <= writeP + 1'd1;
			end
		end
	end
endmodule
