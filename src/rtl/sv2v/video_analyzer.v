module video_analyzer (
	clk,
	hs,
	vs,
	de,
	screen,
	mode,
	vreset
);
	input clk;
	input hs;
	input vs;
	input de;
	input [1:0] screen;
	output reg [1:0] mode;
	output reg vreset;
	reg vsD;
	reg hsD;
	reg [12:0] hcnt;
	reg [12:0] hcntL;
	reg [9:0] vcnt;
	reg [9:0] vcntL;
	reg changed;
	reg [1:0] screenL;
	always @(posedge clk) begin
		hsD <= hs;
		if (screen != screenL) begin
			changed <= 1'b1;
			screenL <= screen;
		end
		if (!hs && hsD) begin
			hcntL <= hcnt;
			if (hcntL != hcnt)
				changed <= 1'b1;
			hcnt <= 0;
		end
		else
			hcnt <= hcnt + 13'd1;
		if (!hs && hsD) begin
			vsD <= vs;
			if (!vs && vsD) begin
				vcntL <= vcnt;
				if (vcntL != vcnt)
					changed <= 1'b1;
				vcnt <= 0;
				if ((vcnt == 10'd312) && (hcntL == 13'd2047))
					mode <= 2'd1;
				if ((vcnt == 10'd262) && (hcntL == 13'd2031))
					mode <= 2'd0;
				if ((vcnt == 10'd500) && (hcntL == 13'd895))
					mode <= 2'd2;
			end
			else
				vcnt <= vcnt + 10'd1;
		end
		vreset <= 1'b0;
		if ((((((hcnt == (screen == 2'd2 ? 204 : 244)) && (vcnt == 36)) && changed) && (mode == 2'd2)) || ((((hcnt == (screen == 2'd2 ? 121 : (screen == 2'd0 ? 222 : 161))) && (vcnt == 26)) && changed) && (mode == 2'd1))) || ((((hcnt == (screen == 2'd2 ? 121 : (screen == 2'd0 ? 214 : 161))) && (vcnt == 18)) && changed) && (mode == 2'd0))) begin
			vreset <= 1'b1;
			changed <= 1'b0;
		end
	end
endmodule
