module HD63701_SCI (
	mcu_rst,
	mcu_clk,
	mcu_en,
	mcu_ad,
	mcu_wr,
	mcu_do,
	rx,
	tx,
	te,
	mcu_irq2_sci,
	en_sci,
	iod
);
	input mcu_rst;
	input mcu_clk;
	input mcu_en;
	input [15:0] mcu_ad;
	input mcu_wr;
	input [7:0] mcu_do;
	input rx;
	output reg tx;
	output wire te;
	output wire mcu_irq2_sci;
	output wire en_sci;
	output wire [7:0] iod;
	reg [7:0] RMCR;
	reg [7:0] TRCSR;
	reg [7:0] RDR;
	reg [7:0] TDR;
	reg RDRF;
	reg TDRE;
	reg ORFE;
	reg last_rx;
	reg [8:0] rxsr;
	reg [7:0] rxcnt;
	reg [11:0] txcnt;
	reg [8:0] txsr;
	reg clr_rd;
	reg clr_td;
	wire re = TRCSR[3];
	always @(posedge mcu_clk or posedge mcu_rst)
		if (mcu_rst) begin
			RMCR <= 8'h00;
			TRCSR <= 8'h00;
			RDR <= 8'h00;
			TDR <= 8'h00;
			TDRE <= 1'b1;
			RDRF <= 1'b0;
			ORFE <= 1'b0;
			clr_rd <= 1'b0;
			clr_td <= 1'b0;
			last_rx <= 1'b1;
			rxcnt <= 8'h00;
			txcnt <= 12'h000;
			rxsr <= 9'h1ff;
			txsr <= 9'h000;
			tx <= 1'b1;
		end
		else if (mcu_en) begin
			if (en_sci && !mcu_wr) begin
				if (mcu_ad == 16'h0011)
					{clr_rd, clr_td} <= 2'b11;
				if ((mcu_ad == 16'h0012) && clr_rd) begin
					RDRF <= 1'b0;
					ORFE <= 1'b0;
					clr_rd <= 1'b0;
				end
			end
			if (re) begin
				last_rx <= rx;
				rxcnt <= rxcnt + 8'd1;
				if (((rxsr == 9'h1ff) && last_rx) && !rx)
					rxcnt <= 8'h00;
				if (rxcnt == 8'd128) begin
					rxsr <= {rx, rxsr[8:1]};
					if (rxsr[0] == 1'b0) begin
						if (rx == 1'b1) begin
							rxsr <= 9'h1ff;
							if (RDRF == 1'b1)
								ORFE <= 1'b1;
							else
								RDR <= rxsr[8:1];
							RDRF <= 1'b1;
							clr_rd <= 1'b0;
						end
						else begin
							ORFE <= 1'b1;
							RDR <= rxsr[8:1];
						end
					end
				end
			end
			if (mcu_wr) begin
				if (mcu_ad == 16'h0010)
					RMCR <= mcu_do;
				if (mcu_ad == 16'h0011)
					TRCSR <= mcu_do;
				if (mcu_ad == 16'h0013) begin
					if (clr_td) begin
						TDRE <= 1'b0;
						clr_td <= 1'b0;
					end
					TDR <= mcu_do;
				end
			end
			txcnt <= txcnt + 12'd1;
			if (txcnt == 12'haff)
				txcnt <= 12'h000;
			if (txcnt[7:0] == 8'hff) begin
				if (((txsr == 9'h000) && !TDRE) && (txcnt == 12'haff)) begin
					TDRE <= 1'b1;
					txcnt <= 12'h000;
					txsr <= {1'b1, TDR};
					tx <= 1'b0;
					clr_td <= 1'b0;
				end
				if (txsr != 9'h000) begin
					tx <= txsr[0];
					txsr <= {1'b0, txsr[8:1]};
				end
			end
		end
	wire [7:0] TRCSR_O = {RDRF, ORFE, TDRE, TRCSR[4:1], 1'b0};
	wire wu = TRCSR[0];
	assign te = TRCSR[1];
	wire tie = TRCSR[2];
	wire rie = TRCSR[4];
	assign mcu_irq2_sci = (rie && (RDRF | ORFE)) || (tie && TDRE);
	assign en_sci = mcu_ad[15:2] == 14'h0004;
	assign iod = (mcu_ad == 16'h0010 ? RMCR : (mcu_ad == 16'h0011 ? TRCSR_O : (mcu_ad == 16'h0012 ? RDR : TDR)));
endmodule
