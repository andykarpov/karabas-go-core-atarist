module HD63701V0_M6 (
	CLK,
	EN,
	EN2,
	EN2X,
	RES,
	NMI,
	IRQ,
	RW,
	AD,
	DO,
	DI,
	PI4,
	PI1,
	PO1,
	PI2,
	PO2
);
	input CLK;
	input EN;
	input EN2;
	input EN2X;
	input RES;
	input NMI;
	input IRQ;
	output wire RW;
	output wire [15:0] AD;
	output wire [7:0] DO;
	input [7:0] DI;
	input [7:0] PI4;
	input [7:0] PI1;
	output wire [7:0] PO1;
	input [4:0] PI2;
	output wire [7:0] PO2;
	reg RST = 1'b1;
	always @(posedge CLK)
		if (EN)
			RST <= RES;
	wire [7:0] PO2I;
	wire te;
	wire txd;
	assign PO2 = (te ? {PO2I[7:5], txd, PO2I[3:0]} : PO2I);
	wire [15:0] ADI;
	wire [7:0] PO3;
	wire [7:0] PO4;
	assign AD = (PO2I[7:5] == 3'b111 ? {PO4, PO3} : ADI);
	wire en_birom = ADI[15:12] == 4'b1111;
	wire [7:0] biromd;
	MCU_BIROM irom(
		.CLK(CLK),
		.EN(EN2X),
		.AD(ADI[11:0]),
		.DO(biromd)
	);
	wire en_biram;
	wire [7:0] biramd;
	HD63701_BIRAM biram(
		.mcu_clk(CLK),
		.mcu_en(EN2X),
		.mcu_ad(ADI),
		.mcu_wr(RW),
		.mcu_do(DO),
		.en_biram(en_biram),
		.biramd(biramd)
	);
	wire en_biio;
	wire [7:0] biiod;
	HD63701_IOPort iopt(
		.mcu_rst(RST),
		.mcu_clk(CLK),
		.mcu_en(EN2X),
		.mcu_ad(ADI),
		.mcu_wr(RW),
		.mcu_do(DO),
		.en_io(en_biio),
		.iod(biiod),
		.PI1(PI1),
		.PI2(PI2),
		.PI3(DI),
		.PI4(PI4),
		.PO1(PO1),
		.PO2(PO2I),
		.PO3(PO3),
		.PO4(PO4)
	);
	wire irq2_sci;
	wire en_bisci;
	wire [7:0] biscid;
	HD63701_SCI sci(
		.mcu_rst(RST),
		.mcu_clk(CLK),
		.mcu_en(EN2X),
		.mcu_ad(ADI),
		.mcu_wr(RW),
		.mcu_do(DO),
		.rx(PI2[3]),
		.tx(txd),
		.te(te),
		.mcu_irq2_sci(irq2_sci),
		.en_sci(en_bisci),
		.iod(biscid)
	);
	wire irq2_tim;
	wire en_bitim;
	wire [7:0] bitimd;
	HD63701_Timer timer(
		.mcu_rst(RST),
		.mcu_clk(CLK),
		.mcu_en(EN2X),
		.mcu_en2(EN || EN2),
		.mcu_ad(ADI),
		.mcu_wr(RW),
		.mcu_do(DO),
		.mcu_irq2_tim(irq2_tim),
		.en_timer(en_bitim),
		.timerd(bitimd)
	);
	wire [7:0] biddi;
	HD63701_BIDSEL bidsel(
		.o(biddi),
		.e0(en_birom),
		.d0(biromd),
		.e1(en_biram),
		.d1(biramd),
		.e2(en_biio),
		.d2(biiod),
		.e3(en_bisci),
		.d3(biscid),
		.e4(en_bitim),
		.d4(bitimd),
		.dx(DI)
	);
	HD63701_Core core(
		.CLK(CLK),
		.EN(EN),
		.EN2(EN2),
		.RST(RST),
		.NMI(NMI),
		.IRQ(IRQ),
		.IRQ2_TIM(irq2_tim),
		.IRQ2_SCI(irq2_sci),
		.RW(RW),
		.AD(ADI),
		.DO(DO),
		.DI(biddi)
	);
endmodule
