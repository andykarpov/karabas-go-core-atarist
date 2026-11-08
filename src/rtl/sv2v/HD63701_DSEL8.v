module HD63701_DSEL8 (
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
	d7
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
	assign o = (f0 ? d0 : (f1 ? d1 : (f2 ? d2 : (f3 ? d3 : (f4 ? d4 : (f5 ? d5 : (f6 ? d6 : (f7 ? d7 : 16'h0000))))))));
endmodule
