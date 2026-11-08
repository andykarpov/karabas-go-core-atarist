module stBlitter (
	clk,
	aRESETn,
	pwrUp,
	enPhi1,
	enPhi2,
	ASn,
	RWn,
	LDSn,
	UDSn,
	FC0,
	FC1,
	FC2,
	BERRn,
	iDTACKn,
	ctrlOe,
	dataOe,
	oASn,
	oDSn,
	oRWn,
	oDTACKn,
	selected,
	iBRn,
	BGIn,
	iBGACKn,
	oBRn,
	oBGACKn,
	INTn,
	BGOn,
	dmaInput,
	iABUS,
	oABUS,
	iDBUS,
	oDBUS
);
	reg _sv2v_0;
	input clk;
	input aRESETn;
	input pwrUp;
	input enPhi1;
	input enPhi2;
	input ASn;
	input RWn;
	input LDSn;
	input UDSn;
	input FC0;
	input FC1;
	input FC2;
	input BERRn;
	input iDTACKn;
	output wire ctrlOe;
	output wire dataOe;
	output wire oASn;
	output wire oDSn;
	output wire oRWn;
	output wire oDTACKn;
	output wire selected;
	input iBRn;
	input BGIn;
	input iBGACKn;
	output wire oBRn;
	output wire oBGACKn;
	output wire INTn;
	output wire BGOn;
	input [15:0] dmaInput;
	input [23:1] iABUS;
	output wire [23:1] oABUS;
	input [15:0] iDBUS;
	output wire [15:0] oDBUS;
	wire [9:0] Clks;
	assign Clks[9] = clk;
	assign Clks[8] = aRESETn;
	assign Clks[7] = pwrUp | !aRESETn;
	assign Clks[5] = pwrUp;
	assign Clks[4] = enPhi1;
	assign Clks[3] = enPhi2;
	assign Clks[2] = enPhi2 | enPhi1;
	assign {Clks[6], Clks[1], Clks[0]} = 3'b000;
	wire blitSpace = {iABUS[23:6], 6'b000000} == 24'hff8a00;
	assign selected = (({FC2, FC1, FC0} == 3'b101) & !ASn) & blitSpace;
	wire wrWordSel = ((selected & !RWn) & !LDSn) & !UDSn;
	wire ramWrSel = wrWordSel & !iABUS[5];
	wire ramSel = selected & !iABUS[5];
	reg [15:0] SEL;
	always @(*) begin : sv2v_autoblock_1
		reg [4:1] iSel;
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < 16; i = i + 1)
				begin
					iSel = i;
					SEL[i] = (selected & iABUS[5]) & (iABUS[4:1] == iSel);
				end
		end
	end
	assign oDTACKn = !selected;
	wire [15:0] ramOut;
	wire busOwned;
	wire extDmaReq;
	wire enIas;
	wire negIas;
	wire enS0;
	wire enS5;
	wire rBltReset;
	wire wantDma;
	wire updSrc;
	wire updDst;
	wire writeCycle;
	wire srcCycle;
	wire xtraSrcCycle;
	wire nxtLineCycle;
	wire nfsrCycle;
	wire busOe;
	assign ctrlOe = busOe;
	wire XC1;
	wire XC2;
	wire XYZ;
	wire Direction;
	wire IncSign;
	wire forceDestRd;
	wire updCycle = negIas;
	reg [15:0] dbusLatch;
	always @(posedge Clks[9])
		if (negIas)
			dbusLatch <= dmaInput;
	reg rBusy;
	reg [3:0] OP;
	reg [1:0] HOP;
	reg [3:0] Skew;
	reg [3:0] LineCtr;
	reg Fxsr;
	reg Nfsr;
	reg Smudge;
	reg Hog;
	reg [15:1] srcXincr;
	reg [15:1] srcYincr;
	reg [15:1] dstXincr;
	reg [15:1] dstYincr;
	reg [15:0] lEndMask;
	reg [15:0] cEndMask;
	reg [15:0] rEndMask;
	wire [23:1] srcAddr;
	wire [23:1] dstAddr;
	wire [15:0] xCounter;
	wire [15:0] yCounter;
	wire [15:0] bltOut;
	wire [15:0] skewed;
	wire csRdSel = (selected & RWn) & (!LDSn | !UDSn);
	reg [15:0] ioOut;
	always @(*) begin
		if (_sv2v_0)
			;
		case (iABUS[4:1])
			4'h0: ioOut = {srcXincr, 1'b0};
			4'h1: ioOut = {srcYincr, 1'b0};
			4'h2: ioOut = {8'h00, srcAddr[23:16]};
			4'h3: ioOut = {srcAddr[15:1], 1'b0};
			4'h4: ioOut = lEndMask;
			4'h5: ioOut = cEndMask;
			4'h6: ioOut = rEndMask;
			4'h7: ioOut = {dstXincr, 1'b0};
			4'h8: ioOut = {dstYincr, 1'b0};
			4'h9: ioOut = {8'h00, dstAddr[23:16]};
			4'ha: ioOut = {dstAddr[15:1], 1'b0};
			4'hb: ioOut = xCounter;
			4'hc: ioOut = yCounter;
			4'hd: ioOut = {6'h00, HOP, 4'h0, OP};
			4'he: ioOut = {rBusy, Hog, Smudge, 1'b0, LineCtr, Fxsr, Nfsr, 2'b00, Skew};
			4'hf: ioOut = 1'sb0;
		endcase
	end
	assign oDBUS = (csRdSel ? (iABUS[5] ? ioOut : ramOut) : bltOut);
	assign dataOe = csRdSel | (busOwned & writeCycle);
	localparam REG_00 = 0;
	localparam REG_02 = 1;
	localparam REG_08 = 4;
	localparam REG_0A = 5;
	localparam REG_0C = 6;
	localparam REG_0E = 7;
	localparam REG_10 = 8;
	always @(posedge Clks[9])
		if (Clks[5]) begin
			{srcXincr, srcYincr} <= 1'sb0;
			{dstXincr, dstYincr} <= 1'sb0;
			lEndMask <= 1'sb0;
			cEndMask <= 1'sb0;
			rEndMask <= 1'sb0;
		end
		else if (Clks[4] & wrWordSel) begin
			if (SEL[REG_00])
				srcXincr <= iDBUS[15:1];
			if (SEL[REG_02])
				srcYincr <= iDBUS[15:1];
			if (SEL[REG_0E])
				dstXincr <= iDBUS[15:1];
			if (SEL[REG_10])
				dstYincr <= iDBUS[15:1];
			if (SEL[REG_08])
				lEndMask <= iDBUS;
			if (SEL[REG_0A])
				cEndMask <= iDBUS;
			if (SEL[REG_0C])
				rEndMask <= iDBUS;
		end
	reg maskChanged;
	always @(posedge Clks[9])
		if (Clks[4])
			maskChanged <= wrWordSel & ((SEL[REG_08] | SEL[REG_0A]) | SEL[REG_0C]);
	wire [3:0] ramIdx;
	localparam REG_1C = 14;
	wire ctrlWr = (SEL[REG_1C] & !RWn) & !UDSn;
	wire busyMask = !ctrlWr;
	wire busy = rBusy & busyMask;
	assign INTn = busy;
	always @(posedge Clks[9] or posedge XYZ)
		if (XYZ)
			{rBusy, Hog} <= 1'sb0;
		else if (Clks[7])
			{rBusy, Hog} <= 1'sb0;
		else if (Clks[4]) begin
			if ((SEL[REG_1C] & !RWn) & !UDSn) begin
				rBusy <= iDBUS[15];
				Hog <= iDBUS[14];
			end
		end
	always @(posedge Clks[9])
		if (Clks[5])
			{Smudge, LineCtr} <= 1'sb0;
		else if (Clks[4] & ctrlWr) begin
			LineCtr <= iDBUS[11:8];
			Smudge <= iDBUS[13];
		end
		else if (nxtLineCycle)
			LineCtr <= (IncSign ? LineCtr - 1'b1 : LineCtr + 1'b1);
	assign ramIdx = (Smudge ? skewed[3:0] : LineCtr);
	reg skewWr;
	localparam REG_1A = 13;
	always @(posedge Clks[9]) begin
		if (Clks[5])
			{HOP, OP, Fxsr, Nfsr, Skew} <= 1'sb0;
		else if (Clks[4] & !RWn) begin
			if (SEL[REG_1A] & !UDSn)
				HOP <= iDBUS[9:8];
			if (SEL[REG_1A] & !LDSn)
				OP <= iDBUS[3:0];
			if (SEL[REG_1C] & !LDSn) begin
				{Fxsr, Nfsr} <= iDBUS[7:6];
				Skew <= iDBUS[3:0];
			end
		end
		if (Clks[5])
			skewWr <= 1'sb0;
		else if (Clks[4])
			skewWr <= (SEL[REG_1C] & !LDSn) & !RWn;
	end
	reg [6:0] tmoCntr;
	wire timeOut = tmoCntr[6];
	reg prevAs;
	always @(posedge Clks[9]) begin
		if (Clks[2])
			prevAs <= ASn;
		if (Clks[2]) begin
			if (!busy)
				tmoCntr <= 1'sb0;
			else if (!ASn & prevAs)
				tmoCntr <= tmoCntr + 1'b1;
		end
	end
	reg [31:0] skewRegs = 1'sb0;
	reg [15:0] destBuf = 1'sb0;
	wire dstLatchCycle;
	always @(posedge Clks[9]) begin
		if (negIas & dstLatchCycle)
			destBuf <= dmaInput;
		if (negIas & srcCycle)
			skewRegs <= (!Direction ? {skewRegs[15:0], dmaInput} : {dmaInput, skewRegs[31:16]});
		else if (enS0 & nfsrCycle)
			skewRegs <= (!Direction ? {skewRegs[15:0], dbusLatch} : {dbusLatch, skewRegs[31:16]});
		else if (negIas & nfsrCycle)
			skewRegs <= (!Direction ? {skewRegs[15:0], bltOut} : {bltOut, skewRegs[31:16]});
	end
	assign skewed = skewRegs >> Skew;
	bltControl bltControl(
		.Clks(Clks),
		.busy(busy),
		.Hog(Hog),
		.negIas(negIas),
		.enS5(enS5),
		.extDmaReq(extDmaReq),
		.timeOut(timeOut),
		.rBltReset(rBltReset),
		.XC2(XC2),
		.XC1(XC1),
		.OP(OP),
		.HOP(HOP),
		.Smudge(Smudge),
		.Nfsr(Nfsr),
		.Fxsr(Fxsr),
		.skewWr(skewWr),
		.forceDestRd(forceDestRd),
		.busOe(busOe),
		.updSrc(updSrc),
		.updDst(updDst),
		.srcCycle(srcCycle),
		.writeCycle(writeCycle),
		.nxtLineCycle(nxtLineCycle),
		.xtraSrcCycle(xtraSrcCycle),
		.nfsrCycle(nfsrCycle),
		.dstLatchCycle(dstLatchCycle),
		.wantDma(wantDma)
	);
	bltBusCtrl bltBusCtrl(
		.Clks(Clks),
		.busOe(busOe),
		.wantDma(wantDma),
		.iBRn(iBRn),
		.BGIn(BGIn),
		.iBGACKn(iBGACKn),
		.iASn(ASn),
		.BERRn(BERRn),
		.iDTACKn(iDTACKn),
		.busOwned(busOwned),
		.extDmaReq(extDmaReq),
		.enIas(enIas),
		.negIas(negIas),
		.enS0(enS0),
		.enS5(enS5),
		.writeCycle(writeCycle),
		.oASn(oASn),
		.oDSn(oDSn),
		.oRWn(oRWn),
		.oBRn(oBRn),
		.oBGACKn(oBGACKn),
		.BGOn(BGOn)
	);
	bltCounters bltCounters(
		.Clks(Clks),
		.SEL(SEL),
		.wrWordSel(wrWordSel),
		.busOwned(busOwned),
		.updSrc(updSrc),
		.updDst(updDst),
		.updCycle(updCycle),
		.srcCycle(srcCycle),
		.xtraSrcCycle(xtraSrcCycle),
		.Nfsr(Nfsr),
		.srcXincr(srcXincr),
		.srcYincr(srcYincr),
		.dstXincr(dstXincr),
		.dstYincr(dstYincr),
		.srcAddr(srcAddr),
		.dstAddr(dstAddr),
		.xCounter(xCounter),
		.yCounter(yCounter),
		.XC1(XC1),
		.XC2(XC2),
		.XYZ(XYZ),
		.rBltReset(rBltReset),
		.Direction(Direction),
		.IncSign(IncSign),
		.iDBUS(iDBUS),
		.oABUS(oABUS)
	);
	bltScore bltScore(
		.Clks(Clks),
		.SEL(SEL),
		.iDBUS(iDBUS),
		.OP(OP),
		.HOP(HOP),
		.destBuf(destBuf),
		.srcbuf(skewed),
		.rBltReset(rBltReset),
		.updCycle(updCycle),
		.updDst(updDst),
		.busOwned(busOwned),
		.enIas(enIas),
		.XC1(XC1),
		.XC2(XC2),
		.wrWordSel(wrWordSel),
		.maskChanged(maskChanged),
		.lEndMask(lEndMask),
		.cEndMask(cEndMask),
		.rEndMask(rEndMask),
		.ramSel(ramSel),
		.ramWrSel(ramWrSel),
		.ramSelIdx(iABUS[4:1]),
		.ramIdx(ramIdx),
		.ramOut(ramOut),
		.forceDestRd(forceDestRd),
		.bltOut(bltOut)
	);
	initial _sv2v_0 = 0;
endmodule
