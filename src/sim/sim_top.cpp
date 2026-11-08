// sim_top.cpp - verilator harness of sim_top.v: the Atari ST machine with sdram.v, st_sram, st_hid
// and the video chain of the board tops (memory models in sim_top.v).
//
//   sim_top [--tos FILE] [--file] [--ste|--megast] [--mono] [--ms N] [--ppm PREFIX] [--every N]
//           [--key MS:CODE[:MOD]] [--expect-var NAME=HEX ...] [--expect-frames N] [--expect-mode N]
//           [--expect-ikbd HEX] (a byte the IKBD sent to the keyboard ACIA) [--disk FILE]
//
// The TOS goes in through the loader port of st_sram (one byte per 4 clocks, the ROM loader of the
// mcu is slower) while resb is low: at 100000 (EmuTOS of core.json) or with --file at 000000 (a TOS
// file of the FL item). --ppm writes every N-th frame of the doubled output (de window, 720 x 576)
// as PREFIX_NNNN.ppm. --key holds a USB HID usage code (and modifiers) for 100 ms from MS.
// The TOS system variables are read from the SDRAM model every frame and printed when they change.
// --disk mounts FILE in A: (through a model of the mcu firmware on img_sdc) while the machine is in
// reset, as the firmware does at the start of the core, and prints the commands of fdc1772.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include "Vsim_top.h"
#include "Vsim_top___024root.h"
#include "verilated.h"

static Vsim_top *tb;
static double sim_ms = 0;
static const double TICK_MS = 1000.0 / 32000000.0;

static const char *ppm_prefix = nullptr;
static int ppm_every = 25;
static int frames = 0;

static uint32_t rd32(uint32_t a) {
	auto &m = tb->rootp->sim_top__DOT__sdr_mem;
	uint32_t w0 = m[(a >> 1) & 0x3fffff], w1 = m[((a >> 1) + 1) & 0x3fffff];
	return (w0 << 16) | w1;
}

static struct { uint32_t addr; const char *name; uint32_t cur; bool seen; } sysvars[] = {
	{ 0x420, "memvalid", 0, false }, { 0x42e, "phystop", 0, false },
	{ 0x436, "_memtop", 0, false },  { 0x44e, "_v_bas_ad", 0, false },
	{ 0x4c2, "_drvbits", 0, false }, { 0x4ba, "_hz_200", 0, false },
	{ 0, nullptr, 0, false }
};

static void check_vars(bool print) {
	for (int i = 0; sysvars[i].name; i++) {
		uint32_t v = rd32(sysvars[i].addr);
		if (!sysvars[i].seen || v != sysvars[i].cur) {
			if (print && strcmp(sysvars[i].name, "_hz_200"))
				printf("%9.3f ms %-10s = $%08x\n", sim_ms, sysvars[i].name, v);
			sysvars[i].cur = v;
			sysvars[i].seen = true;
		}
	}
}

// the doubled output: pixels inside de
static const int MAXW = 1100, MAXH = 700;
static std::vector<uint8_t> fb(MAXW * MAXH * 3);
static int fx = 0, fy = 0, fw = 0, last_hs = 0, last_vs = 0, line_de = 0;

static void write_ppm(int h) {
	char name[512];
	snprintf(name, sizeof name, "%s_%04d.ppm", ppm_prefix, frames);
	FILE *f = fopen(name, "wb");
	if (!f) { perror(name); return; }
	fprintf(f, "P6\n%d %d\n255\n", fw, h);
	for (int y = 0; y < h; y++)
		fwrite(&fb[y * MAXW * 3], 3, fw, f);
	fclose(f);
	printf("%9.3f ms frame %d: %dx%d mode %d -> %s\n", sim_ms, frames, fw, h, tb->vmode, name);
}

static void capture(void) {
	if (tb->vid_de) {
		if (fx < MAXW && fy < MAXH) {
			uint8_t *p = &fb[(fy * MAXW + fx) * 3];
			p[0] = tb->vid_rgb >> 16; p[1] = tb->vid_rgb >> 8; p[2] = tb->vid_rgb;
		}
		fx++;
		line_de = 1;
	}
	if (tb->vid_hs && !last_hs) {
		if (line_de) { if (fx > fw) fw = fx; fy++; }
		fx = 0; line_de = 0;
	}
	last_hs = tb->vid_hs;
	if (tb->vid_vs && !last_vs) {
		if (fy) {
			check_vars(true);
			if (ppm_prefix && frames % ppm_every == 0) write_ppm(fy);
			frames++;
		}
		fy = 0; fw = 0;
	}
	last_vs = tb->vid_vs;
}

