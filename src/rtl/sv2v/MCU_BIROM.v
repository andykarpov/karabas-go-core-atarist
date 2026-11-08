module MCU_BIROM (
	CLK,
	EN,
	AD,
	DO
);
	input CLK;
	input EN;
	input [11:0] AD;
	output reg [7:0] DO;
	reg [7:0] rom [0:4095];
	initial $readmemh("rtl/ikbd/rom/ikbd.hex", rom, 0);
	always @(posedge CLK)
		if (EN)
			DO <= rom[AD];
endmodule
