module bltCounters (
	Clks,
	SEL,
	wrWordSel,
	busOwned,
	updCycle,
	srcCycle,
	xtraSrcCycle,
	updSrc,
	updDst,
	Nfsr,
	srcXincr,
	srcYincr,
	dstXincr,
	dstYincr,
	xCounter,
	yCounter,
	srcAddr,
	dstAddr,
	XC1,
	XC2,
	XYZ,
	rBltReset,
	Direction,
	IncSign,
	iDBUS,
	oABUS
);
	reg _sv2v_0;
	input wire [9:0] Clks;
	input [15:0] SEL;
	input wrWordSel;
	input busOwned;
	input updCycle;
	input srcCycle;
	input xtraSrcCycle;
	input updSrc;
	input updDst;
	input Nfsr;
	input [15:1] srcXincr;
	input [15:1] srcYincr;
	input [15:1] dstXincr;
	input [15:1] dstYincr;
	output reg [15:0] xCounter;
	output reg [15:0] yCounter;
	output reg [23:1] srcAddr;
	output reg [23:1] dstAddr;
	output wire XC1;
	output wire XC2;
	output reg XYZ;
	output reg rBltReset;
	output wire Direction;
	output wire IncSign;
	input [15:0] iDBUS;
	output wire [23:1] oABUS;
	localparam REG_18 = 12;
	wire yCntWr = SEL[REG_18] & wrWordSel;
	reg [15:0] xStart;
	wire YC1 = yCounter == 16'h0001;
	assign XC1 = xCounter == 16'h0001;
	assign XC2 = xCounter == 16'h0002;
	always @(posedge Clks[9])
		if (Clks[7])
			XYZ <= 1'b0;
		else if (Clks[4] & rBltReset)
			XYZ <= 1'b0;
		else if (updCycle & updDst)
			XYZ <= XC1 & YC1;
	always @(posedge Clks[9])
		if (Clks[5])
			rBltReset <= 1'b0;
		else if (Clks[4])
			rBltReset <= yCntWr;
	localparam REG_16 = 11;
	always @(posedge Clks[9])
		if (Clks[5]) begin
			xCounter <= 1'sb0;
			yCounter <= 1'sb0;
		end
		else if (busOwned) begin
			if (updCycle & updDst) begin
				if (XC1) begin
					yCounter <= yCounter - 1'b1;
					xCounter <= xStart;
				end
				else
					xCounter <= xCounter - 1'b1;
			end
		end
		else if (Clks[4]) begin
			if (wrWordSel) begin
				if (SEL[REG_16]) begin
					xCounter <= iDBUS[15:0];
					xStart <= iDBUS[15:0];
				end
				if (SEL[REG_18])
					yCounter <= iDBUS[15:0];
			end
		end
	wire [15:1] dstIncr = (!XC1 ? dstXincr : dstYincr);
	wire [23:1] extDstIncr = {{8 {dstIncr[15]}}, dstIncr[15:1]};
	reg isX;
	always @(*) begin
		if (_sv2v_0)
			;
		if (xtraSrcCycle)
			isX = 1'b1;
		else if (XC1 | (XC2 & Nfsr))
			isX = 1'b0;
		else
			isX = 1'b1;
	end
	wire [15:1] srcIncr = (isX ? srcXincr : srcYincr);
	wire [23:1] extSrcIncr = {{8 {srcIncr[15]}}, srcIncr[15:1]};
	assign Direction = srcXincr[15];
	assign IncSign = dstYincr[15];
	localparam REG_04 = 2;
	localparam REG_06 = 3;
	localparam REG_12 = 9;
	localparam REG_14 = 10;
	always @(posedge Clks[9])
		if (Clks[5]) begin
			srcAddr <= 1'sb0;
			dstAddr <= 1'sb0;
		end
		else if (busOwned) begin
			if (updCycle) begin
				if (updSrc)
					srcAddr <= srcAddr + extSrcIncr;
				if (updDst)
					dstAddr <= dstAddr + extDstIncr;
			end
		end
		else if (Clks[4]) begin
			if (wrWordSel) begin
				if (SEL[REG_04])
					srcAddr[23:16] <= iDBUS[7:0];
				if (SEL[REG_06])
					srcAddr[15:1] <= iDBUS[15:1];
				if (SEL[REG_12])
					dstAddr[23:16] <= iDBUS[7:0];
				if (SEL[REG_14])
					dstAddr[15:1] <= iDBUS[15:1];
			end
		end
	assign oABUS = (srcCycle ? srcAddr : dstAddr);
	initial _sv2v_0 = 0;
endmodule
