module HD63701_SEQ (
	CLK,
	EN,
	RST,
	NMI,
	IRQ,
	IRQ2_SCI,
	IRQ2_TIM,
	DI,
	mcout,
	vect,
	inte,
	fncu
);
	input CLK;
	input EN;
	input RST;
	input NMI;
	input IRQ;
	input IRQ2_SCI;
	input IRQ2_TIM;
	input [7:0] DI;
	output wire [23:0] mcout;
	input [7:0] vect;
	input inte;
	output wire fncu;
	reg [7:0] opcode;
	reg [23:0] mcode;
	reg mcside;
	wire bIRQ = IRQ & inte;
	wire bIRQ2_TIM = IRQ2_TIM & inte;
	wire bIRQ2_SCI = IRQ2_SCI & inte;
	wire bINT = ((NMI | bIRQ) | bIRQ2_TIM) | bIRQ2_SCI;
	wire [7:0] vINT = (NMI ? 8'hfc : (bIRQ ? 8'hf8 : (bIRQ2_TIM ? 8'hf4 : (bIRQ2_SCI ? 8'hf0 : 0))));
	reg [5:0] PHASE;
	always @(posedge CLK or posedge RST)
		if (RST) begin
			opcode <= 0;
			mcode <= 0;
			mcside <= 0;
		end
		else if (EN)
			case (PHASE)
				0: mcside <= 1;
				1: mcside <= 1;
				16: begin
					opcode <= DI;
					if (bINT & (opcode[7:1] != 7'b0000111)) begin
						mcside <= 0;
						mcode <= {5'd25, vINT, 11'h030};
					end
					else
						mcside <= 1;
				end
				32: mcside <= 1;
				40: begin
					mcside <= 0;
					if (vect == 8'h00) begin
						if (bINT) begin
							mcode <= 24'h988190;
							opcode <= vINT;
						end
						else
							mcode <= 24'h000000;
					end
					else begin
						opcode <= vect;
						mcode <= 24'h988190;
					end
				end
				41: mcode <= {5'd31, opcode, 11'h04c};
				62: begin
					mcside <= 0;
					if (bINT)
						mcode <= {5'd25, vINT, 11'h030};
					else
						mcode <= 24'h000000;
				end
				default:
					;
			endcase
	wire [2:0] mcph = mcout[6:4];
	always @(negedge CLK or posedge RST)
		if (RST)
			PHASE <= 0;
		else if (EN)
			case (mcph)
				3'd1: PHASE <= PHASE + 6'h01;
				3'd2: PHASE <= 16;
				3'd3: PHASE <= 32;
				3'd4: PHASE <= 1;
				3'd6: PHASE <= 63;
				3'd7: PHASE <= 62;
				default: PHASE <= PHASE;
			endcase
	wire [23:0] mcoder;
	HD63701_MCROM mcr(
		.CLK(CLK),
		.EN(EN),
		.PHASE(PHASE),
		.OPCODE((PHASE == 16 ? DI : opcode)),
		.mcode(mcoder)
	);
	assign mcout = (mcside ? mcoder : mcode);
	assign fncu = (opcode[7:4] == 4'h2) | ((opcode[7:4] == 4'h3) & (opcode[3:0] != 4'hd));
endmodule
