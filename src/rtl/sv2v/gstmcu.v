module gstmcu (
	clk32,
	resb,
	porb,
	FC0,
	FC1,
	FC2,
	AS_N,
	RW,
	UDS_N,
	LDS_N,
	VMA_N,
	MFPINT_N,
	A,
	ADDR,
	DIN,
	DOUT,
	OE_L,
	OE_H,
	CLK_O,
	MHZ8,
	MHZ8_EN1,
	MHZ8_EN2,
	MHZ4,
	MHZ4_EN,
	RDY_N_I,
	RDY_N_O,
	BG_N,
	BR_N_I,
	BR_N_O,
	BGACK_N_I,
	BGACK_N_O,
	BERR_N,
	IPL0_N,
	IPL1_N,
	IPL2_N,
	DTACK_N_I,
	DTACK_N_O,
	IACK_N,
	ROM0_N,
	ROM1_N,
	ROM2_N,
	ROM3_N,
	ROM4_N,
	ROM5_N,
	ROM6_N,
	ROMP_N,
	RAM_N,
	RAS0_N,
	RAS1_N,
	CAS0L_N,
	CAS0H_N,
	CAS1L_N,
	CAS1H_N,
	RAM_LDS,
	RAM_UDS,
	REF,
	VPA_N,
	MFPCS_N,
	SNDIR,
	SNDCS,
	N6850,
	FCS_N,
	RTCCS_N,
	RTCRD_N,
	RTCWR_N,
	LATCH,
	HSYNC_N,
	VSYNC_N,
	DE,
	BLANK_N,
	RDAT_N,
	WE_N,
	WDAT_N,
	CMPCS_N,
	DCYC_N,
	SREQ,
	SLOAD_N,
	SINT,
	BUTTON_N,
	JOYWE_N,
	JOYRL_N,
	JOYWL,
	JOYRH_N,
	st,
	extra_ram,
	tos192k,
	turbo,
	viking_at_c0,
	viking_at_e8,
	bus_cycle
);
	input clk32;
	input resb;
	input porb;
	input FC0;
	input FC1;
	input FC2;
	input AS_N;
	input RW;
	input UDS_N;
	input LDS_N;
	input VMA_N;
	input MFPINT_N;
	input [23:1] A;
	output reg [23:1] ADDR;
	input [15:0] DIN;
	output wire [15:0] DOUT;
	output wire OE_L;
	output wire OE_H;
	output wire CLK_O;
	output wire MHZ8;
	output wire MHZ8_EN1;
	output wire MHZ8_EN2;
	output wire MHZ4;
	output wire MHZ4_EN;
	input RDY_N_I;
	output wire RDY_N_O;
	input BG_N;
	input BR_N_I;
	output wire BR_N_O;
	input BGACK_N_I;
	output wire BGACK_N_O;
	output wire BERR_N;
	output wire IPL0_N;
	output wire IPL1_N;
	output wire IPL2_N;
	input DTACK_N_I;
	output wire DTACK_N_O;
	output wire IACK_N;
	output wire ROM0_N;
	output wire ROM1_N;
	output wire ROM2_N;
	output wire ROM3_N;
	output wire ROM4_N;
	output wire ROM5_N;
	output wire ROM6_N;
	output wire ROMP_N;
	output wire RAM_N;
	output wire RAS0_N;
	output wire RAS1_N;
	output wire CAS0L_N;
	output wire CAS0H_N;
	output wire CAS1L_N;
	output wire CAS1H_N;
	output wire RAM_LDS;
	output wire RAM_UDS;
	output wire REF;
	output wire VPA_N;
	output wire MFPCS_N;
	output wire SNDIR;
	output wire SNDCS;
	output wire N6850;
	output wire FCS_N;
	output wire RTCCS_N;
	output wire RTCRD_N;
	output wire RTCWR_N;
	output wire LATCH;
	output wire HSYNC_N;
	output wire VSYNC_N;
	output reg DE;
	output reg BLANK_N;
	output wire RDAT_N;
	output wire WE_N;
	output wire WDAT_N;
	output wire CMPCS_N;
	output wire DCYC_N;
	input SREQ;
	output wire SLOAD_N;
	output wire SINT;
	output wire BUTTON_N;
	output reg JOYWE_N;
	output wire JOYRL_N;
	output wire JOYWL;
	output wire JOYRH_N;
	input st;
	input extra_ram;
	input tos192k;
	input turbo;
	input viking_at_c0;
	input viking_at_e8;
	output wire [1:0] bus_cycle;
	reg [21:1] snd;
	wire time4_t;
	wire time5_s;
	wire addrselb = (turbo ? ~time4_t : ~time5_s);
	reg [23:1] dma_reg;
	reg ixdma;
	wire ixdmab = ~ixdma;
	wire refb;
	wire snden;
	reg [23:1] vid_reg;
	always @(*)
		casez ({addrselb, ixdmab, snden, refb})
			4'b00zz: ADDR = dma_reg;
			4'b01zz: ADDR = A;
			4'b1zz0: ADDR = 0;
			4'b1z11: ADDR = {2'b00, snd};
			4'b1z01: ADDR = vid_reg;
		endcase
	assign REF = addrselb & ~refb;
	reg p8008_s;
	reg p8010_s;
	wire aso = p8008_s | ~p8010_s;
	wire ias = (ixdma ? aso : ~AS_N);
	reg drw;
	wire irwz = (ixdma ? drw : RW);
	wire irwb = ~irwz;
	reg p8001_s;
	wire dso = ((p8008_s & p8001_s) | (p8008_s & drw)) | ~p8010_s;
	wire iuds = (ixdma ? dso : ~UDS_N);
	wire ilds = (ixdma ? dso : ~LDS_N);
	wire ivma = ~VMA_N;
	wire ifc0 = (ixdma ? 1'b1 : FC0);
	wire ifc1 = (ixdma ? 1'b0 : FC1);
	wire ifc2 = (ixdma ? 1'b1 : FC2);
	wire iiack = ((ias & ifc0) & ifc1) & ifc2;
	wire ifc2z = ifc2;
	wire fcx = ifc0 ^ ifc1;
	wire [15:0] id = DIN;
	reg udenb;
	wire doutb;
	assign OE_H = ~udenb;
	assign OE_L = ~doutb;
	wire vclrb = ~(iiack & (A[3:1] == 3'b100));
	wire hclrb = ~(iiack & (A[3:1] == 3'b010));
	wire device = (ixdmab & ifc2z) & fcx;
	wire idev = device & (A[23:16] == 8'hff);
	assign IACK_N = ~(iiack & (A[3:1] == 3'b110));
	assign VPA_N = ~((((idev & ias) & (A[15:9] == 7'h7e)) | ~vclrb) | ~hclrb);
	assign MFPCS_N = ~((idev & ias) & (A[15:6] == 10'h3e8));
	wire isndcsb = ~((idev & ias) & (A[15:8] == 8'h88));
	assign SNDIR = ~isndcsb & ~irwz;
	assign SNDCS = ~isndcsb & ~A[1];
	assign N6850 = (idev & ivma) & (A[15:3] == 13'h1f80);
	wire pifcsb = ~((((idev & ias) & ilds) & iuds) & (A[15:2] == 14'h2181));
	wire ifcsb = pifcsb & resb;
	assign FCS_N = ifcsb;
	assign RTCCS_N = ~((idev & ias) & (A[15:5] == 11'h7e1));
	assign RTCRD_N = ~((irwz & ivma) & ilds);
	assign RTCWR_N = ~((irwb & ivma) & ilds);
	wire overlap = |A[15:3];
	wire rvec = (((irwz & ~overlap) & ifc2z) & fcx) & ixdmab;
	wire rom = (irwz & fcx) & ixdmab;
	wire irom0 = ((rom & ias) & ~tos192k) & (A[23:18] == 6'h3a);
	wire irom1 = ((rom & ias) & ~tos192k) & (A[23:18] == 6'h39);
	wire irom2 = ((ias & rvec) & (A[23:16] == 8'h00)) | ((rom & ias) & ((~tos192k & (A[23:18] == 6'h38)) | ((tos192k & (A[23:18] == 6'h3f)) & (A[19:16] != 4'hf))));
	wire gamecart;
	wire irom3 = (((rom & ias) & ~gamecart) & (A[23:16] == 8'hfb)) | (((rom & ias) & gamecart) & (A[23:18] == 6'h37));
	wire irom4 = (((rom & ias) & ~gamecart) & (A[23:16] == 8'hfa)) | (((rom & ias) & gamecart) & (A[23:18] == 6'h36));
	wire irom5 = (rom & ias) & (A[23:18] == 6'h35);
	wire irom6 = (rom & ias) & (A[23:18] == 6'h34);
	wire romp = (rom & ias) & (A[23:13] == 11'h7f0);
	wire romxb = ~(((((((irom0 | irom1) | irom2) | irom3) | irom4) | irom6) | irom6) | romp);
	assign ROM0_N = ~irom0;
	assign ROM1_N = ~irom1;
	assign ROM2_N = ~irom2;
	assign ROM3_N = ~irom3;
	assign ROM4_N = ~irom4;
	assign ROM5_N = ~irom5;
	assign ROM6_N = ~irom6;
	assign ROMP_N = ~romp;
	wire viking_c0 = viking_at_c0 && (A[23:18] == 6'b110000);
	wire viking_e8 = viking_at_e8 && (A[23:19] == 5'b11101);
	wire iram_extra = (fcx & extra_ram) & ((A[23] ^ A[22]) | ((A[23] & A[22]) & ~A[21]));
	wire system = ifc2z | (A[15:11] != 0);
	wire irama = |A[21:16];
	wire iramb = (fcx & ~A[23]) & ~A[22];
	wire iramaa = irama & iramb;
	wire iramc = (overlap & fcx) & system;
	wire iramab = (A[23:16] == 0) & iramc;
	wire iram = (((((iramaa | iramab) | ~ixdmab) | viking_c0) | viking_e8) | iram_extra) | ~resb;
	assign RAM_N = ~iram;
	wire dmadir = ((idev & ias) & iuds) & (A[15:1] == 15'h4303);
	wire dmadirb = ~dmadir;
	wire mdesel = (idev & ias) & (A[15:1] == 15'h4130);
	wire syncsel = (idev & ias) & (A[15:1] == 15'h4105);
	wire scrlsel = (((idev & ias) & ilds) & (A[15:1] == 15'h4132)) & ~st;
	wire cartsel = ((idev & ias) & (A[15:1] == 15'h4800)) & ~st;
	wire butsel = ((idev & ias) & (A[15:1] == 15'h4900)) & ~st;
	wire joysel = ((idev & ias) & (A[15:1] == 15'h4901)) & ~st;
	wire padsel = ((idev & ias) & (A[15:3] == 13'h1242)) & ~st;
	wire pensel = ((idev & ias) & (A[15:2] == 14'h2488)) & ~st;
	wire regs = (((idev & ias) & (A[15:12] == 4'h8)) & ~A[8]) & ~A[11];
	wire dma = A[9] & A[10];
	wire video = A[9] & ~A[10];
	wire conf = ~A[9] & ~A[10];
	wire vmapb = ~(idev & (A[15:6] == 10'h209));
	wire regrd = (irwz & (A[7:4] == 4'h0)) & ilds;
	wire regwr = (irwb & (A[7:4] == 4'h0)) & ilds;
	wire rconfigb = ~(((regs & conf) & regrd) & (A[3:1] == 3'd0));
	wire wconfigb = ~(((regs & conf) & regwr) & (A[3:1] == 3'd0));
	wire rvidbhb = ~(((regs & video) & regrd) & (A[3:1] == 3'd0));
	wire wvidbhb = ~(((regs & video) & regwr) & (A[3:1] == 3'd0));
	wire rvidbmb = ~(((regs & video) & regrd) & (A[3:1] == 3'd1));
	wire wvidbmb = ~(((regs & video) & regwr) & (A[3:1] == 3'd1));
	wire rlochb = ~(((regs & video) & regrd) & (A[3:1] == 3'd2));
	wire wlochb = ~(((regs & video) & regwr) & (A[3:1] == 3'd2)) | st;
	wire rlocmb = ~(((regs & video) & regrd) & (A[3:1] == 3'd3));
	wire wlocmb = ~(((regs & video) & regwr) & (A[3:1] == 3'd3)) | st;
	wire rloclb = ~(((regs & video) & regrd) & (A[3:1] == 3'd4));
	wire wloclb = ~(((regs & video) & regwr) & (A[3:1] == 3'd4)) | st;
	wire rvidblb = ~(((regs & video) & regrd) & (A[3:1] == 3'd6)) | st;
	wire wvidblb = ~(((regs & video) & regwr) & (A[3:1] == 3'd6)) | st;
	wire rhoffb = ~(((regs & video) & regrd) & (A[3:1] == 3'd7)) | st;
	wire whoffb = ~(((regs & video) & regwr) & (A[3:1] == 3'd7)) | st;
	wire rdmahb = ~(((regs & dma) & regrd) & (A[3:1] == 3'd4));
	wire wdmah = ~(((regs & dma) & regwr) & (A[3:1] == 3'd4));
	wire rdmamb = ~(((regs & dma) & regrd) & (A[3:1] == 3'd5));
	wire wdmam = ~(((regs & dma) & regwr) & (A[3:1] == 3'd5));
	wire rdmalb = ~(((regs & dma) & regrd) & (A[3:1] == 3'd6));
	wire wdmal = ~(((regs & dma) & regwr) & (A[3:1] == 3'd6));
	wire srgackb = ~((idev & ias) & (A[15:5] == 11'h448)) | st;
	wire regxackb = ~((((regs & (A[9] | ~A[10])) & (~dma | A[3])) & (A[7:4] == 4'h0)) | ~srgackb);
	wire sndrgb = ~((~srgackb & ilds) & irwz);
	wire smapb = ~(idev & (A[15:5] == 11'h449)) | st;
	wire rscntlb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4480)) | st;
	wire wscntlb = ~((((idev & ias) & ilds) & irwb) & (A[15:1] == 15'h4480)) | st;
	wire rsfbhb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4481)) | st;
	wire wsfbhb = ~((((idev & ias) & ilds) & irwb) & (A[15:1] == 15'h4481)) | st;
	wire rsfbmb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4482)) | st;
	wire wsfbmb = ~((((idev & ias) & ilds) & irwb) & (A[15:1] == 15'h4482)) | st;
	wire rsfblb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4483)) | st;
	wire wsfblb = ~((((idev & ias) & ilds) & irwb) & (A[15:1] == 15'h4483)) | st;
	wire rsfchb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4484)) | st;
	wire rsfcmb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4485)) | st;
	wire rsfclb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4486)) | st;
	wire rsfthb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4487)) | st;
	wire wsfthb = ~((((idev & ias) & ilds) & irwb) & (A[15:1] == 15'h4487)) | st;
	wire rsftmb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4488)) | st;
	wire wsftmb = ~((((idev & ias) & ilds) & irwb) & (A[15:1] == 15'h4488)) | st;
	wire rsftlb = ~((((idev & ias) & ilds) & irwz) & (A[15:1] == 15'h4489)) | st;
	wire wsftlb = ~((((idev & ias) & ilds) & irwb) & (A[15:1] == 15'h4489)) | st;
	wire padrb = 1;
	wire penrb = 1;
	assign doutb = ~(((~sndrgb | ~padrb) | ~penrb) | (((((regs & (A[9] | ~A[10])) & (~dma | A[3])) & (A[7:4] == 4'h0)) & ilds) & irwz));
	reg [9:8] idout_h;
	assign DOUT[15:8] = {6'b111111, idout_h};
	reg [7:0] dma_o;
	reg [7:0] snd_o;
	reg [7:0] vid_o;
	assign DOUT[7:0] = (vid_o & snd_o) & dma_o;
	reg iihsync;
	reg iivsync;
	assign HSYNC_N = resb & iihsync;
	assign VSYNC_N = resb & iivsync;
	assign IPL0_N = 1'b1;
	wire hintb;
	wire vintb;
	assign IPL1_N = MFPINT_N & (hintb | ~vintb);
	assign IPL2_N = MFPINT_N & vintb;
	register hintb_r(
		.clock(clk32),
		.s(~((resb & porb) & hclrb)),
		.r(1'b0),
		.c(iihsync),
		.d(1'b0),
		.q(hintb)
	);
	register vintb_r(
		.clock(clk32),
		.s(~((resb & porb) & vclrb)),
		.r(1'b0),
		.c(iivsync),
		.d(1'b0),
		.q(vintb)
	);
	reg [6:0] berr_cnt;
	assign BERR_N = ~berr_cnt[6];
	always @(posedge clk32 or negedge porb)
		if (!porb)
			berr_cnt <= 0;
		else if (~ias)
			berr_cnt <= 0;
		else if (MHZ8_EN1)
			berr_cnt <= berr_cnt + 1'd1;
	register gamecart_r(
		.clock(clk32),
		.s(1'b0),
		.r(~(resb & porb)),
		.c((irwb & cartsel) & iuds),
		.d(id[8]),
		.q(gamecart)
	);
	wire noscroll;
	mlatch noscroll_l(
		.clock(clk32),
		.s(~(resb & porb)),
		.r(1'b0),
		.g(scrlsel),
		.d(~|id[3:0]),
		.q(noscroll)
	);
	wire mde1;
	register mde1_r(
		.clock(clk32),
		.s(1'b0),
		.r(~(resb & porb)),
		.c(~((irwb & mdesel) & iuds) ^ st),
		.d(id[9]),
		.q(mde1)
	);
	wire mde0;
	register mde0_r(
		.clock(clk32),
		.s(1'b0),
		.r(~(resb & porb)),
		.c(~((irwb & mdesel) & iuds) ^ st),
		.d(id[8]),
		.q(mde0)
	);
	wire pal;
	register pal_r(
		.clock(clk32),
		.s(1'b0),
		.r(~(resb & porb)),
		.c(~((irwb & syncsel) & iuds)),
		.d(id[9]),
		.q(pal)
	);
	wire ntsc = ~pal;
	always @(posedge clk32 or negedge resb or negedge porb) begin : drw_block
		reg dmadirb_d;
		if (!porb)
			drw <= 1;
		else if (!resb)
			drw <= 1;
		else begin
			dmadirb_d <= dmadirb;
			if (~dmadirb_d & dmadirb)
				drw <= id[8];
		end
	end
	wire penr = ((iuds & ilds) & irwz) & pensel;
	wire padr = (ilds & irwz) & padsel;
	wire butr = (ilds & irwz) & butsel;
	assign BUTTON_N = ~butr;
	assign JOYRL_N = ~((joysel & ilds) & irwz);
	assign JOYWL = (joysel & irwb) & ilds;
	assign JOYRH_N = ~((joysel & iuds) & irwz);
	always @(posedge clk32)
		if (!resb || !JOYRL_N)
			JOYWE_N <= 1;
		else if (JOYWL)
			JOYWE_N <= 0;
	always @(*) begin
		idout_h = 2'b11;
		if ((cartsel & irwz) & iuds)
			idout_h = {1'b0, gamecart};
		if ((syncsel & irwz) & iuds)
			idout_h = {pal, 1'b0};
		udenb = ~((irwz & iuds) & (cartsel | syncsel));
	end
	reg wloclb_rs = 1'b0;
	reg wlocmb_rs = 1'b0;
	reg wlochb_rs = 1'b0;
	wire frame;
	always @(posedge clk32) begin
		if (~frame)
			{wloclb_rs, wlocmb_rs, wlochb_rs} <= 3'b000;
		if (~wloclb)
			wloclb_rs <= 1'b1;
		if (~wlocmb)
			wlocmb_rs <= 1'b1;
		if (~wlochb)
			wlochb_rs <= 1'b1;
	end
	wire [23:1] vld;
	wire [23:1] lvd;
	assign vld[23:22] = (extra_ram ? (~wlochb | wlochb_rs ? id[7:6] : lvd[23:22]) : 2'b00);
	assign vld[21:16] = (~wlochb | wlochb_rs ? id[5:0] : lvd[21:16]);
	assign vld[15:8] = (~wlocmb | wlocmb_rs ? id[7:0] : lvd[15:8]);
	assign vld[7:1] = (~wloclb | wloclb_rs ? id[7:1] : lvd[7:1]);
	wire [7:0] hoff;
	mlatch #(.WIDTH(8)) hoff_l(
		.clock(clk32),
		.s(1'b0),
		.r(~(resb & porb)),
		.g(~whoffb),
		.d(id[7:0]),
		.q(hoff)
	);
	mlatch #(.WIDTH(7)) lvd_ll(
		.clock(clk32),
		.s(1'b0),
		.r(~(((resb & porb) & wvidbmb) & wvidbhb)),
		.g(~wvidblb),
		.d(id[7:1]),
		.q(lvd[7:1])
	);
	mlatch #(.WIDTH(8)) lvd_ml(
		.clock(clk32),
		.s(1'b0),
		.r(~(resb & porb)),
		.g(~wvidbmb),
		.d(id[7:0]),
		.q(lvd[15:8])
	);
	mlatch #(.WIDTH(8)) lvd_hl(
		.clock(clk32),
		.s(1'b0),
		.r(~(resb & porb)),
		.g(~wvidbhb),
		.d(id[7:0]),
		.q(lvd[23:16])
	);
	wire [3:0] conf_reg;
	mlatch #(.WIDTH(4)) conf_l(
		.clock(clk32),
		.s(1'b0),
		.r(~porb),
		.g(~wconfigb),
		.d(id[3:0]),
		.q(conf_reg[3:0])
	);
	wire rs2b = ~conf_reg[2];
	wire rs3b = ~conf_reg[3];
	reg [23:1] vid;
	always @(*) begin
		vid_o = 8'hff;
		if (~rhoffb)
			vid_o = hoff;
		if (~rvidblb)
			vid_o = {lvd[7:1], 1'b0};
		if (~rvidbmb)
			vid_o = lvd[15:8];
		if (~rvidbhb)
			vid_o = {(extra_ram ? lvd[23:22] : 2'b00), lvd[21:16]};
		if (~rconfigb)
			vid_o = {4'b0000, conf_reg};
		if (~rloclb)
			vid_o = {vid[7:1], 1'b0};
		if (~rlocmb)
			vid_o = vid[15:8];
		if (~rlochb)
			vid_o = vid[23:16];
	end
	wire [21:1] sfb;
	wire [21:1] sft_l;
	reg [21:1] sft;
	wire [3:1] snd_ctrl;
	wire sndon;
	wire sfrep = snd_ctrl[1];
	wire stoff;
	mlatch #(.WIDTH(7)) sfb_ll(
		.clock(clk32),
		.s(1'b0),
		.r(~resb & porb),
		.g(~wsfblb),
		.d(id[7:1]),
		.q(sfb[7:1])
	);
	mlatch #(.WIDTH(8)) sfb_ml(
		.clock(clk32),
		.s(1'b0),
		.r(~resb & porb),
		.g(~wsfbmb),
		.d(id[7:0]),
		.q(sfb[15:8])
	);
	mlatch #(.WIDTH(6)) sfb_hl(
		.clock(clk32),
		.s(1'b0),
		.r(~resb & porb),
		.g(~wsfbhb),
		.d(id[5:0]),
		.q(sfb[21:16])
	);
	mlatch #(.WIDTH(3)) sctl_l(
		.clock(clk32),
		.s(1'b0),
		.r(~resb & porb),
		.g(~wscntlb),
		.d(id[3:1]),
		.q(snd_ctrl)
	);
	mlatch #(.WIDTH(1)) sndon_l(
		.clock(clk32),
		.s(1'b0),
		.r((~resb & porb) | stoff),
		.g(~wscntlb),
		.d(id[0]),
		.q(sndon)
	);
	mlatch #(.WIDTH(7)) sft_lll(
		.clock(clk32),
		.s(1'b0),
		.r(~resb & porb),
		.g(~wsftlb),
		.d(id[7:1]),
		.q(sft_l[7:1])
	);
	mlatch #(.WIDTH(8)) sft_mll(
		.clock(clk32),
		.s(1'b0),
		.r(~resb & porb),
		.g(~wsftmb),
		.d(id[7:0]),
		.q(sft_l[15:8])
	);
	mlatch #(.WIDTH(6)) sft_hll(
		.clock(clk32),
		.s(1'b0),
		.r(~resb & porb),
		.g(~wsfthb),
		.d(id[5:0]),
		.q(sft_l[21:16])
	);
	wire sframe;
	always @(posedge clk32)
		if (~porb)
			sft <= 0;
		else if (~sframe)
			sft <= sft_l;
	always @(*) begin
		snd_o = 8'hff;
		if (~rsfblb)
			snd_o = {sfb[7:1], 1'b0};
		if (~rsfbmb)
			snd_o = sfb[15:8];
		if (~rsfbhb)
			snd_o = {2'b00, sfb[21:16]};
		if (~rscntlb)
			snd_o = {4'b0000, snd_ctrl, sndon};
		if (~rsftlb)
			snd_o = {sft[7:1], 1'b0};
		if (~rsftmb)
			snd_o = sft[15:8];
		if (~rsfthb)
			snd_o = {2'b00, sft[21:16]};
		if (~rsfclb)
			snd_o = {snd[7:1], 1'b0};
		if (~rsfcmb)
			snd_o = snd[15:8];
		if (~rsfchb)
			snd_o = {2'b00, snd[21:16]};
	end
	reg sndack;
	always @(posedge clk32 or posedge isndcsb) begin : sv2v_autoblock_1
		reg sndack1;
		if (isndcsb)
			{sndack, sndack1} <= 0;
		else if (MHZ8_EN1) begin
			sndack1 <= ~isndcsb;
			sndack <= sndack1;
		end
	end
	assign RDY_N_O = ~aso;
	wire ready = RDY_N_O & RDY_N_I;
	wire fcsackb;
	register fcsackb_r(
		.clock(clk32),
		.s(~(porb & ias)),
		.r(1'b0),
		.c(ready),
		.d(ifcsb),
		.q(fcsackb)
	);
	reg dtack_d;
	wire cmpcycb;
	wire ramcycb;
	wire dtack = ((((((((((sndack | ~ramcycb) | ~cmpcycb) | ~romxb) | ~regxackb) | cartsel) | syncsel) | butr) | joysel) | padr) | penr) | ~fcsackb;
	always @(posedge clk32 or negedge porb)
		if (!porb)
			dtack_d <= 0;
		else if (MHZ8_EN2)
			dtack_d <= dtack & ~DTACK_N_I;
	always @(posedge clk32 or negedge porb or negedge ixdma)
		if (!porb)
			{p8001_s, p8008_s, p8010_s} <= 3'b001;
		else if (!ixdma)
			{p8001_s, p8008_s, p8010_s} <= 3'b001;
		else if (MHZ8_EN1) begin
			p8001_s <= p8008_s;
			p8008_s <= p8001_s ^ ~((p8008_s & p8001_s) & ~dtack_d);
		end
		else if (MHZ8_EN2)
			p8010_s <= ~(p8001_s & p8008_s);
	assign DTACK_N_O = ~dtack;
	wire br_n = BR_N_I & BR_N_O;
	wire bgack_n = BGACK_N_I & BGACK_N_O;
	assign BGACK_N_O = ixdmab;
	reg br_o;
	assign BR_N_O = ~br_o;
	reg p9033;
	wire p9033_i = (ready & ~ias) | (p9033 & ias);
	wire ixdma_i = ixdma | (~ias & ~BG_N);
	wire br_o_i = (((br_n | br_o) & (BG_N | br_o)) & p9033) & bgack_n;
	always @(posedge clk32 or negedge porb or negedge resb)
		if (!porb || !resb) begin
			p9033 <= 0;
			br_o <= 0;
			ixdma <= 0;
		end
		else if (MHZ8_EN1) begin
			p9033 <= p9033_i;
			br_o <= br_o_i;
			if (!p9033_i)
				ixdma <= 0;
		end
		else if (MHZ8_EN2)
			ixdma <= ixdma_i;
	wire sela = rs2b & rs3b;
	wire [3:0] ramaaa = (sela ? {~ADDR[21] & ~ADDR[20], ~ADDR[19], ~ADDR[18], ~ADDR[17]} : {1'b1, ~ADDR[21], ~ADDR[20], ~ADDR[19]});
	wire ram1 = (((extra_ram & ((~ADDR[23] | ~ADDR[22]) | ((ADDR[23] & ADDR[22]) & ~ADDR[21]))) | viking_c0) | viking_e8) | (rs3b ? &ramaaa : ADDR[21]);
	wire ram2 = (rs3b ? ((ramaaa[3] & ramaaa[2]) & ramaaa[1]) & ~ramaaa[0] : ~ADDR[21]);
	wire clk4;
	wire ram1a;
	wire ram2a;
	wire udsl;
	wire ldsl;
	mlatch ram1a_l(
		.clock(clk32),
		.s(1'b0),
		.r(!porb),
		.g((turbo ? MHZ8 : clk4)),
		.d(ram1),
		.q(ram1a)
	);
	mlatch ram2a_l(
		.clock(clk32),
		.s(1'b0),
		.r(!porb),
		.g((turbo ? MHZ8 : clk4)),
		.d(ram2),
		.q(ram2a)
	);
	mlatch ldsl_l(
		.clock(clk32),
		.s(1'b0),
		.r(!porb),
		.g((turbo ? MHZ8 : clk4)),
		.d(ilds),
		.q(ldsl)
	);
	mlatch udsl_l(
		.clock(clk32),
		.s(1'b0),
		.r(!porb),
		.g((turbo ? MHZ8 : clk4)),
		.d(iuds),
		.q(udsl)
	);
	wire time0_s;
	wire time3_t;
	wire rascyc = (turbo ? ~time3_t : time0_s);
	wire vos;
	assign RAS0_N = ~(((rascyc & addrselb) & (~refb | (ram1a & vos))) | (((~rascyc & ~addrselb) & ram1a) & ~ramcycb));
	assign RAS1_N = ~(((rascyc & addrselb) & (~refb | (ram2a & vos))) | (((~rascyc & ~addrselb) & ram2a) & ~ramcycb));
	wire time7_s;
	wire lcycsel = (turbo ? time4_t : time7_s);
	wire time2_s;
	wire time2_t;
	wire time2 = (turbo ? time2_t : time2_s);
	assign CAS0L_N = ~((((time2 & ~lcycsel) & ram1a) & vos) | ((((~time2 & lcycsel) & ram1a) & ~ramcycb) & ldsl));
	assign CAS0H_N = ~((((time2 & ~lcycsel) & ram1a) & vos) | ((((~time2 & lcycsel) & ram1a) & ~ramcycb) & udsl));
	assign CAS1L_N = ~((((time2 & ~lcycsel) & ram2a) & vos) | ((((~time2 & lcycsel) & ram2a) & ~ramcycb) & ldsl));
	assign CAS1H_N = ~((((time2 & ~lcycsel) & ram2a) & vos) | ((((~time2 & lcycsel) & ram2a) & ~ramcycb) & udsl));
	wire time0_t;
	wire time0 = (turbo ? time0_t : time0_s);
	assign RAM_LDS = (((time0 & addrselb) & (ram1a | ram2a)) & vos) | ((((~time0 & ~addrselb) & (ram1a | ram2a)) & ~ramcycb) & ldsl);
	assign RAM_UDS = (((time0 & addrselb) & (ram1a | ram2a)) & vos) | ((((~time0 & ~addrselb) & (ram1a | ram2a)) & ~ramcycb) & udsl);
	wire clk;
	wire m2clock;
	wire m2clock_en_p;
	wire m2clock_en_n;
	wire time1_s;
	wire time3_s;
	wire time4_s;
	wire time6_s;
	wire latch_s;
	assign bus_cycle = {~time4_s, ~time0_s};
	assign CLK_O = clk;
	clockgen clockgen_s(
		.clk32(clk32),
		.clk(clk),
		.resb(resb),
		.porb(porb),
		.turbo(1'b0),
		.mhz8(MHZ8),
		.mhz8_en1(MHZ8_EN1),
		.mhz8_en2(MHZ8_EN2),
		.mhz4(MHZ4),
		.mhz4_en(MHZ4_EN),
		.clk4(clk4),
		.time0(time0_s),
		.time1(time1_s),
		.time2(time2_s),
		.time3(time3_s),
		.time4(time4_s),
		.time5(time5_s),
		.time6(time6_s),
		.time7(time7_s),
		.m2clock(m2clock),
		.m2clock_en_p(m2clock_en_p),
		.m2clock_en_n(m2clock_en_n),
		.latch(latch_s)
	);
	wire clk4_t;
	wire time1_t;
	wire time5_t;
	wire time6_t;
	wire time7_t;
	wire latch_t;
	clockgen clockgen_t(
		.clk32(clk32),
		.clk(),
		.resb(resb),
		.porb(porb),
		.turbo(1'b1),
		.mhz8(),
		.mhz8_en1(),
		.mhz8_en2(),
		.mhz4(),
		.mhz4_en(),
		.clk4(),
		.time0(time0_t),
		.time1(time1_t),
		.time2(time2_t),
		.time3(time3_t),
		.time4(time4_t),
		.time5(time5_t),
		.time6(time6_t),
		.time7(time7_t),
		.m2clock(),
		.m2clock_en_p(),
		.m2clock_en_n(),
		.latch(latch_t)
	);
	assign LATCH = (turbo ? latch_t : latch_s);
	wire time1 = (turbo ? time1_t : time1_s);
	wire time4 = (turbo ? time4_t : time4_s);
	wire cycsel_en = (turbo ? time3_t & ~time4_t : time6_s & ~time7_s);
	wire vidb;
	wire viden;
	wire sndclk_loc;
	wire sload_n_loc;
	wire dcyc_n_loc;
	wire ivsync = ~(iivsync & resb);
	wire ideb = ~DE;
	reg hde1;
	mcucontrol mcucontrol(
		.clk32(clk32),
		.porb(porb),
		.resb(resb),
		.turbo(turbo),
		.clk(clk),
		.ias(ias),
		.idev(idev),
		.iram(iram),
		.iuds(iuds),
		.ilds(ilds),
		.irwz(irwz),
		.ixdmab(ixdmab),
		.vmapb(vmapb),
		.smapb(smapb),
		.ivsync(ivsync),
		.ideb(ideb),
		.hde1(hde1),
		.addrselb(addrselb),
		.sreq(SREQ),
		.sndon(sndon),
		.lcycsel(lcycsel),
		.cycsel_en(cycsel_en),
		.time0(time0),
		.time1(time1),
		.frame(frame),
		.refb(refb),
		.vidb(vidb),
		.viden(viden),
		.vos(vos),
		.snd(snd),
		.sft(sft),
		.stoff(stoff),
		.sfrep(sfrep),
		.sframe(sframe),
		.sndclk(sndclk_loc),
		.snden(snden),
		.cmpcycb(cmpcycb),
		.ramcycb(ramcycb),
		.rdat_n(RDAT_N),
		.we_n(WE_N),
		.wdat_n(WDAT_N),
		.cmpcs_n(CMPCS_N),
		.dcyc_n(dcyc_n_loc),
		.sload_n(sload_n_loc),
		.sint(SINT)
	);
	wire vidclkb = (turbo ? ~(time0_s | vidb) : ~(time5_s | vidb));
	assign DCYC_N = dcyc_n_loc | (time5_s & turbo);
	wire sndclk = sndclk_loc | (time1_s & turbo);
	wire sndclk_en = (turbo ? ~time0_s & ~time7_s : addrselb & time4) & snden;
	assign SLOAD_N = sload_n_loc | (time1_s & turbo);
	wire interlace = 0;
	wire ihsync = ~(iihsync & resb);
	wire vertclk;
	reg [6:0] hsc;
	wire [6:0] hsc_load_val_ste = {mde1 | interlace, 2'b00, mde1, 1'b0, ntsc & ~mde1, ~(ntsc & ~mde1)};
	wire [6:0] hsc_load_val_st = (mde1 ? 7'h48 : (ntsc ? 7'h01 : 7'h00));
	reg hsc_load;
	wire hsc_reload = hsc == 7'd127;
	wire [6:0] ihsync_set = (mde1 ? 7'd121 : 7'd101);
	wire [6:0] ihsync_res = (mde1 ? 7'd127 : 7'd111);
	always @(posedge clk32 or negedge resb)
		if (!resb) begin
			hsc <= 0;
			hsc_load <= 0;
			iihsync <= 1;
		end
		else if (m2clock_en_p) begin
			hsc <= hsc + 1'd1;
			if (hsc_reload | hsc_load) begin
				hsc_load <= ~hsc_load;
				if (st & ~hsc_load)
					hsc <= hsc_load_val_st;
				if (~st)
					hsc <= hsc_load_val_ste;
			end
			if (hsc == ihsync_set)
				iihsync <= 0;
			if (hsc == ihsync_res)
				iihsync <= 1;
		end
	wire cpal = ~mde1 & ~ntsc;
	wire cntsc = ~mde1 & ntsc;
	reg [7:0] hdec;
	reg hblank;
	wire hblank_set = (cntsc & (hdec == 8'd8)) | (cpal & (hdec == 8'd9));
	wire hblank_reset = mde1 | (hdec == 8'd114);
	reg hde;
	wire hde_set_ste = ((cntsc & (hdec == 8'd11)) | (cpal & (hdec == 8'd12))) | (mde1 & (hdec == 8'd2));
	wire hde_set_st = ((cntsc & (hdec == 8'd15)) | (cpal & (hdec == 8'd16))) | (mde1 & (hdec == 8'd3));
	wire hde_reset = ((cntsc & (hdec == 8'd95)) | (cpal & (hdec == 8'd96))) | (mde1 & (hdec == 8'd43));
	reg hde_set_r1;
	reg hde_set_r2;
	reg hde_set_r3;
	reg hde_set_r4;
	always @(posedge clk32 or negedge porb)
		if (!porb) begin
			hdec <= 0;
			hblank <= 0;
			{hde_set_r1, hde_set_r2, hde_set_r3, hde_set_r4} <= 0;
			hde <= 0;
		end
		else if ((m2clock_en_p && (hsc == ihsync_set)) || ihsync) begin
			hdec <= 0;
			hblank <= 0;
			{hde_set_r1, hde_set_r2, hde_set_r3, hde_set_r4} <= 0;
			hde <= 0;
		end
		else if (m2clock_en_n) begin
			hdec <= hdec + 1'd1;
			if (hblank_set)
				hblank <= 1;
			if (hblank_reset)
				hblank <= 0;
			hde_set_r1 <= hde_set_ste;
			hde_set_r2 <= hde_set_r1;
			hde_set_r3 <= hde_set_r2;
			hde_set_r4 <= hde_set_r3;
			if (hde_reset)
				hde <= 0;
			else if ((~st && noscroll) && ((~mde1 & hde_set_r4) || (mde1 && hde_set_r1)))
				hde <= 1;
			else if ((~st && !noscroll) && ((~mde0 & hde_set_ste) || (mde0 && hde_set_r2)))
				hde <= 1;
			else if (st && hde_set_st)
				hde <= 1;
		end
	reg vblank;
	reg vde;
	always @(posedge clk32 or negedge porb)
		if (!porb) begin
			BLANK_N <= 1;
			hde1 <= 0;
			DE <= 1;
		end
		else if (m2clock_en_p) begin
			BLANK_N <= hblank & vblank;
			hde1 <= hde;
			DE <= hde & vde;
		end
	wire iivsync_a;
	wire vertclk_en = (st ? hsc_reload : hsc_load) & m2clock_en_p;
	reg [8:0] vsc;
	wire [8:0] vsc_load_val_ste = {1'b0, ~mde1, ~mde1, ~mde1 & ntsc, ~mde1 & ntsc, 1'b1, mde1, ~mde1 & ntsc, 1'b0};
	wire [8:0] vsc_load_val_st = (mde1 ? 9'd11 : (cpal ? 9'd199 : 9'd249));
	reg vsc_load;
	wire [8:0] ivsync_set = (mde1 ? 9'd510 : 9'd508);
	always @(posedge clk32 or negedge resb)
		if (!resb) begin
			vsc <= 0;
			vsc_load <= 1;
			iivsync <= 1;
		end
		else if (vertclk_en) begin
			vsc <= vsc + 1'd1;
			if (~st && ((vsc == 9'd511) || vsc_load)) begin
				vsc_load <= ~vsc_load;
				vsc <= vsc_load_val_ste;
				iivsync <= 1;
			end
			if (st && (vsc == 9'd511)) begin
				vsc <= vsc_load_val_st;
				iivsync <= 1;
			end
			if (vsc == ivsync_set)
				iivsync <= 0;
		end
	reg [8:0] vdec;
	wire vblank_set = (cpal & (vdec == 9'd24)) | (cntsc & (vdec == 9'd15));
	wire vblank_reset = (mde1 | (cpal & (vdec == 9'd307))) | (cntsc & (vdec == 9'd257));
	wire vde_set = ((mde1 & (vdec == 9'd35)) | (cpal & (vdec == 9'd62))) | (cntsc & (vdec == 9'd33));
	wire vde_reset = ((mde1 & (vdec == 9'd435)) | (cpal & (vdec == 9'd262))) | (cntsc & (vdec == 9'd233));
	always @(posedge clk32 or negedge porb)
		if (!porb) begin
			vdec <= 0;
			vde <= 0;
			vblank <= 0;
		end
		else if ((vertclk_en & (vsc == ivsync_set)) | ivsync) begin
			vdec <= 0;
			vde <= 0;
			vblank <= 0;
		end
		else if (m2clock_en_p && (hsc == ihsync_res)) begin
			vdec <= vdec + 1'd1;
			if (vde_set)
				vde <= 1;
			if (vde_reset)
				vde <= 0;
			if (vblank_set)
				vblank <= 1;
			if (vblank_reset)
				vblank <= 0;
		end
	reg vid_r_d;
	reg vidclk_d;
	reg vidb_d;
	reg pf071;
	reg pf071_reg;
	wire vid_r = pf071 & vidb;
	wire vid_xll = wloclb & frame;
	wire vid_xlm = wlocmb & frame;
	wire vid_xlh = wlochb & frame;
	wire vid_rr = ~((((!porb | !frame) | !wlochb) | !wlocmb) | !wloclb);
	always @(*) begin
		vid = vid_reg;
		if (~vid_r_d & vid_r)
			vid = vid + {15'd0, hoff};
		else if (~vidclk_d & ~vidclkb)
			vid = vid_reg + 1'd1;
		if (!vid_xll)
			vid[7:1] = vld[7:1];
		if (!vid_xlm)
			vid[15:8] = vld[15:8];
		if (!vid_xlh)
			vid[23:16] = vld[23:16];
		if (!extra_ram)
			vid[23:22] = 2'b00;
		pf071 = pf071_reg;
		if (!vid_rr)
			pf071 = 0;
		else if (~vidb_d & vidb)
			pf071 = 1;
	end
	always @(posedge clk32) begin
		vid_r_d <= vid_r;
		vidclk_d <= ~vidclkb;
		vid_reg <= vid;
		vidb_d <= vidb;
		pf071_reg <= pf071;
	end
	always @(posedge clk32)
		if (!(porb & resb))
			snd <= 0;
		else if (!sframe)
			snd <= sfb;
		else if (sndclk_en)
			snd <= snd + 1'd1;
	wire dmaclk = ~(dso & ixdma);
	reg [23:1] dmaa;
	reg dmaclk_d;
	always @(*) begin
		dmaa = dma_reg;
		if (~dmaclk_d & dmaclk)
			dmaa = dmaa + 1'd1;
		if (!wdmal)
			dmaa[7:1] = id[7:1];
		if (!wdmam)
			dmaa[15:8] = id[7:0];
		if (!wdmah)
			dmaa[23:16] = id[7:0];
		if (!extra_ram)
			dmaa[23:22] = 2'b00;
		if (~(resb & porb))
			dmaa = 0;
	end
	always @(posedge clk32) begin
		dmaclk_d <= dmaclk;
		dma_reg <= dmaa;
	end
	always @(*) begin
		dma_o = 8'hff;
		if (~rdmalb)
			dma_o = {dmaa[7:1], 1'b0};
		if (~rdmamb)
			dma_o = dmaa[15:8];
		if (~rdmahb)
			dma_o = dmaa[23:16];
	end
endmodule