static int last_rx = -1;
static std::vector<int> rx_bytes;
static void mcu_clock(void);
static void fdc_trace(void);
static bool use_disk = false;
static void tick(void) {
	if (use_disk) mcu_clock();
	tb->clk = 1; tb->eval();
	tb->clk = 0; tb->eval();
	sim_ms += TICK_MS;
	if (use_disk) fdc_trace();
	capture();
	if (tb->kbd_rx != last_rx) {
		if (last_rx >= 0) {
			printf("%9.3f ms IKBD -> ACIA $%02x\n", sim_ms, tb->kbd_rx);
			rx_bytes.push_back(tb->kbd_rx);
		}
		last_rx = tb->kbd_rx;
	}
}

// ---------------------------------------------------------------- the mcu firmware on img_sdc
static std::vector<uint8_t> disk;
static uint32_t q_lba = 0;
static int q_op = 0, q_sec = 0, q_wend = 0, q_bank = 0, mcu_reads = 0, mcu_writes = 0;
static uint16_t q_wsum = 0;
static uint8_t q_buf[512];
static int m_state = 0, m_cnt = 0, m_k = 0, ack_d = 0;
static uint16_t m_sum = 0;

static void mcu_clock(void) {
	tb->img_q_ack = 0;
	if (tb->img_q_wr && !ack_d) {
		tb->img_q_ack = 1;
		uint32_t di = tb->img_q_di;
		int cmd = di >> 16, a = (di >> 8) & 0xff, d = di & 0xff;
		if (cmd == 0x42) q_lba = (q_lba & ~(0xffu << ((a & 3) * 8))) | ((uint32_t)d << ((a & 3) * 8));
		else if (cmd == 0x43) { q_op = d; q_sec = 1; }
		else if (cmd == 0x44) {
			if (a == 0x10) q_wsum = (q_wsum & 0xff00) | d;
			else if (a == 0x11) { q_wsum = (q_wsum & 0xff) | (d << 8); q_wend = 1; }
			else q_bank = d;
		}
		else if (cmd == 0x45) q_buf[((q_bank & 1) << 8) | a] = d;
	}
	ack_d = tb->img_q_ack;
	tb->img_data_wr = 0; tb->img_result_wr = 0;
	switch (m_state) {
	case 0: if (q_sec && (q_op == 1 || q_wend)) { m_state = 1; m_cnt = 32000 * 3; } break;  // 3 ms
	case 1:
		if (--m_cnt) break;
		if (q_op == 1) { mcu_reads++; printf("%9.3f ms mcu read lba %u\n", sim_ms, q_lba); m_state = 2; m_k = 0; m_sum = 0; m_cnt = 0; }
		else {
			for (int k = 0; k < 512 && (q_lba + 1) * 512 <= disk.size(); k++) disk[q_lba * 512 + k] = q_buf[k];
			mcu_writes++; printf("%9.3f ms mcu write lba %u\n", sim_ms, q_lba); m_state = 4;
		}
		break;
	case 2:
		if (m_cnt++ & 3) break;
		{ uint8_t b = (q_lba + 1) * 512 <= disk.size() ? disk[q_lba * 512 + m_k] : 0;
		  tb->img_data_wr = 1; tb->img_data_addr = m_k; tb->img_data = b; m_sum += b;
		  if (++m_k == 512) m_state = 3; }
		break;
	case 3: tb->img_sum = m_sum; m_state = 4; break;
	case 4: tb->img_result = 1; tb->img_result_wr = 1; q_sec = 0; q_wend = 0; m_state = 0; break;
	}
}

// the commands of fdc1772: a line when one starts or ends
static int fdc_busy_d = 0, fdc_motor_d = 0, fdc_irq_d = 0;
static void fdc_trace(void) {
	if (tb->fdc_busy != fdc_busy_d)
		printf("%9.3f ms fdc %s cmd %02x track %d sector %d drive %d present %d rd %d wr %d\n", sim_ms, tb->fdc_busy ? "busy" : "idle",
			tb->fdc_cmd, tb->fdc_track, tb->fdc_sector, tb->fdc_drive, tb->fdc_present, tb->fdc_rd, tb->fdc_wr);
	if (tb->fdc_motor != fdc_motor_d) printf("%9.3f ms fdc motor %d\n", sim_ms, tb->fdc_motor);
	fdc_busy_d = tb->fdc_busy; fdc_motor_d = tb->fdc_motor; fdc_irq_d = tb->fdc_irq;
}

struct Key { double ms; int code, mod; };

