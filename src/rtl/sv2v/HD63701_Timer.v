module HD63701_Timer (
	mcu_rst,
	mcu_clk,
	mcu_en,
	mcu_en2,
	mcu_ad,
	mcu_wr,
	mcu_do,
	mcu_irq2_tim,
	en_timer,
	timerd
);
	input mcu_rst;
	input mcu_clk;
	input mcu_en;
	input mcu_en2;
	input [15:0] mcu_ad;
	input mcu_wr;
	input [7:0] mcu_do;
	output wire mcu_irq2_tim;
	output wire en_timer;
	output wire [7:0] timerd;
	reg oci;
	reg oce;
	reg [15:0] ocr;
	reg [15:0] icr;
	reg [16:0] frc;
	reg [7:0] frt;
	reg [7:0] rmc;
	always @(posedge mcu_clk or posedge mcu_rst)
		if (mcu_rst) begin
			oce <= 0;
			ocr <= 16'hffff;
			icr <= 16'hffff;
			frc <= 0;
			frt <= 0;
			rmc <= 8'h40;
		end
		else if (mcu_en) begin
			frc <= frc + 17'd1;
			if (mcu_wr)
				case (mcu_ad)
					16'h0008: oce <= mcu_do[3];
					16'h0009: frt <= mcu_do;
					16'h000a: frc <= {frt, mcu_do, 1'h0};
					16'h000b: ocr[15:8] <= mcu_do;
					16'h000c: ocr[7:0] <= mcu_do;
					16'h000d: icr[15:8] <= mcu_do;
					16'h000e: icr[7:0] <= mcu_do;
					16'h0014: rmc <= {mcu_do[7:6], 6'h00};
					default:
						;
				endcase
		end
	always @(posedge mcu_clk or posedge mcu_rst)
		if (mcu_rst)
			oci <= 1'b0;
		else if (mcu_en2)
			case (mcu_ad)
				16'h000b: oci <= 1'b0;
				16'h000c: oci <= 1'b0;
				default:
					if (frc[16:1] == ocr)
						oci <= 1'b1;
			endcase
	assign mcu_irq2_tim = oci & oce;
	assign en_timer = ((mcu_ad >= 16'h0008) & (mcu_ad <= 16'h000e)) | (mcu_ad == 16'h0014);
	assign timerd = (mcu_ad == 16'h0008 ? {1'b0, oci, 2'b10, oce, 3'b000} : (mcu_ad == 16'h0009 ? frc[16:9] : (mcu_ad == 16'h000a ? frc[8:1] : (mcu_ad == 16'h000b ? ocr[15:8] : (mcu_ad == 16'h000c ? ocr[7:0] : (mcu_ad == 16'h000d ? icr[15:8] : (mcu_ad == 16'h000e ? icr[7:0] : (mcu_ad == 16'h0014 ? rmc : 8'h00))))))));
endmodule
