`timescale 1ns / 1ps
// tb_midi.v - MIDI IN as in the board tops: the bytes of the mcu through kg_midi_tx into the
// MIDI ACIA of the machine (rtl/sv2v). The harness is the cpu on the registers of the ACIA.
module tb_midi (
	input wire clk,
	input wire reset,
	input wire [7:0] midi_data,
	input wire midi_wr,
	input wire E,
	input wire sel,
	input wire rs,
	input wire rw,
	input wire [7:0] din,
	output wire [7:0] dout,
	output wire irq,
	output wire line
);
kg_midi_tx #(.CLK_HZ(32000000), .AW(5)) midi_in (.clk(clk), .data(midi_data), .wr(midi_wr), .overflow(), .tx(line));
acia acia (.clk(clk), .E(E), .reset(reset), .rxtxclk_sel(1'b0), .din(din), .sel(sel), .rs(rs), .rw(rw),
	.dout(dout), .irq(irq), .tx(), .rx(line), .dout_strobe());
endmodule
