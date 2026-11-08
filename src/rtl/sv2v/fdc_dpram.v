module fdc_dpram (
	douta,
	doutb,
	clka,
	ocea,
	cea,
	reseta,
	wrea,
	clkb,
	oceb,
	ceb,
	resetb,
	wreb,
	ada,
	dina,
	adb,
	dinb
);
	output reg [7:0] douta;
	output reg [7:0] doutb;
	input clka;
	input ocea;
	input cea;
	input reseta;
	input wrea;
	input clkb;
	input oceb;
	input ceb;
	input resetb;
	input wreb;
	input [9:0] ada;
	input [7:0] dina;
	input [9:0] adb;
	input [7:0] dinb;
	reg [7:0] ram [0:1023];
	always @(posedge clka)
		if (wrea) begin
			ram[ada] <= dina;
			douta <= dina;
		end
		else
			douta <= ram[ada];
	always @(posedge clka)
		if (wreb) begin
			ram[adb] <= dinb;
			doutb <= dinb;
		end
		else
			doutb <= ram[adb];
endmodule
