module HD63701_IOPort (
	mcu_rst,
	mcu_clk,
	mcu_en,
	mcu_ad,
	mcu_wr,
	mcu_do,
	en_io,
	iod,
	PI1,
	PI2,
	PI3,
	PI4,
	PO1,
	PO2,
	PO3,
	PO4
);
	input mcu_rst;
	input mcu_clk;
	input mcu_en;
	input [15:0] mcu_ad;
	input mcu_wr;
	input [7:0] mcu_do;
	output wire en_io;
	output wire [7:0] iod;
	input [7:0] PI1;
	input [4:0] PI2;
	input [7:0] PI3;
	input [7:0] PI4;
	output wire [7:0] PO1;
	output wire [7:0] PO2;
	output wire [7:0] PO3;
	output wire [7:0] PO4;
	reg [7:0] DDR1;
	reg [7:0] PO1R;
	assign PO1 = ~DDR1 | PO1R;
	reg [4:0] DDR2;
	reg [7:0] PO2R;
	assign PO2 = {3'b000, ~DDR2} | PO2R;
	reg [7:0] DDR3;
	reg [7:0] PO3R;
	assign PO3 = ~DDR3 | PO3R;
	reg [7:0] DDR4;
	reg [7:0] PO4R;
	assign PO4 = ~DDR4 | PO4R;
	always @(posedge mcu_clk)
		if (mcu_rst) begin
			DDR1 <= 8'h00;
			DDR2 <= 5'h00;
			DDR3 <= 8'h00;
			DDR4 <= 8'h00;
			PO2R[7:5] <= PI2[2:0];
		end
		else if (mcu_en) begin
			if (mcu_wr) begin
				if (mcu_ad == 16'h0000)
					DDR1 <= mcu_do;
				if (mcu_ad == 16'h0001)
					DDR2 <= mcu_do[4:0];
				if (mcu_ad == 16'h0002)
					PO1R <= mcu_do;
				if (mcu_ad == 16'h0003)
					PO2R[4:0] <= mcu_do[4:0];
				if (mcu_ad == 16'h0004)
					DDR3 <= mcu_do;
				if (mcu_ad == 16'h0005)
					DDR4 <= mcu_do;
				if (mcu_ad == 16'h0006)
					PO3R <= mcu_do;
				if (mcu_ad == 16'h0007)
					PO4R <= mcu_do;
			end
		end
	assign en_io = mcu_ad[15:3] == 13'h0000;
	assign iod = (mcu_ad == 16'h0000 ? DDR1 : (mcu_ad == 16'h0001 ? {3'b111, DDR2} : (mcu_ad == 16'h0002 ? PI1 : (mcu_ad == 16'h0003 ? {3'b111, PI2} : (mcu_ad == 16'h0004 ? DDR3 : (mcu_ad == 16'h0005 ? DDR4 : (mcu_ad == 16'h0006 ? PI3 : PI4)))))));
endmodule
