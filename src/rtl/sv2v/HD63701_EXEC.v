module HD63701_EXEC (
	CLK,
	EN,
	EN2,
	RST,
	DI,
	AD,
	RW,
	DO,
	mcode,
	vect,
	inte,
	fncu
);
	input CLK;
	input EN;
	input EN2;
	input RST;
	input [7:0] DI;
	output wire [15:0] AD;
	output wire RW;
	output reg [7:0] DO;
	input [23:0] mcode;
	output reg [7:0] vect;
	output wire inte;
	input fncu;
	wire mcpi = mcode[0];
	wire [2:0] mcam = mcode[3:1];
	wire [2:0] mcph = mcode[6:4];
	wire [3:0] mcr2 = mcode[10:7];
	wire [3:0] mcr1 = mcode[14:11];
	wire [3:0] mcr0 = mcode[18:15];
	wire [4:0] mcop = mcode[23:19];
	wire mcnw = ((((mcop == 5'd18) | (mcop == 5'd19)) | (mcop == 5'd30)) | (mcop == 5'd31)) | (mcop == 5'd25);
	wire [7:0] mccf = {mcr0, mcr1};
	wire [7:0] mcva = {mcr0, mcr1};
	reg [15:0] rT;
	reg [15:0] rE;
	reg [15:0] rD;
	reg [15:0] rX;
	reg [15:0] rS;
	reg [15:0] rSp;
	reg [15:0] rP;
	reg [5:0] rC;
	wire IsCCR = (mcop == 5'd18) | (mcop == 5'd19);
	wire IsCChit = (({rC[1] ^ rC[3], rC} & mccf[6:0]) == 7'h00) ^ mccf[7];
	wire [15:0] R0;
	wire [15:0] R1;
	wire [15:0] RR;
	wire [5:0] CC;
	HD63701_DSEL13 sR0(
		.o(R0),
		.f0((mcr0 == 4'd3) | IsCCR),
		.d0({10'b0000000011, rC}),
		.f1(mcr0 == 4'd1),
		.d1({8'h00, rD[15:8]}),
		.f2(mcr0 == 4'd2),
		.d2({8'h00, rD[7:0]}),
		.f3(mcr0 == 4'd4),
		.d3(rD),
		.f4(mcr0 == 4'd5),
		.d4(rX),
		.f5(mcr0 == 4'd6),
		.d5(rS),
		.f6(mcr0 == 4'd7),
		.d6(rP),
		.f7(mcr0 == 4'd8),
		.d7({8'h00, rT[15:8]}),
		.f8(mcr0 == 4'd9),
		.d8({8'h00, rT[7:0]}),
		.f9(mcr0 == 4'd10),
		.d9({DI, 8'h00}),
		.fA(mcr0 == 4'd11),
		.dA({8'h00, DI}),
		.fB(mcr0 == 4'd12),
		.dB(rT),
		.fC(mcr0 == 4'd13),
		.dC(rE)
	);
	HD63701_DSEL13 sR1(
		.o(R1),
		.f0((mcr1 == 4'd3) | IsCCR),
		.d0({10'b0000000011, rC}),
		.f1(mcr1 == 4'd1),
		.d1({8'h00, rD[15:8]}),
		.f2(mcr1 == 4'd2),
		.d2({8'h00, rD[7:0]}),
		.f3(mcr1 == 4'd4),
		.d3(rD),
		.f4(mcr1 == 4'd5),
		.d4(rX),
		.f5(mcr1 == 4'd6),
		.d5(rS),
		.f6(mcr1 == 4'd7),
		.d6(rP),
		.f7(mcr1 == 4'd8),
		.d7({8'h00, rT[15:8]}),
		.f8(mcr1 == 4'd9),
		.d8({8'h00, rT[7:0]}),
		.f9(mcr1 == 4'd10),
		.d9({DI, 8'h00}),
		.fA(mcr1 == 4'd11),
		.dA({8'h00, DI}),
		.fB(mcr1 == 4'd12),
		.dB(rT),
		.fC(mcr1 == 4'd13),
		.dC(rE)
	);
	HD63701_ALU ALU(
		.op(mcop),
		.cf(mccf),
		.bw((mcr2 == 4'd0 ? mcr0[2] : mcr2[2])),
		.R0(R0),
		.R1(R1),
		.C(rC[0]),
		.RR(RR),
		.RC(CC)
	);
	HD63701_DSEL8 sAB(
		.o(AD),
		.f0(mcam == 3'd0),
		.d0(rP),
		.f1(mcam == 3'd1),
		.d1(rP + 16'h0001),
		.f2(mcam == 3'd2),
		.d2(rS),
		.f3(mcam == 3'd3),
		.d3(rS + 16'h0001),
		.f4(mcam == 3'd4),
		.d4(rX),
		.f5(mcam == 3'd5),
		.d5(rX + rT),
		.f6(mcam == 3'd6),
		.d6(rE),
		.f7(mcam == 3'd7),
		.d7(rE + 16'h0001)
	);
	reg [4:0] pmcop;
	always @(posedge CLK)
		if (EN) begin
			if (pmcop == 5'd26)
				rS <= rSp - 16'h0001;
			else if (pmcop == 5'd27)
				rS <= rSp + 16'h0001;
			else
				rS <= rSp;
		end
	wire noCCop = ((((((mcop != 5'd31) & (mcop != 5'd0)) & (mcop != 5'd26)) & (mcop != 5'd27)) & (mcop != 5'd30)) & (mcop != 5'd21)) & ~fncu;
	wire noCCrg = (((mcr2 != 4'd3) & (mcr2 != 4'd6)) & (mcr2 != 4'd7)) & (mcr0 != 4'd3);
	always @(posedge CLK or posedge RST)
		if (RST) begin
			pmcop <= 0;
			vect <= 0;
			rT <= 0;
			rE <= 0;
			rP <= 0;
			rC <= 6'b010000;
			DO <= 0;
		end
		else if (EN2) begin
			if ((mcr2 != 4'd7) & (mcpi == 1'b1))
				rP <= rP + 16'h0001;
			if (noCCrg & noCCop)
				rC <= {CC[5], rC[4], CC[3:0]};
			if (mcr2 != 4'd6)
				rSp <= rS;
			case (mcop)
				5'd28: begin
					rT <= rX;
					rX <= rD;
				end
				5'd30:
					if (IsCChit)
						rP <= rP + {{8 {rT[7]}}, rT[7:0]};
				5'd25: vect <= mcva;
				5'd31: rE <= {8'hff, mcva};
				5'd21: rC <= {rC[5:4], CC[3:2], rC[1:0]};
				default:
					case (mcr2)
						4'd1: rD[15:8] <= RR[7:0];
						4'd2: rD[7:0] <= RR[7:0];
						4'd3: rC <= RR[5:0];
						4'd4: rD <= RR;
						4'd5: rX <= RR;
						4'd6: rSp <= RR;
						4'd7: rP <= RR;
						4'd8: rT[15:8] <= RR[7:0];
						4'd9: rT[7:0] <= RR[7:0];
						4'd12: rT <= RR;
						4'd13: rE <= RR;
						default:
							;
					endcase
			endcase
			DO <= (mcnw ? 8'h00 : (mcr2 == 4'd10 ? RR[15:8] : (mcr2 == 4'd11 ? RR[7:0] : 8'h00)));
			pmcop <= mcop;
		end
	reg CLK_PH;
	always @(posedge CLK) begin
		if (EN)
			CLK_PH <= 1'b1;
		if (EN2)
			CLK_PH <= 1'b0;
	end
	assign RW = (!CLK_PH & ((mcr2 == 4'd10) | (mcr2 == 4'd11))) & ~mcnw;
	assign inte = ~rC[4];
endmodule
