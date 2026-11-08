`timescale 1ns / 1ps
`default_nettype wire

/*
 st_hid.v

 The USB devices of the mcu link (kg_mcu: the keyboard report, mouse deltas, two joysticks) as
 the inputs of the Atari ST machine of MiSTeryNano (atarist.v): the IKBD keyboard matrix, the
 mouse on port 0 and the joysticks on port 1 (and on port 0 while the mouse rests).

 Keyboard: the report (KB_STATUS = modifiers, KB_DAT0..5 = USB HID usage codes) is scanned
 serially, one item per clock through ONE keymap (atarist_keymap.v of MiSTeryNano): items 0..5 the
 key codes, 6..13 the modifier bits as the codes 68..6F of the keymap. A scan builds the matrix
 (15 columns x 8 rows, 0 = pressed) and the matrix is taken at its end, every 14 clocks.
 matrix_in is the AND of the columns that the IKBD selects (matrix_out low), as in MiSTeryNano.
 F12 (45, not on the ST keyboard) is reset (held).

 Mouse: the deltas of each report are added to two counters; every 2^15 clocks (1 ms) a counter
 that is not 0 moves its 2-bit Gray code one step towards 0, as the light barriers of the ST mouse
 (hid.v of MiSTeryNano). Buttons: left, right.

 Joysticks: kg_mcu JOY: [1] up, [2] down, [3] left, [4] right, [6] A, [7] B. atarist joy0 / joy1:
 MiST order { fire2, fire, up, down, left, right }. Port 1 (the joystick port of the ST) is JOY_L.
 Port 0 is the mouse; a button of JOY_R makes it JOY_R until a mouse button is pressed (upstream).
*/

module st_hid (
	input wire clk,
	input wire reset,

	input wire [7:0] kb_status,
	input wire [7:0] kb_dat0,
	input wire [7:0] kb_dat1,
	input wire [7:0] kb_dat2,
	input wire [7:0] kb_dat3,
	input wire [7:0] kb_dat4,
	input wire [7:0] kb_dat5,

	input wire [7:0] ms_x,
	input wire [7:0] ms_y,
	input wire [2:0] ms_b,
	input wire ms_upd,

	input wire [12:0] joy_l,
	input wire [12:0] joy_r,

	input wire [14:0] matrix_out,
	output wire [7:0] matrix_in,
	output wire [5:0] joy0,
	output wire [4:0] joy1,
	output reg kb_reset = 1'b0
);

// ------------------------------------------------------------------ keyboard

reg [3:0] idx = 4'd0;
reg [6:0] code = 7'd0;
reg code_ok = 1'b0;
reg f12_scan = 1'b0;

// the item of this clock
always @(*) begin
	code = 7'd0;
	code_ok = 1'b0;
	case (idx)
	4'd0: begin code = kb_dat0[6:0]; code_ok = !kb_dat0[7]; end
	4'd1: begin code = kb_dat1[6:0]; code_ok = !kb_dat1[7]; end
	4'd2: begin code = kb_dat2[6:0]; code_ok = !kb_dat2[7]; end
	4'd3: begin code = kb_dat3[6:0]; code_ok = !kb_dat3[7]; end
	4'd4: begin code = kb_dat4[6:0]; code_ok = !kb_dat4[7]; end
	4'd5: begin code = kb_dat5[6:0]; code_ok = !kb_dat5[7]; end
	default: begin code = { 4'b1101, idx[2:0] - 3'd6 }; code_ok = kb_status[idx[2:0] - 3'd6]; end
	endcase
end

wire [2:0] km_row;
wire [3:0] km_col;
keymap km (.code(code), .row(km_row), .column(km_col));
// the keymap gives column 0 row 0 for a code it does not know (no key there)
wire hit = code_ok && code != 7'd0 && (km_row != 3'd0 || km_col != 4'd0);

reg [119:0] scan = {120{1'b1}};
reg [119:0] matrix = {120{1'b1}};
always @(posedge clk) begin
	if (reset) begin
		idx <= 4'd0;
		scan <= {120{1'b1}};
		matrix <= {120{1'b1}};
		f12_scan <= 1'b0;
		kb_reset <= 1'b0;
	end
	else begin
		if (hit)
			scan[{ km_col, km_row }] <= 1'b0;
		if (idx < 4'd6 && code_ok && code == 7'h45)
			f12_scan <= 1'b1;
		if (idx == 4'd13) begin
			idx <= 4'd0;
			matrix <= hit ? (scan & ~(120'd1 << { km_col, km_row })) : scan;
			scan <= {120{1'b1}};
			kb_reset <= f12_scan;
			f12_scan <= 1'b0;
		end
		else
			idx <= idx + 4'd1;
	end
end

// the columns that the IKBD selects (low) are ANDed, as MiSTeryNano (misterynano.sv)
reg [7:0] mi;
integer c;
always @(*) begin
	mi = 8'hFF;
	for (c = 0; c < 15; c = c + 1)
		if (!matrix_out[c])
			mi = mi & matrix[c*8 +: 8];
end
assign matrix_in = mi;

// ------------------------------------------------------------------ mouse

reg ms_upd_d = 1'b0;
reg [7:0] mx_cnt = 8'd0, my_cnt = 8'd0;
reg [1:0] mx = 2'd0, my = 2'd0;
reg [1:0] mbtn = 2'd0;
reg [14:0] mdiv = 15'd0;
wire ms_new = ms_upd != ms_upd_d;

always @(posedge clk) begin
	ms_upd_d <= ms_upd;
	mdiv <= mdiv + 15'd1;
	if (reset) begin
		mx_cnt <= 8'd0;
		my_cnt <= 8'd0;
		mbtn <= 2'd0;
	end
	else if (ms_new) begin
		mbtn <= { ms_b[1], ms_b[0] };
		mx_cnt <= mx_cnt + ms_x;
		my_cnt <= my_cnt + ms_y;
	end
	else if (mdiv == 15'd0) begin
		if (mx_cnt != 8'd0) begin
			if (mx_cnt[7]) begin
				mx_cnt <= mx_cnt + 8'd1;
				mx <= { ~mx[0], mx[1] };
			end
			else begin
				mx_cnt <= mx_cnt - 8'd1;
				mx <= { mx[0], ~mx[1] };
			end
		end
		if (my_cnt != 8'd0) begin
			if (my_cnt[7]) begin
				my_cnt <= my_cnt + 8'd1;
				my <= { ~my[0], my[1] };
			end
			else begin
				my_cnt <= my_cnt - 8'd1;
				my <= { my[0], ~my[1] };
			end
		end
	end
end
wire [5:0] mouse = { mbtn, mx, my };

// ------------------------------------------------------------------ joysticks

wire [5:0] jl = { joy_l[7], joy_l[6], joy_l[1], joy_l[2], joy_l[3], joy_l[4] };
wire [5:0] jr = { joy_r[7], joy_r[6], joy_r[1], joy_r[2], joy_r[3], joy_r[4] };

reg port0_mouse = 1'b1;
always @(posedge clk) begin
	if (reset)
		port0_mouse <= 1'b1;
	else if (mouse[5] || mouse[4])
		port0_mouse <= 1'b1;
	else if (jr[5] || jr[4])
		port0_mouse <= 1'b0;
end

assign joy0 = port0_mouse ? mouse : jr;
assign joy1 = jl[4:0];

endmodule
