module HD63701_BIRAM (
	mcu_clk,
	mcu_en,
	mcu_ad,
	mcu_wr,
	mcu_do,
	en_biram,
	biramd
);
	input mcu_clk;
	input mcu_en;
	input [15:0] mcu_ad;
	input mcu_wr;
	input [7:0] mcu_do;
	output wire en_biram;
	output reg [7:0] biramd;
	assign en_biram = mcu_ad[15:7] == 9'b000000001;
	wire [6:0] biad = mcu_ad[6:0];
	reg [7:0] bimem [0:127];
	always @(posedge mcu_clk)
		if (mcu_en) begin
			if (en_biram & mcu_wr)
				bimem[biad] <= mcu_do;
			else
				biramd <= bimem[biad];
		end
endmodule
