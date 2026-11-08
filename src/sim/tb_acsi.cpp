// tb_acsi.cpp - harness of tb_acsi.v: dma + acsi + img_sdc with a model of the mcu firmware.
//
// One disk image in memory on ACSI target 0 (every byte a function of its offset). The cpu side
// drives the dma registers as TOS does; the ST RAM answers the dma bus. Checks: test unit ready,
// inquiry reply, read(6) of two sectors, write(6) of a sector (the image of the model), reading
// it back, a read(10), and that the target without an image does not answer. Exit 0 when all pass.

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <vector>
#include "Vtb_acsi.h"
#include "verilated.h"

static Vtb_acsi *tb;
static uint64_t ticks = 0;
static const int SECTORS = 2048;
static std::vector<uint8_t> disk;
static int fails = 0;

// ------------------------------------------------- mcu
static uint32_t q_lba = 0;
static int q_slot = 0, q_op = 0, q_bank = 0, q_sec = 0, q_wend = 0, mcu_reads = 0, mcu_writes = 0;
static uint16_t q_wsum = 0;
static uint8_t q_buf[512];
static int m_state = 0, m_cnt = 0, m_k = 0, ack_d = 0, m_result = 0;
static uint16_t m_sum = 0;

static void mcu_clock(void) {
	tb->img_q_ack = 0;
	if (tb->img_q_wr && !ack_d) {
		tb->img_q_ack = 1;
		uint32_t di = tb->img_q_di;
		int cmd = di >> 16, a = (di >> 8) & 0xff, d = di & 0xff;
		if (cmd == 0x42) q_lba = (q_lba & ~(0xffu << ((a & 3) * 8))) | ((uint32_t)d << ((a & 3) * 8));
		else if (cmd == 0x43) { q_slot = a; q_op = d; q_sec = 1; }
		else if (cmd == 0x44) {
			if (a == 0x10) q_wsum = (q_wsum & 0xff00) | d;
			else if (a == 0x11) { q_wsum = (q_wsum & 0xff) | (d << 8); q_wend = 1; }
			else q_bank = d;
		}
		else if (cmd == 0x45) q_buf[((q_bank & 1) << 8) | a] = d;
	}
	ack_d = tb->img_q_ack;
	tb->img_data_wr = 0; tb->img_result_wr = 0;
	bool ok = q_slot == 2 && q_lba < (uint32_t)SECTORS;
	switch (m_state) {
	case 0: if (q_sec && (q_op == 1 || q_wend)) { m_state = 1; m_cnt = 2000; } break;
	case 1:
		if (--m_cnt) break;
		if (q_op == 1) { mcu_reads++; m_state = 2; m_k = 0; m_sum = 0; m_cnt = 0; }
		else {
			uint16_t s = 0;
			for (int k = 0; k < 512; k++) s += q_buf[k];
			if (s != q_wsum) { printf("FAIL write sum %04x, frames %04x\n", s, q_wsum); fails++; }
			if (ok) for (int k = 0; k < 512; k++) disk[q_lba * 512 + k] = q_buf[k];
			mcu_writes++; m_result = ok ? 1 : 2; m_state = 4;
		}
		break;
	case 2:
		if (m_cnt++ & 3) break;
		{ uint8_t b = ok ? disk[q_lba * 512 + m_k] : 0;
		  tb->img_data_wr = 1; tb->img_data_addr = m_k; tb->img_data = b; m_sum += b;
		  if (++m_k == 512) m_state = 3; }
		break;
	case 3: tb->img_sum = m_sum; m_result = ok ? 1 : 2; m_state = 4; break;
	case 4: tb->img_result = m_result; tb->img_result_wr = 1; q_sec = 0; q_wend = 0; m_state = 0; break;
	}
}

// ------------------------------------------------- the ST RAM on the dma bus
static std::vector<uint16_t> ram_rx;      // words the dma wrote to RAM
static std::vector<uint16_t> ram_tx;      // words the dma reads from RAM
static size_t ram_tx_pos = 0;
static int bus_cnt = 0;

static void bus_clock(void) {
	tb->rdy_i = 0;
	bus_cnt = (bus_cnt + 1) & 15;
	if (tb->cpu_sel || !tb->rdy_o || bus_cnt != 0) return;
	// a bus cycle of the dma: the rising edge of rdy_i is the strobe
	ram_rx.push_back(tb->cpu_dout);
	tb->ram_din = ram_tx_pos < ram_tx.size() ? ram_tx[ram_tx_pos] : 0;
	ram_tx_pos++;
	tb->rdy_i = 1;
}

static void tick(void) {
	mcu_clock();
	bus_clock();
	tb->clk = 1; tb->eval();
	tb->clk = 0; tb->eval();
	ticks++;
}

// ------------------------------------------------- the cpu side
static void cpu_wr(int a1, int v) {
	tb->cpu_a1 = a1; tb->cpu_din = v; tb->cpu_rw = 0; tb->cpu_sel = 1;
	for (int i = 0; i < 12; i++) tick();
	tb->cpu_sel = 0; tb->cpu_rw = 1;
	for (int i = 0; i < 12; i++) tick();
}
static int cpu_rd(int a1) {
	tb->cpu_a1 = a1; tb->cpu_rw = 1; tb->cpu_sel = 1;
	for (int i = 0; i < 12; i++) tick();
	int v = tb->cpu_dout;
	tb->cpu_sel = 0;
	for (int i = 0; i < 12; i++) tick();
	return v;
}
static bool wait_irq(int ms) {
	uint64_t t0 = ticks;
	while (!tb->irq) { tick(); if (ticks - t0 > (uint64_t)ms * 32000) return false; }
	return true;
}

