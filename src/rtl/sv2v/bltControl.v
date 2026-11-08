module bltControl (
	Clks,
	busy,
	Hog,
	extDmaReq,
	negIas,
	enS5,
	timeOut,
	rBltReset,
	XC2,
	XC1,
	OP,
	HOP,
	Smudge,
	Nfsr,
	Fxsr,
	skewWr,
	forceDestRd,
	busOe,
	updSrc,
	updDst,
	srcCycle,
	writeCycle,
	nxtLineCycle,
	xtraSrcCycle,
	dstLatchCycle,
	nfsrCycle,
	wantDma
);
	reg _sv2v_0;
	input wire [9:0] Clks;
	input busy;
	input Hog;
	input extDmaReq;
	input negIas;
	input enS5;
	input timeOut;
	input rBltReset;
	input XC2;
	input XC1;
	input [3:0] OP;
	input [1:0] HOP;
	input Smudge;
	input Nfsr;
	input Fxsr;
	input skewWr;
	input forceDestRd;
	output wire busOe;
	output wire updSrc;
	output wire updDst;
	output wire srcCycle;
	output wire writeCycle;
	output wire nxtLineCycle;
	output wire xtraSrcCycle;
	output wire dstLatchCycle;
	output wire nfsrCycle;
	output wire wantDma;
	reg [31:0] bltState;
	reg [31:0] next;
	reg [31:0] first;
	wire stopBlit = ((timeOut & !Hog) | extDmaReq) | !busy;
	wire haveRmDest = (forceDestRd | (OP[3] ^ OP[2])) | (OP[1] ^ OP[0]);
	wire skipNextSrc = (XC2 & (bltState == 32'd4)) & Nfsr;
	wire noOpSrc = (OP[2] == OP[0]) & (OP[3] == OP[1]);
	wire noHopSrc = !HOP[1] & !Smudge;
	wire noSrcRd = (skipNextSrc | noOpSrc) | noHopSrc;
	reg bltActive;
	assign busOe = bltActive;
	reg fxsrLatch;
	assign xtraSrcCycle = bltState == 32'd1;
	always @(posedge Clks[9])
		if (skewWr)
			fxsrLatch <= Fxsr;
		else if (negIas) begin
			if (bltActive & xtraSrcCycle)
				fxsrLatch <= 1'b0;
		end
		else if (((enS5 & updDst) & Fxsr) & XC1)
			fxsrLatch <= 1'b1;
	always @(posedge Clks[9] or negedge busy)
		if (!busy)
			bltActive <= 1'b0;
		else if (Clks[7])
			bltActive <= 1'b0;
		else if (negIas)
			bltActive <= !stopBlit;
	assign wantDma = (!stopBlit & busy) | bltActive;
	always @(*) begin
		if (_sv2v_0)
			;
		if (!noSrcRd)
			first = (fxsrLatch ? 32'd1 : 32'd2);
		else
			first = (haveRmDest ? 32'd3 : 32'd4);
		case (bltState)
			32'd0: next = (stopBlit ? 32'd0 : first);
			32'd1: next = (bltActive ? 32'd2 : 32'd1);
			32'd2: next = (bltActive ? (haveRmDest ? 32'd3 : 32'd4) : 32'd2);
			32'd3: next = (bltActive ? 32'd4 : 32'd3);
			32'd4: next = (bltActive ? first : 32'd4);
			default: next = 32'd0;
		endcase
	end
	always @(posedge Clks[9])
		if (Clks[7])
			bltState <= 32'd0;
		else if (rBltReset)
			bltState <= 32'd0;
		else if (negIas)
			bltState <= next;
	assign updSrc = bltActive & ((bltState == 32'd2) | (bltState == 32'd1));
	assign updDst = bltActive & (bltState == 32'd4);
	assign srcCycle = bltActive & ((bltState == 32'd2) | (bltState == 32'd1));
	assign nfsrCycle = ((bltActive & writeCycle) & Nfsr) & XC1;
	assign dstLatchCycle = bltActive & (bltState == 32'd3);
	assign writeCycle = bltState == 32'd4;
	assign nxtLineCycle = ((writeCycle & bltActive) & XC1) & negIas;
	initial _sv2v_0 = 0;
endmodule
