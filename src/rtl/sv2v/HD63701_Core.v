module HD63701_Core (
	CLK,
	EN,
	EN2,
	RST,
	NMI,
	IRQ,
	IRQ2_TIM,
	IRQ2_SCI,
	RW,
	AD,
	DO,
	DI
);
	input CLK;
	input EN;
	input EN2;
	input RST;
	input NMI;
	input IRQ;
	input IRQ2_TIM;
	input IRQ2_SCI;
	output wire RW;
	output wire [15:0] AD;
	output wire [7:0] DO;
	input [7:0] DI;
	wire [23:0] mcode;
	wire [7:0] vect;
	wire inte;
	wire fncu;
	HD63701_SEQ SEQ(
		.CLK(CLK),
		.EN(EN),
		.RST(RST),
		.NMI(NMI),
		.IRQ(IRQ),
		.IRQ2_TIM(IRQ2_TIM),
		.IRQ2_SCI(IRQ2_SCI),
		.DI(DI),
		.mcout(mcode),
		.vect(vect),
		.inte(inte),
		.fncu(fncu)
	);
	HD63701_EXEC EXEC(
		.CLK(CLK),
		.EN(EN),
		.EN2(EN2),
		.RST(RST),
		.DI(DI),
		.AD(AD),
		.RW(RW),
		.DO(DO),
		.mcode(mcode),
		.vect(vect),
		.inte(inte),
		.fncu(fncu)
	);
endmodule
