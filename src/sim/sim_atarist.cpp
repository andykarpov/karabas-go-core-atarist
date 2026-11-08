// sim_atarist.cpp - verilator harness of the Atari ST machine alone (rtl/sv2v, what XST builds).
//
// The ST RAM and the TOS ROM are C++ arrays on the DRAM / ROM buses of atarist, as in the
// testbench of MiSTeryNano (sim/atarist_tb.cpp): a read is answered at the clock edge of the
// request, so this checks the machine, not the board memory controllers.
//
//   sim_atarist [--tos FILE] [--ms N] [--ram KB] [--ppm PREFIX] [--every N] [--mono]
//               [--expect-var NAME=HEX ...] [--expect-frames N]
//
// --ppm writes every N-th frame (default 25) as PREFIX_NNNN.ppm: the shifter output at the
// 32 MHz clock, the de window only. The TOS system variables (MEMVALID, PHYSTOP, _v_bas_ad ...)
// are printed when the TOS writes them. Exit code 1 when an --expect fails.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include "Vatarist.h"
#include "verilated.h"

static Vatarist *tb;
static double sim_ms = 0;
static const double TICK_MS = 1000.0 / 32084988.0;  // one clk_32 period

static int ram_kb = 1024;
static std::vector<uint8_t> ram;
static uint8_t rom[256 * 1024];

static const char *ppm_prefix = nullptr;
static int ppm_every = 25;
static int frames = 0;

// the TOS system variables worth watching
static struct { int addr; const char *name; uint32_t cur; bool seen; } sysvars[] = {
	{ 0x420, "memvalid", 0, false }, { 0x42e, "phystop", 0, false },
	{ 0x432, "_membot", 0, false },  { 0x436, "_memtop", 0, false },
	{ 0x43a, "memval2", 0, false },  { 0x44e, "_v_bas_ad", 0, false },
	{ 0x4c2, "_drvbits", 0, false }, { 0x51a, "memval3", 0, false },
	{ 0, nullptr, 0, false }
};

static uint32_t rd32(int a) {
	return (ram[a] << 24) | (ram[a + 1] << 16) | (ram[a + 2] << 8) | ram[a + 3];
}

static void check_vars(int addr) {
	for (int i = 0; sysvars[i].name; i++) {
		int a = sysvars[i].addr;
		if (addr >= a && addr < a + 4) {
			uint32_t v = rd32(a);
			if (!sysvars[i].seen || v != sysvars[i].cur) {
				printf("%9.3f ms %-10s = $%08x\n", sim_ms, sysvars[i].name, v);
				sysvars[i].cur = v;
				sysvars[i].seen = true;
			}
		}
	}
}

// video capture: pixels inside de, one line per hsync, one frame per vsync
static const int MAXW = 2100, MAXH = 700;
static std::vector<uint8_t> fb(MAXW * MAXH * 3);
static int fx = 0, fy = 0, fw = 0, fh = 0, last_hs = 1, last_vs = 1, line_has_de = 0;

static void write_ppm(void) {
	char name[512];
	snprintf(name, sizeof name, "%s_%04d.ppm", ppm_prefix, frames);
	FILE *f = fopen(name, "wb");
	if (!f) { perror(name); return; }
	int w = fw ? fw : 1, h = fh ? fh : 1;
	fprintf(f, "P6\n%d %d\n255\n", w, h);
	for (int y = 0; y < h; y++)
		fwrite(&fb[y * MAXW * 3], 3, w, f);
	fclose(f);
	printf("%9.3f ms frame %d: %dx%d -> %s\n", sim_ms, frames, w, h, name);
}

static void capture(void) {
	if (tb->de) {
		if (fx < MAXW && fy < MAXH) {
			uint8_t *p = &fb[(fy * MAXW + fx) * 3];
			p[0] = tb->r * 17; p[1] = tb->g * 17; p[2] = tb->b * 17;
		}
		fx++;
		line_has_de = 1;
	}
	if (tb->hsync_n != last_hs) {
		last_hs = tb->hsync_n;
		if (!tb->hsync_n && line_has_de) {
			if (fx > fw) fw = fx;
			fy++;
			line_has_de = 0;
		}
		if (!tb->hsync_n) fx = 0;
	}
	if (tb->vsync_n != last_vs) {
		last_vs = tb->vsync_n;
		if (!tb->vsync_n) {
			fh = fy;
			if (ppm_prefix && fh && frames % ppm_every == 0) write_ppm();
			frames++;
			fy = 0; fw = 0;
		}
	}
}

