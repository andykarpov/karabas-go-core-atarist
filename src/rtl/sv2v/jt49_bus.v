module jt49_bus (
	rst_n,
	clk,
	clk_en,
	bdir,
	bc1,
	din,
	sel,
	dout,
	sound,
	A,
	B,
	C,
	sample,
	IOA_in,
	IOA_out,
	IOA_oe,
	IOB_in,
	IOB_out,
	IOB_oe
);
	input rst_n;
	input clk;
	input clk_en;
	input bdir;
	input bc1;
	input [7:0] din;
	input sel;
	output wire [7:0] dout;
	output wire [9:0] sound;
	output wire [7:0] A;
	output wire [7:0] B;
	output wire [7:0] C;
	output wire sample;
	input [7:0] IOA_in;
	output wire [7:0] IOA_out;
	output wire IOA_oe;
	input [7:0] IOB_in;
	output wire [7:0] IOB_out;
	output wire IOB_oe;
	parameter [1:0] COMP = 2'b00;
	reg wr_n;
	reg cs_n;
	reg [3:0] addr;
	reg addr_ok;
	reg [7:0] din_latch;
	always @(posedge clk)
		if (!rst_n) begin
			wr_n <= 1'b1;
			cs_n <= 1'b1;
			addr <= 4'd0;
			addr_ok <= 1'b1;
		end
		else
			case ({bdir, bc1})
				2'b00: {wr_n, cs_n} <= 2'b11;
				2'b01: {wr_n, cs_n} <= (addr_ok ? 2'b10 : 2'b11);
				2'b10: begin
					{wr_n, cs_n} <= (addr_ok ? 2'b00 : 2'b11);
					din_latch <= din;
				end
				2'b11: begin
					{wr_n, cs_n} <= 2'b11;
					addr <= din[3:0];
					addr_ok <= din[7:4] == 4'd0;
				end
			endcase
	jt49 #(.COMP(COMP)) u_jt49(
		.rst_n(rst_n),
		.clk(clk),
		.clk_en(clk_en),
		.addr(addr[3:0]),
		.cs_n(cs_n),
		.wr_n(wr_n),
		.din(din_latch),
		.sel(sel),
		.dout(dout),
		.sound(sound),
		.sample(sample),
		.A(A),
		.B(B),
		.C(C),
		.IOA_in(IOA_in),
		.IOA_out(IOA_out),
		.IOA_oe(IOA_oe),
		.IOB_in(IOB_in),
		.IOB_out(IOB_out),
		.IOB_oe(IOB_oe)
	);
endmodule
