`timescale 1ns / 1ps
// tb_rtc.v - the registers of kg_mcu (rtc_mode 3) and st_rtc, as karabas_minig_top.v wires them
module tb_rtc (
	input wire clk,
	input wire rx_stb,
	input wire [7:0] rx_addr,
	input wire [7:0] rx_data,
	output wire [51:0] digits
);
`include "kg_mcu_cmds.vh"
wire [7:0] rtc_a, rtc_do;
kg_mcu_rtc u_rtc (
	.clk(clk), .rx_stb(rx_stb), .rx_cmd(CMD_RTC), .rx_addr(rx_addr), .rx_data(rx_data), .busy(1'b0),
	.rtc_a(rtc_a), .rtc_di(8'd0), .rtc_do(rtc_do), .rtc_cs(1'b0), .rtc_wr_n(1'b1),
	.tx_req(), .tx_data()
);
st_rtc st_rtc (.clk(clk), .rtc_a(rtc_a), .rtc_do(rtc_do), .digits(digits));
endmodule
