`timescale 1ns / 1ps
`default_nettype wire

/*
 st_rtc.v

 The clock of the ST (RP5C15 digits in atarist.v) from the registers kg_mcu keeps with rtc_mode 3
 (MSM6242B): 0-12 are one BCD digit each, S1 S10 MI1 MI10 H1 H10 D1 D10 MO1 MO10 Y1 Y10 W, in the
 order atarist.v wants. This module walks the addresses and copies them. The mcu sends the time
 every 500 ms, so nothing counts here. The mcu year is mod 100 (2026 = 26), the ST counts from
 1980: 80 more, that is 20 back, in the tens digit only. The ST does not set the clock
 (atarist.v ignores writes to its time registers).
*/

module st_rtc (
	input wire clk,
	output reg [7:0] rtc_a = 8'd0,   // to kg_mcu, data a clock later
	input wire [7:0] rtc_do,
	output reg [51:0] digits = 52'd0
);

localparam [7:0] Y10 = 8'd11, LAST = 8'd12;

// the address rtc_do belongs to
reg [7:0] a_d = 8'd0;
wire [3:0] d = rtc_do[3:0];
wire [3:0] y10_st = (d >= 4'd8) ? d - 4'd8 : d + 4'd2;

always @(posedge clk) begin
	rtc_a <= (rtc_a == LAST) ? 8'd0 : rtc_a + 8'd1;
	a_d <= rtc_a;
	digits[a_d[3:0] * 4 +: 4] <= (a_d == Y10) ? y10_st : d;
end

endmodule
