module HD63701_DSEL13 (
	o,
	f0,
	d0,
	f1,
	d1,
	f2,
	d2,
	f3,
	d3,
	f4,
	d4,
	f5,
	d5,
	f6,
	d6,
	f7,
	d7,
	f8,
	d8,
	f9,
	d9,
	fA,
	dA,
	fB,
	dB,
	fC,
	dC
);
	output wire [15:0] o;
	input f0;
	input [15:0] d0;
	input f1;
	input [15:0] d1;
	input f2;
	input [15:0] d2;
	input f3;
	input [15:0] d3;
	input f4;
	input [15:0] d4;
	input f5;
	input [15:0] d5;
	input f6;
	input [15:0] d6;
	input f7;
	input [15:0] d7;
	input f8;
	input [15:0] d8;
	input f9;
	input [15:0] d9;
	input fA;
	input [15:0] dA;
	input fB;
	input [15:0] dB;
	input fC;
	input [15:0] dC;
	assign o = (f0 ? d0 : (f1 ? d1 : (f2 ? d2 : (f3 ? d3 : (f4 ? d4 : (f5 ? d5 : (f6 ? d6 : (f7 ? d7 : (f8 ? d8 : (f9 ? d9 : (fA ? dA : (fB ? dB : (fC ? dC : 16'h0000)))))))))))));
endmodule
