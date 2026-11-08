// tb_midi.cpp - harness of tb_midi.v: a chord in one burst from the firmware (as USB MIDI comes),
// read back through the status and data registers of the ACIA as a MIDI driver does.
#include <cstdio>
#include <cstdint>
#include "Vtb_midi.h"
#include "verilated.h"
static Vtb_midi *tb;
static uint64_t t = 0;
static void tick() {
	// E: 1 MHz, the 6800 bus clock of the ST (high 16 clocks of 32 MHz)
	tb->E = ((t >> 4) & 1);
	tb->clk = 0; tb->eval(); tb->clk = 1; tb->eval(); t++;
}
static void ticks(int n) { while (n--) tick(); }
static uint8_t cycle(int rs, int rw, uint8_t d) {
	while (tb->E == 1 || ((t >> 4) & 1) == 1) tick();
	tb->sel = 1; tb->rs = rs; tb->rw = rw; tb->din = d;
	ticks(24);
	uint8_t r = tb->dout;
	ticks(8); tb->sel = 0; ticks(8);
	return r;
}
int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	tb = new Vtb_midi;
	tb->reset = 1; ticks(100); tb->reset = 0; ticks(100);
	cycle(0, 0, 0x03);            // master reset
	cycle(0, 0, 0x95);            // /16, 8N1, rx interrupt on
	ticks(3200);
	static const uint8_t msg[] = { 0x90, 0x3C, 0x7F, 0x90, 0x40, 0x7F, 0x90, 0x43, 0x7F, 0x80, 0x3C, 0x00 };
	const int N = sizeof msg;
	for (int i = 0; i < N; i++) {
		tb->midi_data = msg[i]; tb->midi_wr = 1; tick(); tb->midi_wr = 0; ticks(320); // 10 us apart
	}
	int fails = 0, got = 0, wait = 0;
	while (got < N && wait < 2000000) {
		tick(); wait++;
		if (wait % 64) continue;
		uint8_t st = cycle(0, 1, 0);
		if (st & 0x70) { printf("FAIL status %02x at byte %d\n", st, got); fails++; }
		if (st & 1) {
			uint8_t d = cycle(1, 1, 0);
			if (d != msg[got]) { printf("FAIL byte %d: %02x, not %02x\n", got, d, msg[got]); fails++; }
			else printf("ok   byte %d: %02x\n", got, d);
			got++;
		}
	}
	if (got != N) { printf("FAIL got %d of %d\n", got, N); fails++; }
	printf(fails ? "FAILED: %d\n" : "all pass\n", fails);
	return fails != 0;
}