// a command of n bytes; count sectors of dma (0 = none); returns the status or -1
static int command(const uint8_t *c, int n, bool write, int count) {
	int dir = write ? 0x100 : 0;
	ram_rx.clear(); ram_tx_pos = 0;
	cpu_wr(1, 0x190);                            // the direction toggled twice below clears the fifo
	cpu_wr(1, write ? 0x090 : 0x190);
	cpu_wr(1, write ? 0x190 : 0x090);
	cpu_wr(0, count);                            // sector count register (mode bit 4)
	cpu_wr(1, 0x088 | dir);                      // A0 low: the first byte
	cpu_wr(0, c[0]);
	if (!wait_irq(5)) return -1;
	cpu_wr(1, 0x08a | dir);
	for (int i = 1; i < n; i++) {
		cpu_wr(0, c[i]);
		if (i < n - 1 && !wait_irq(5)) return -2;
	}
	if (!wait_irq(500)) return -3;
	return cpu_rd(0) & 0xff;
}

static uint16_t be(const std::vector<uint8_t> &d, uint32_t off) { return (d[off] << 8) | d[off + 1]; }
static void report(const char *what, bool ok, int st) {
	printf("%s %s: status %d (%.1f ms)\n", ok ? "ok  " : "FAIL", what, st, ticks / 32000.0);
	if (!ok) fails++;
}

static void check_read(const char *what, const uint8_t *c, int n, uint32_t lba, int count) {
	int st = command(c, n, false, count);
	size_t words = count * 256;
	int bad = -1;
	if (ram_rx.size() >= words)
		for (size_t i = 0; i < words; i++)
			if (ram_rx[i] != be(disk, lba * 512 + i * 2)) { bad = i; break; }
	bool ok = st == 0 && ram_rx.size() >= words && bad < 0;
	if (!ok) printf("     %zu words, first difference at word %d\n", ram_rx.size(), bad);
	report(what, ok, st);
}

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	disk.resize(SECTORS * 512);
	for (uint32_t i = 0; i < disk.size(); i++) disk[i] = (uint8_t)((i * 7 + (i >> 9) * 13) ^ (i >> 3));
	tb = new Vtb_acsi;
	tb->reset = 1; tb->cpu_rw = 1;
	for (int i = 0; i < 40; i++) tick();
	tb->reset = 0;
	for (int i = 0; i < 40; i++) tick();
	tb->img_size = SECTORS * 512; tb->img_mounted = 1 << 2;
	tick();
	tb->img_mounted = 0;
	for (int i = 0; i < 40; i++) tick();

	const uint8_t tur[6] = { 0x00, 0, 0, 0, 0, 0 };
	int st = command(tur, 6, false, 0);
	report("test unit ready", st == 0, st);

	const uint8_t inq[6] = { 0x12, 0, 0, 0, 32, 0 };
	st = command(inq, 6, false, 1);
	// the dma is still emptying its fifo at the irq: only the first chunk is checked
	report("inquiry", st == 0 && ram_rx.size() >= 8 && ram_rx[1] == 0x0100 && ram_rx[4] == 0x4d69, st);

	const uint8_t rd6[6] = { 0x08, 0, 0, 5, 2, 0 };
	check_read("read(6) lba 5, 2 sectors", rd6, 6, 5, 2);
	if (mcu_reads != 2) { printf("FAIL %d mcu reads\n", mcu_reads); fails++; }

	ram_tx.resize(256);
	std::vector<uint8_t> w(512);
	for (int i = 0; i < 512; i++) w[i] = (uint8_t)(i * 3 + 0x5a);
	for (int i = 0; i < 256; i++) ram_tx[i] = (w[i * 2] << 8) | w[i * 2 + 1];
	const uint8_t wr6[6] = { 0x0a, 0, 0, 7, 1, 0 };
	int writes0 = mcu_writes;
	st = command(wr6, 6, true, 1);
	int bad = -1;
	for (int i = 0; i < 512; i++) if (disk[7 * 512 + i] != w[i]) { bad = i; break; }
	if (bad >= 0) printf("     image differs at byte %d\n", bad);
	report("write(6) lba 7", st == 0 && mcu_writes == writes0 + 1 && bad < 0, st);

	check_read("read(6) back lba 7", (const uint8_t[]){ 0x08, 0, 0, 7, 1, 0 }, 6, 7, 1);
	check_read("read(10) lba 300", (const uint8_t[]){ 0x1f, 0x28, 0, 0, 0, 1, 0x2c, 0, 0, 1, 0 }, 11, 300, 1);  // 0x1f: an extended command follows

	// target 1 has no image: no answer to its first byte
	cpu_wr(1, 0x088);
	cpu_wr(0, 0x20);
	report("target 1 without an image is silent", !wait_irq(5), 0);

	printf("%s: %d failed, %.1f ms of 32 MHz\n", fails ? "FAIL" : "PASS", fails, ticks / 32000.0);
	delete tb;
	return fails ? 1 : 0;
}
