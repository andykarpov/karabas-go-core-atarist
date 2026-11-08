module register (
	clock,
	s,
	r,
	c,
	d,
	q
);
	input clock;
	input s;
	input r;
	input c;
	parameter WIDTH = 1;
	input [WIDTH - 1:0] d;
	output reg [WIDTH - 1:0] q;
	reg [WIDTH - 1:0] val_reg;
	reg c_d;
	always @(*)
		if (r)
			q = 0;
		else if (s)
			q = 1;
		else
			q = val_reg;
	always @(negedge clock) begin
		c_d <= c;
		if (((~c_d & c) & ~r) & ~s)
			val_reg <= d;
		else
			val_reg <= q;
	end
endmodule
