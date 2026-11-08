module ikbd (
	clk,
	res,
	tx,
	rx,
	caps_lock,
	matrix_out,
	matrix_in,
	joystick0,
	joystick1
);
	input clk;
	input res;
	output wire tx;
	input rx;
	output wire caps_lock;
	output wire [14:0] matrix_out;
	input [7:0] matrix_in;
	input [5:0] joystick0;
	input [4:0] joystick1;
	parameter DIV = 4;
	reg [DIV:0] clk_cnt;
	always @(posedge clk) clk_cnt <= clk_cnt + 1;
	wire en = &clk_cnt;
	wire en2 = !clk_cnt[DIV] && &clk_cnt[DIV - 1:0];
	wire en2x = !clk_cnt[DIV - 1] && &clk_cnt[DIV - 2:0];
	wire [7:0] po2;
	wire [7:0] pi4 = (po2[0] ? 8'hff : ~{joystick1[3:0], joystick0[3:0]});
	wire [1:0] fire_buttons = {joystick0[5] | joystick1[4], joystick0[4]};
	wire [7:0] po3;
	wire [7:0] po4;
	assign tx = po2[4];
	assign caps_lock = po3[0];
	HD63701V0_M6 HD63701V0_M6(
		.CLK(clk),
		.EN(en),
		.EN2(en2),
		.EN2X(en2x),
		.RES(res),
		.NMI(1'b0),
		.IRQ(1'b0),
		.RW(),
		.AD({po4, po3}),
		.DO(),
		.DI(8'h00),
		.PI1(matrix_in),
		.PI2({po2[4], rx, ~fire_buttons, po2[0]}),
		.PI4(pi4),
		.PO1(),
		.PO2(po2)
	);
	assign matrix_out = {po4, po3[7:1]};
endmodule
