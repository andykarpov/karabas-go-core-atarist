// tb_rtc.cpp - harness of tb_rtc.v: the mcu writes the 13 digits of rtc_mode 3, the digits at
// the machine must follow, with the year moved to the base of the ST (1980). Exit 0 when all pass.
#include <cstdio>
#include <cstdint>
#include "Vtb_rtc.h"
#include "verilated.h"
static Vtb_rtc *tb;
static int fails = 0;
static void tick(int n = 1) { while (n--) { tb->clk = 0; tb->eval(); tb->clk = 1; tb->eval(); } }
static void set(const int *r) {
	for (int i = 0; i < 13; i++) {
		tb->rx_addr = i; tb->rx_data = r[i]; tb->rx_stb = 1; tick(); tb->rx_stb = 0; tick(3);
	}
	tick(40);
}
static void check(const char *name, const int *r, int y10) {
	for (int i = 0; i < 13; i++) {
		int want = i == 11 ? y10 : r[i];
		int got = (tb->digits >> (i * 4)) & 15;
		if (got != want) { printf("FAIL %s: digit %d is %d, not %d\n", name, i, got, want); fails++; }
	}
	printf("%s: done\n", name);
}
int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	tb = new Vtb_rtc;
	tick(40);
	// no time from the mcu: month 00, the machine hides the clock
	if ((tb->digits >> 32) & 0xff) { printf("FAIL start: %llx\n", (unsigned long long)tb->digits); fails++; }
	// 2026-11-08 17:45:39, Sunday: the ST year 46
	static const int a[13] = { 9,3, 5,4, 7,1, 8,0, 1,1, 6,2, 0 };
	set(a); check("2026", a, 4);
	if (!((tb->digits >> 32) & 0xff)) { printf("FAIL month\n"); fails++; }
	// the next second: only one digit changes
	static const int b[13] = { 0,4, 5,4, 7,1, 8,0, 1,1, 6,2, 0 };
	set(b); check("next second", b, 4);
	// 2085: the ST year 105 mod 100, digit 0 (the chip has two digits)
	static const int c[13] = { 1,2, 3,4, 5,0, 6,1, 7,0, 5,8, 6 };
	set(c); check("2085", c, 0);
	printf(fails ? "FAILED: %d\n" : "all pass\n", fails);
	return fails != 0;
}