static void tick(int c) {
	tb->clk_32 = c;
	tb->eval();
	if (!c) return;
	sim_ms += TICK_MS;

	if (!tb->rom_n) {
		int a = (tb->rom_addr << 1) & 0x3ffff;
		tb->rom_data_out = (rom[a] << 8) | rom[a + 1];
	}
	if (!tb->ram_ras_n && !tb->ram_ref && (!tb->ram_cash_n || !tb->ram_casl_n)) {
		int a = tb->ram_addr << 1;
		if (a < ram_kb * 1024) {
			if (tb->ram_we_n)
				tb->ram_data_out = (ram[a] << 8) | ram[a + 1];
			else {
				if (!tb->ram_cash_n) ram[a] = tb->ram_data_in >> 8;
				if (!tb->ram_casl_n) ram[a + 1] = tb->ram_data_in & 0xff;
				check_vars(a);
			}
		}
	}
	capture();
}

int main(int argc, char **argv) {
	const char *tos = "../roms/etos192uk.img";
	double run_ms = 100;
	int mono = 0, expect_frames = -1;
	std::vector<std::pair<std::string, uint32_t>> expects;

	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		if (a == "--tos" && i + 1 < argc) tos = argv[++i];
		else if (a == "--ms" && i + 1 < argc) run_ms = atof(argv[++i]);
		else if (a == "--ram" && i + 1 < argc) ram_kb = atoi(argv[++i]);
		else if (a == "--ppm" && i + 1 < argc) ppm_prefix = argv[++i];
		else if (a == "--every" && i + 1 < argc) ppm_every = atoi(argv[++i]);
		else if (a == "--mono") mono = 1;
		else if (a == "--expect-frames" && i + 1 < argc) expect_frames = atoi(argv[++i]);
		else if (a == "--expect-var" && i + 1 < argc) {
			std::string e = argv[++i];
			size_t eq = e.find('=');
			expects.push_back({ e.substr(0, eq), (uint32_t)strtoul(e.c_str() + eq + 1, nullptr, 16) });
		}
		else { fprintf(stderr, "unknown argument %s\n", argv[i]); return 2; }
	}

	ram.assign(ram_kb * 1024, 0);
	FILE *f = fopen(tos, "rb");
	if (!f) { perror(tos); return 2; }
	size_t n = fread(rom, 1, sizeof rom, f);
	fclose(f);
	// a 192 KB TOS sits at FC0000: the ROM bus of atarist gives the offset in the 256 KB window
	printf("TOS %s: %zu KB\n", tos, n / 1024);

	Verilated::commandArgs(argc, argv);
	tb = new Vatarist;
	tb->mono_detect = mono ? 0 : 1;
	tb->keyboard_matrix_in = 0xff;
	tb->ste = 0;
	tb->blitter_en = 1;
	tb->floppy_protected = 3;
	tb->porb = 0; tb->resb = 0;
	for (int i = 0; i < 100; i++) { tick(1); tick(0); }
	tb->porb = 1;
	for (int i = 0; i < 100; i++) { tick(1); tick(0); }
	tb->resb = 1;

	while (sim_ms < run_ms) { tick(1); tick(0); }
	printf("stopped at %.3f ms, %d frames\n", sim_ms, frames);

	int fail = 0;
	for (auto &e : expects) {
		bool found = false;
		for (int i = 0; sysvars[i].name; i++)
			if (e.first == sysvars[i].name) {
				found = true;
				if (rd32(sysvars[i].addr) != e.second) {
					printf("FAIL %s = $%08x, expected $%08x\n", e.first.c_str(), rd32(sysvars[i].addr), e.second);
					fail = 1;
				} else
					printf("ok   %s = $%08x\n", e.first.c_str(), e.second);
			}
		if (!found) { printf("FAIL unknown variable %s\n", e.first.c_str()); fail = 1; }
	}
	if (expect_frames >= 0) {
		if (frames < expect_frames) { printf("FAIL %d frames, expected %d\n", frames, expect_frames); fail = 1; }
		else printf("ok   %d frames\n", frames);
	}
	delete tb;
	return fail;
}
