module mlatch (
	clock,
	s,
	r,
	g,
	d,
	q
);
	input clock;
	input s;
	input r;
	input g;
	parameter WIDTH = 1;
	input [WIDTH - 1:0] d;
	output reg [WIDTH - 1:0] q;
	reg [WIDTH - 1:0] val_reg;
	always @(*)
		if (r)
			q = 0;
		else if (s)
			q = 1;
		else if (g)
			q = d;
		else
			q = val_reg;
	always @(posedge clock) val_reg <= q;
endmodule