int main(int argc, char **argv) {
	const char *tos = "roms/etos192uk.img", *disk_file = nullptr;
	double run_ms = 100;
	bool mono = false;
	int file = 0, chipset = 0, expect_frames = -1, expect_mode = -1, expect_ikbd = -1;
	std::vector<std::pair<std::string, uint32_t>> expects;
	std::vector<Key> keys;

	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		if (a == "--tos" && i + 1 < argc) tos = argv[++i];
		else if (a == "--file") file = 1;
		else if (a == "--disk" && i + 1 < argc) disk_file = argv[++i];
		else if (a == "--ste") chipset = 2;
		else if (a == "--megast") chipset = 1;
		else if (a == "--mono") mono = true;
		else if (a == "--ms" && i + 1 < argc) run_ms = atof(argv[++i]);
		else if (a == "--ppm" && i + 1 < argc) ppm_prefix = argv[++i];
		else if (a == "--every" && i + 1 < argc) ppm_every = atoi(argv[++i]);
		else if (a == "--expect-frames" && i + 1 < argc) expect_frames = atoi(argv[++i]);
		else if (a == "--expect-mode" && i + 1 < argc) expect_mode = atoi(argv[++i]);
		else if (a == "--expect-ikbd" && i + 1 < argc) expect_ikbd = strtol(argv[++i], nullptr, 16);
		else if (a == "--key" && i + 1 < argc) {
			Key k = { 0, 0, 0 };
			sscanf(argv[++i], "%lf:%x:%x", &k.ms, &k.code, &k.mod);
			keys.push_back(k);
		}
		else if (a == "--expect-var" && i + 1 < argc) {
			std::string e = argv[++i];
			size_t eq = e.find('=');
			expects.push_back({ e.substr(0, eq), (uint32_t)strtoul(e.c_str() + eq + 1, nullptr, 16) });
		}
		else { fprintf(stderr, "unknown argument %s\n", argv[i]); return 2; }
	}

	std::vector<uint8_t> rom(256 * 1024, 0xff);
	FILE *f = fopen(tos, "rb");
	if (!f) { perror(tos); return 2; }
	size_t n = fread(rom.data(), 1, rom.size(), f);
	fclose(f);
	rom.resize(n);

	Verilated::commandArgs(argc, argv);
	tb = new Vsim_top;
	tb->chipset = chipset;
	tb->mono_detect = !mono;
	tb->tos_file = file;
	tb->kb_status = 0; tb->kb_dat0 = 0;
	tb->porb_ext = 0; tb->resb = 0; tb->ld_we = 0;
	for (int i = 0; i < 100; i++) tick();
	tb->porb_ext = 1;

	// the loader: a byte per 4 clocks, the machine held in reset
	uint32_t base = file ? 0x000000 : 0x100000;
	for (size_t i = 0; i < rom.size(); i++) {
		tb->ld_we = 1; tb->ld_addr = base + i; tb->ld_data = rom[i];
		tick();
		tb->ld_we = 0;
		tick(); tick(); tick();
	}
	if (disk_file) {
		FILE *d = fopen(disk_file, "rb");
		if (!d) { perror(disk_file); return 2; }
		fseek(d, 0, SEEK_END); disk.resize(ftell(d)); rewind(d);
		if (fread(disk.data(), 1, disk.size(), d) != disk.size()) return 2;
		fclose(d);
		use_disk = true;
		tb->img_size = disk.size(); tb->img_mounted = 1;
		tick();
		tb->img_mounted = 0;
	}
	for (int i = 0; i < 100; i++) tick();
	printf("%9.3f ms TOS %s: %zu KB at %06x, SDRAM ready %d\n", sim_ms, tos, n / 1024, base, tb->ram_ready);
	tb->resb = 1;

	while (sim_ms < run_ms) {
		int code = 0, mod = 0;
		for (auto &k : keys)
			if (sim_ms >= k.ms && sim_ms < k.ms + 100) { code = k.code; mod = k.mod; }
		tb->kb_dat0 = code; tb->kb_status = mod;
		tick();
	}
	check_vars(true);
	printf("stopped at %.3f ms, %d frames, mode %d\n", sim_ms, frames, tb->vmode);

	int fail = 0;
	for (auto &e : expects) {
		bool found = false;
		for (int i = 0; sysvars[i].name; i++)
			if (e.first == sysvars[i].name) {
				found = true;
				uint32_t v = rd32(sysvars[i].addr);
				if (v != e.second) { printf("FAIL %s = $%08x, expected $%08x\n", e.first.c_str(), v, e.second); fail = 1; }
				else printf("ok   %s = $%08x\n", e.first.c_str(), v);
			}
		if (!found) { printf("FAIL unknown variable %s\n", e.first.c_str()); fail = 1; }
	}
	if (expect_frames >= 0) {
		if (frames < expect_frames) { printf("FAIL %d frames, expected %d\n", frames, expect_frames); fail = 1; }
		else printf("ok   %d frames\n", frames);
	}
	if (expect_mode >= 0) {
		if (tb->vmode != expect_mode) { printf("FAIL mode %d, expected %d\n", tb->vmode, expect_mode); fail = 1; }
		else printf("ok   mode %d\n", tb->vmode);
	}
	if (expect_ikbd >= 0) {
		bool seen = false;
		for (int b : rx_bytes) if (b == expect_ikbd) seen = true;
		if (!seen) { printf("FAIL the IKBD sent no $%02x\n", expect_ikbd); fail = 1; }
		else printf("ok   IKBD sent $%02x\n", expect_ikbd);
	}
	delete tb;
	return fail;
}
