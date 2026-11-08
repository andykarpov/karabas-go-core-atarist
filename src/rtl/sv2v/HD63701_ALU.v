module HD63701_ALU (
	op,
	cf,
	bw,
	R0,
	R1,
	C,
	RR,
	RC
);
	input [4:0] op;
	input [7:0] cf;
	input bw;
	input [15:0] R0;
	input [15:0] R1;
	input C;
	output wire [15:0] RR;
	output wire [5:0] RC;
	wire [16:0] r = (op == 5'd21 ? {1'b0, R0} : (op == 5'd20 ? {1'b0, R0} : (op == 5'd0 ? {1'b0, R0} : (op == 5'd26 ? {1'b0, R0} : (op == 5'd27 ? {1'b0, R0} : (op == 5'd25 ? {1'b0, R0} : (op == 5'd29 ? {1'b0, R0} : (op == 5'd1 ? R0 + 16'h0001 : (op == 5'd2 ? R0 + R1 : (op == 5'd3 ? (R0 + R1) + {15'd0, C} : (op == 5'd4 ? R0 - 16'h0001 : (op == 5'd5 ? R0 - R1 : (op == 5'd6 ? (R0 - R1) - {15'd0, C} : (op == 5'd7 ? R0 * R1 : (op == 5'd8 ? {1'b0, ~R0} + 17'h00001 : (op == 5'd9 ? {1'b0, ~R0} : (op == 5'd10 ? {1'b0, R0 & R1} : (op == 5'd11 ? {1'b0, R0 | R1} : (op == 5'd12 ? {1'b0, R0 ^ R1} : (op == 5'd13 ? {R0[15:0], 1'b0} : (op == 5'd14 ? (bw ? {1'b0, R0[15], R0[15:1]} : {9'b000000000, R0[7], R0[7:1]}) : (op == 5'd15 ? {2'b00, R0[15:1]} : (op == 5'd16 ? {R0[15:0], C} : (op == 5'd17 ? (bw ? {1'b0, C, R0[15:1]} : {9'b000000000, C, R0[7:1]}) : (op == 5'd18 ? {11'h003, R0[5:0] & cf[5:0]} : (op == 5'd19 ? {11'h003, R0[5:0] | cf[5:0]} : 17'h00000))))))))))))))))))))))))));
	assign RR = r[15:0];
	wire chCarryL = ((((((op == 5'd13) | (op == 5'd16)) | (op == 5'd2)) | (op == 5'd3)) | (op == 5'd5)) | (op == 5'd6)) | (op == 5'd7);
	wire chCarryR = ((op == 5'd14) | (op == 5'd15)) | (op == 5'd17);
	wire fC = (op == 5'd9 ? 1'b1 : (chCarryL ? (bw ? r[16] : r[8]) : (chCarryR ? R0[0] : C)));
	wire fZ = (bw ? RR[15:0] == 0 : RR[7:0] == 0);
	wire fN = (bw ? RR[15] : RR[7]);
	wire fV = (op == 5'd20 ? 1'b0 : (bw ? ((R0[15] ^ R1[15]) ^ RR[15]) ^ RR[14] : ((R0[7] ^ R1[7]) ^ RR[7]) ^ RR[6]));
	wire fH = (op == 5'd20 ? 1'b0 : (R0[4] ^ R1[4]) ^ RR[4]);
	assign RC = {fH, 1'b0, fN, fZ, fV, fC};
endmodule
