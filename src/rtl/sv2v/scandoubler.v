module scandoubler (
	clk_sys,
	bypass,
	ce_divider,
	pixel_ena,
	scanlines,
	hs_in,
	vs_in,
	r_in,
	g_in,
	b_in,
	hs_out,
	vs_out,
	r_out,
	g_out,
	b_out
);
	input clk_sys;
	input bypass;
	input ce_divider;
	output wire pixel_ena;
	input [1:0] scanlines;
	input hs_in;
	input vs_in;
	input [3:0] r_in;
	input [3:0] g_in;
	input [3:0] b_in;
	output reg hs_out;
	output reg vs_out;
	output reg [5:0] r_out;
	output reg [5:0] g_out;
	output reg [5:0] b_out;
	parameter HCNT_WIDTH = 9;
	reg [1:0] i_div;
	reg ce_x1;
	reg ce_x2;
	always @(posedge clk_sys) begin : sv2v_autoblock_1
		reg last_hs_in;
		last_hs_in <= hs_in;
		if (last_hs_in & !hs_in)
			i_div <= 2'b00;
		else
			i_div <= i_div + 2'd1;
	end
	always @(*)
		if (!ce_divider) begin
			ce_x1 = i_div == 2'b01;
			ce_x2 = i_div[0];
		end
		else begin
			ce_x1 = i_div[0];
			ce_x2 = 1'b1;
		end
	assign pixel_ena = (bypass ? ce_x1 : ce_x2);
	reg scanline;
	reg [3:0] r;
	reg [3:0] g;
	reg [3:0] b;
	reg [11:0] sd_buffer_out;
	reg [11:0] sd_bypass_out;
	wire [11:0] sd_out = (bypass ? sd_bypass_out : sd_buffer_out);
	always @(*) begin
		b = sd_out[3:0];
		g = sd_out[7:4];
		r = sd_out[11:8];
	end
	reg hs_sd;
	reg vs_sd;
	always @(posedge clk_sys)
		if (bypass) begin
			r_out <= {r, 2'b00};
			g_out <= {g, 2'b00};
			b_out <= {b, 2'b00};
			hs_out <= hs_sd;
			vs_out <= vs_sd;
		end
		else if (ce_x2) begin
			hs_out <= hs_sd;
			vs_out <= vs_sd;
			if (vs_out != vs_in)
				scanline <= 0;
			if (hs_out && !hs_sd)
				scanline <= !scanline;
			if (!scanline || !scanlines) begin
				r_out <= {r, 2'b00};
				g_out <= {g, 2'b00};
				b_out <= {b, 2'b00};
			end
			else
				case (scanlines)
					1: begin
						r_out <= {1'b0, r, 1'b0} + {2'b00, r};
						g_out <= {1'b0, g, 1'b0} + {2'b00, g};
						b_out <= {1'b0, b, 1'b0} + {2'b00, b};
					end
					2: begin
						r_out <= {1'b0, r, 1'b0};
						g_out <= {1'b0, g, 1'b0};
						b_out <= {1'b0, b, 1'b0};
					end
					3: begin
						r_out <= {2'b00, r};
						g_out <= {2'b00, g};
						b_out <= {2'b00, b};
					end
				endcase
		end
	(* ramstyle = "no_rw_check" *) reg [11:0] sd_buffer [0:(2 * (2 ** HCNT_WIDTH)) - 1];
	reg line_toggle;
	reg [HCNT_WIDTH - 1:0] hs_max;
	reg [HCNT_WIDTH - 1:0] hs_rise;
	reg [HCNT_WIDTH - 1:0] hcnt;
	always @(posedge clk_sys) begin : sv2v_autoblock_2
		reg hsD;
		reg vsD;
		if (ce_x1) begin
			hsD <= hs_in;
			if (hsD && !hs_in) begin
				hs_max <= hcnt;
				hcnt <= 0;
			end
			else
				hcnt <= hcnt + 1'd1;
			if (!hsD && hs_in)
				hs_rise <= hcnt;
			vsD <= vs_in;
			if (vsD != vs_in)
				line_toggle <= 0;
			if (hsD && !hs_in)
				line_toggle <= !line_toggle;
			sd_buffer[{line_toggle, hcnt}] <= {r_in, g_in, b_in};
		end
	end
	reg [HCNT_WIDTH - 1:0] sd_hcnt;
	always @(posedge clk_sys) begin : sv2v_autoblock_3
		reg hsD;
		if (ce_x2) begin
			hsD <= hs_in;
			sd_hcnt <= sd_hcnt + 1'd1;
			if (hsD && !hs_in)
				sd_hcnt <= hs_max;
			if (sd_hcnt == hs_max)
				sd_hcnt <= 0;
			if (sd_hcnt == hs_max)
				hs_sd <= 0;
			if (sd_hcnt == hs_rise)
				hs_sd <= 1;
			sd_buffer_out <= sd_buffer[{~line_toggle, sd_hcnt}];
			vs_sd <= vs_in;
		end
		if (bypass) begin
			sd_bypass_out <= {r_in, g_in, b_in};
			hs_sd <= hs_in;
			vs_sd <= vs_in;
		end
	end
endmodule
