module bltScore (
	Clks,
	SEL,
	iDBUS,
	rBltReset,
	updCycle,
	updDst,
	busOwned,
	enIas,
	XC1,
	XC2,
	wrWordSel,
	maskChanged,
	ramSel,
	ramWrSel,
	ramSelIdx,
	ramIdx,
	ramOut,
	OP,
	HOP,
	destBuf,
	srcbuf,
	lEndMask,
	cEndMask,
	rEndMask,
	forceDestRd,
	bltOut
);
	reg _sv2v_0;
	input wire [9:0] Clks;
	input [15:0] SEL;
	input [15:0] iDBUS;
	input rBltReset;
	input updCycle;
	input updDst;
	input busOwned;
	input enIas;
	input XC1;
	input XC2;
	input wrWordSel;
	input maskChanged;
	input ramSel;
	input ramWrSel;
	input [3:0] ramSelIdx;
	input [3:0] ramIdx;
	output wire [15:0] ramOut;
	input [3:0] OP;
	input [1:0] HOP;
	input [15:0] destBuf;
	input [15:0] srcbuf;
	input [15:0] lEndMask;
	input [15:0] cEndMask;
	input [15:0] rEndMask;
	output reg forceDestRd;
	output reg [15:0] bltOut;
	reg [15:0] mask;
	reg newLine;
	always @(posedge Clks[9])
		if (Clks[4] & rBltReset)
			newLine <= 1'b1;
		else if (updCycle & updDst)
			newLine <= XC1;
	always @(*) begin
		if (_sv2v_0)
			;
		if (newLine)
			mask = lEndMask;
		else if (XC1)
			mask = rEndMask;
		else
			mask = cEndMask;
	end
	reg [1:0] nxtMask;
	always @(posedge Clks[9])
		if (Clks[5]) begin
			forceDestRd <= 1'b0;
			nxtMask <= 1'sb0;
		end
		else if (Clks[4] & maskChanged)
			case (nxtMask)
				2'b00: forceDestRd <= !(&lEndMask);
				2'b01: forceDestRd <= !(&rEndMask);
				2'b10: forceDestRd <= !(&cEndMask);
			endcase
		else if (Clks[4] & rBltReset) begin
			forceDestRd <= !(&lEndMask);
			nxtMask <= 2'b00;
		end
		else if (updDst & enIas) begin
			if (XC1) begin
				forceDestRd <= !(&lEndMask);
				nxtMask <= 2'b00;
			end
			else if (XC2) begin
				forceDestRd <= !(&rEndMask);
				nxtMask <= 2'b01;
			end
			else begin
				forceDestRd <= !(&cEndMask);
				nxtMask <= 2'b10;
			end
		end
	reg [15:0] hRam [0:15];
	reg [15:0] rambuf;
	reg [3:0] lRamIdx;
	always @(*) begin
		if (_sv2v_0)
			;
		lRamIdx = (busOwned ? ramIdx : ramSelIdx);
	end
	assign ramOut = rambuf;
	always @(posedge Clks[9])
		if (!busOwned) begin
			if (Clks[4] & ramWrSel)
				hRam[lRamIdx] <= iDBUS;
			else if (ramSel & Clks[3])
				rambuf <= hRam[lRamIdx];
		end
		else if (enIas)
			rambuf <= hRam[lRamIdx];
	reg [15:0] nHop;
	reg [15:0] nQop;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < 16; i = i + 1)
				begin
					nHop[i] = (~srcbuf[i] & HOP[1]) | (~rambuf[i] & HOP[0]);
					nQop[i] = ((((!OP[3] & nHop[i]) & ~destBuf[i]) | ((!OP[2] & nHop[i]) & destBuf[i])) | ((!OP[1] & ~nHop[i]) & ~destBuf[i])) | ((!OP[0] & ~nHop[i]) & destBuf[i]);
					bltOut[i] = (mask[i] ? ~nQop[i] : destBuf[i]);
				end
		end
	end
	initial _sv2v_0 = 0;
endmodule
