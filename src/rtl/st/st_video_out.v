`timescale 1ns / 1ps
`default_nettype wire

/*
 st_video_out.v

 The output timing of the doubled Atari ST picture at 32 MHz (the timing table of hdmi.sv of
 MiSTeryNano): a free running counter that restarts at vreset, the point of the ST frame that
 video_analyzer gives for the top left pixel of the window, so the picture of the scandoubler sits
 in it. Syncs active high (hs, vs; the top inverts them for HDMI), de the window, rgb black outside.

   mode    total       window     h sync (start after window, length)   v sync
   PAL     1024 x 626  720 x 576  24, 72                                5, 5     31.25 kHz, 49.9 Hz
   NTSC    1016 x 526  720 x 480  16, 62                                9, 6     31.50 kHz, 59.9 Hz
   mono     896 x 501  640 x 400  24, 72                                5, 5     35.71 kHz, 71.3 Hz
*/

module st_video_out (
	input wire clk,
	input wire [1:0] vmode,     // 0 NTSC, 1 PAL, 2 mono
	input wire vreset,
	input wire [5:0] r,
	input wire [5:0] g,
	input wire [5:0] b,
	output reg [23:0] rgb = 24'd0,
	output reg hs = 1'b0,
	output reg vs = 1'b0,
	output reg de = 1'b0
);

reg [10:0] h_total, h_win, h_ss, h_sl;
reg [9:0] v_total, v_win, v_ss, v_sl;
always @(*) begin
	case (vmode)
	2'd0: begin h_total = 11'd1016; h_win = 11'd720; h_ss = 11'd16; h_sl = 11'd62;
	            v_total = 10'd526;  v_win = 10'd480; v_ss = 10'd9;  v_sl = 10'd6; end
	2'd1: begin h_total = 11'd1024; h_win = 11'd720; h_ss = 11'd24; h_sl = 11'd72;
	            v_total = 10'd626;  v_win = 10'd576; v_ss = 10'd5;  v_sl = 10'd5; end
	default: begin h_total = 11'd896; h_win = 11'd640; h_ss = 11'd24; h_sl = 11'd72;
	            v_total = 10'd501;  v_win = 10'd400; v_ss = 10'd5;  v_sl = 10'd5; end
	endcase
end

reg [10:0] cx = 11'd0;
reg [9:0] cy = 10'd0;

always @(posedge clk) begin
	if (vreset) begin
		cx <= 11'd0;
		cy <= 10'd0;
	end
	else if (cx >= h_total - 11'd1) begin
		cx <= 11'd0;
		cy <= (cy >= v_total - 10'd1) ? 10'd0 : cy + 10'd1;
	end
	else
		cx <= cx + 11'd1;

	de <= cx < h_win && cy < v_win;
	rgb <= (cx < h_win && cy < v_win) ? { r, r[5:4], g, g[5:4], b, b[5:4] } : 24'd0;
	hs <= cx >= h_win + h_ss && cx < h_win + h_ss + h_sl;
	vs <= cy >= v_win + v_ss && cy < v_win + v_ss + v_sl;
end

endmodule
