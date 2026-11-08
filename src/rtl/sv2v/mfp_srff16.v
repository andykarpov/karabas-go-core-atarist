module mfp_srff16 (
	clk,
	set,
	mask,
	reset,
	out
);
	input clk;
	input [15:0] set;
	input [15:0] mask;
	input [15:0] reset;
	output reg [15:0] out;
	integer i;
	always @(posedge clk) begin : sv2v_autoblock_1
		reg [15:0] setD;
		setD <= set;
		for (i = 0; i < 16; i = i + 1)
			if (reset[i])
				out[i] <= 0;
			else if ((~setD[i] & set[i]) & mask[i])
				out[i] <= 1;
	end
endmodule
