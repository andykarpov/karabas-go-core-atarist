module bltBusCtrl (
	Clks,
	wantDma,
	busOe,
	writeCycle,
	iBRn,
	iASn,
	BGIn,
	iBGACKn,
	BERRn,
	iDTACKn,
	oASn,
	oDSn,
	oRWn,
	oBRn,
	oBGACKn,
	BGOn,
	busOwned,
	extDmaReq,
	enIas,
	negIas,
	enS0,
	enS5
);
	reg _sv2v_0;
	input wire [9:0] Clks;
	input wantDma;
	input busOe;
	input writeCycle;
	input iBRn;
	input iASn;
	input BGIn;
	input iBGACKn;
	input BERRn;
	input iDTACKn;
	output reg oASn;
	output reg oDSn;
	output reg oRWn;
	output reg oBRn;
	output wire oBGACKn;
	output reg BGOn;
	output reg busOwned;
	output reg extDmaReq;
	output wire enIas;
	output wire negIas;
	output wire enS0;
	output wire enS5;
	reg [31:0] busState;
	reg rDtack;
	reg rBerr;
	always @(posedge Clks[9])
		if (Clks[3]) begin
			rDtack <= iDTACKn;
			rBerr <= BERRn;
		end
	wire busEnd = (!rBerr | !rDtack) | !busOe;
	always @(posedge Clks[9])
		if (Clks[7])
			busState <= 32'd0;
		else if (!busOwned)
			busState <= 32'd0;
		else if (Clks[4])
			case (busState)
				32'd0: busState <= 32'd1;
				32'd1: busState <= 32'd2;
				32'd2:
					if (busEnd)
						busState <= 32'd3;
				32'd3: busState <= 32'd0;
			endcase
	always @(posedge Clks[9])
		if (Clks[7] | !busOwned)
			{oASn, oDSn, oRWn} <= 1'sb1;
		else if (Clks[4]) begin
			if (busState == 32'd0)
				oASn <= 1'b0;
			if (((busState == 32'd0) & !writeCycle) | (busState == 32'd1))
				oDSn <= 1'b0;
			if (busState == 32'd0)
				oRWn <= !writeCycle;
			else if (busState == 32'd3)
				oRWn <= 1'b1;
		end
		else if (Clks[3]) begin
			if (busState == 32'd3)
				{oASn, oDSn} <= 1'sb1;
		end
	assign enIas = Clks[4] & (busState == 32'd0);
	assign negIas = Clks[3] & (busState == 32'd3);
	assign enS5 = Clks[3] & (busState == 32'd2);
	assign enS0 = Clks[4] & (busState == 32'd3);
	reg yieldState;
	wire rdyGranted = (!BGIn & iBGACKn) & iASn;
	wire canRequest = (((wantDma & iBRn) & iASn) & !yieldState) & !rdyGranted;
	reg [1:0] dmaState;
	reg [1:0] next;
	wire startYield = !iBRn & (dmaState == 2'd3);
	wire inYield = wantDma & yieldState;
	always @(*) begin
		if (_sv2v_0)
			;
		case (dmaState)
			2'd0: next = (canRequest ? 2'd1 : 2'd0);
			2'd1: next = (rdyGranted ? 2'd2 : 2'd1);
			2'd2: next = (wantDma ? 2'd3 : 2'd0);
			2'd3: next = (iBRn ? 2'd2 : 2'd0);
		endcase
	end
	always @(posedge Clks[9]) begin
		if (Clks[7])
			dmaState <= 2'd0;
		else if (Clks[4])
			dmaState <= next;
		if (Clks[7])
			yieldState <= 1'b0;
		else if (Clks[4])
			yieldState <= inYield | startYield;
	end
	wire dmaActive = ((dmaState == 2'd3) | ((dmaState == 2'd2) & wantDma)) | ((dmaState == 2'd1) & rdyGranted);
	always @(posedge Clks[9])
		if (Clks[7]) begin
			oBRn <= 1'b1;
			busOwned <= 1'b0;
			BGOn <= 1'b1;
		end
		else if (Clks[4]) begin
			oBRn <= !((dmaState == 2'd1) | ((dmaState == 2'd0) & canRequest));
			BGOn <= !((!BGIn & !yieldState) & (dmaState == 2'd0));
			busOwned <= inYield | dmaActive;
			extDmaReq <= yieldState | startYield;
		end
	assign oBGACKn = !busOwned;
	initial _sv2v_0 = 0;
endmodule
