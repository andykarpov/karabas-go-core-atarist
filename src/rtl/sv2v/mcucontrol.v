module mcucontrol (
	clk32,
	porb,
	resb,
	turbo,
	clk,
	ias,
	idev,
	iram,
	iuds,
	ilds,
	irwz,
	ixdmab,
	vmapb,
	smapb,
	ideb,
	hde1,
	addrselb,
	time0,
	time1,
	lcycsel,
	cycsel_en,
	ivsync,
	sreq,
	sndon,
	sfrep,
	snd,
	sft,
	cmpcycb,
	ramcycb,
	refb,
	frame,
	vidb,
	viden,
	vos,
	sndclk,
	snden,
	sframe,
	stoff,
	rdat_n,
	we_n,
	wdat_n,
	cmpcs_n,
	dcyc_n,
	sload_n,
	sint
);
	input clk32;
	input porb;
	input resb;
	input turbo;
	input clk;
	input ias;
	input idev;
	input iram;
	input iuds;
	input ilds;
	input irwz;
	input ixdmab;
	input vmapb;
	input smapb;
	input ideb;
	input hde1;
	input addrselb;
	input time0;
	input time1;
	input lcycsel;
	input cycsel_en;
	input ivsync;
	input sreq;
	input sndon;
	input sfrep;
	input [21:1] snd;
	input [21:1] sft;
	output wire cmpcycb;
	output wire ramcycb;
	output wire refb;
	output wire frame;
	output reg vidb;
	output wire viden;
	output wire vos;
	output wire sndclk;
	output wire snden;
	output wire sframe;
	output wire stoff;
	output wire rdat_n;
	output wire we_n;
	output wire wdat_n;
	output wire cmpcs_n;
	output wire dcyc_n;
	output wire sload_n;
	output wire sint;
	wire c1 = ~(lcycsel & time1);
	wire c1_en_p = (lcycsel & time1) & clk;
	wire c1_en_n = cycsel_en;
	reg c1_rise;
	reg c1_fall;
	always @(posedge clk32) begin
		c1_rise <= c1_en_p;
		c1_fall <= c1_en_n;
	end
	reg pk005;
	assign frame = ~pk005;
	assign viden = ~vidb;
	reg pk016;
	reg pk024;
	assign refb = pk016 | pk024;
	assign vos = ~(vidb & ~snden);
	always @(posedge clk32 or negedge porb)
		if (!porb)
			{pk005, vidb, pk016} <= 3'b010;
		else if (c1_en_p) begin
			pk005 <= ivsync;
			vidb <= ideb;
			pk016 <= hde1;
		end
	assign sndclk = ~(addrselb & snden);
	assign snden = ~pk016 & pk024;
	wire pk061 = (snd == sft) & ~c1;
	wire sintsb = sframe;
	assign stoff = pk061 & ~sfrep;
	reg pk031;
	always @(posedge clk32)
		if (c1_en_p)
			pk031 <= sndon;
	mlatch sframe_l(
		.clock(clk32),
		.s(1'b0),
		.r(!pk031),
		.g(!clk ^ turbo),
		.d(~(pk061 & sfrep)),
		.q(sframe)
	);
	mlatch sint_l(
		.clock(clk32),
		.s(!sintsb),
		.r(1'b0),
		.g(c1_fall),
		.d(1'b0),
		.q(sint)
	);
	always @(posedge clk32 or negedge pk031)
		if (!pk031)
			pk024 <= 0;
		else if (c1_en_p)
			pk024 <= sreq;
	mlatch sload_n_l(
		.clock(clk32),
		.s(!porb),
		.r(1'b0),
		.g(clk),
		.d(~((time1 & addrselb) & snden)),
		.q(sload_n)
	);
	wire cmap = ((((~irwz | iuds) | ilds) & (~vmapb | ~smapb)) & idev) & ias;
	wire ramsel = (((~irwz | ilds) | iuds) & ias) & iram;
	reg ramcyc;
	reg cmpcyc;
	always @(posedge clk32 or negedge cmap)
		if (!cmap)
			cmpcyc <= 0;
		else if (cycsel_en)
			cmpcyc <= cmap;
	always @(posedge clk32 or negedge ramsel)
		if (!ramsel)
			ramcyc <= 0;
		else if (cycsel_en)
			ramcyc <= ramsel;
	wire dcyc;
	mlatch dcyc_l(
		.clock(clk32),
		.s(!porb),
		.r(1'b0),
		.g(clk ^ turbo),
		.d(!resb | ((time1 & addrselb) & viden)),
		.q(dcyc)
	);
	assign dcyc_n = ~dcyc;
	assign cmpcycb = ~cmpcyc;
	assign ramcycb = ~ramcyc;
	assign we_n = ~((((ramcyc & cmpcycb) & ~irwz) & ~time0) & ~addrselb);
	assign rdat_n = ~(((cmpcyc & ramcycb) & irwz) | ((ramcyc & cmpcycb) & irwz));
	assign wdat_n = ~(~we_n | ((((cmpcyc & ramcycb) & ~irwz) & ~time1) & ~addrselb));
	assign cmpcs_n = ~((((((cmpcyc & ramcycb) & ~irwz) & ~time1) & ~addrselb) | ((((cmpcyc & ramcycb) & irwz) & lcycsel) & ~time1)) | ~resb);
endmodule
