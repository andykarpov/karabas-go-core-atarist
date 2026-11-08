// tb_floppy.cpp - harness of tb_floppy.v: fdc1772 + img_sdc with a model of the mcu firmware.
//
// The disks are two 720 KB images in memory (80 tracks, 9 sectors, 2 sides; every byte a function
// of its offset). The cpu side drives the fdc registers as TOS does, with the spin up skipped
// (h flag) to keep the run short:
//   - restore, read sector 1 of track 0 side 0 of A: (lba 0), compare 512 bytes;
//   - seek track 5, side 1, read sector 9 (lba 5*18 + 9 + 8 = 107), compare;
//   - write sector 4 of track 5 side 1 (lba 102) with a pattern, check the image of the model;
//   - read it back through the fdc;
//   - drive B: read (lba 0 of the second image);
//   - write to a write protected A: : the status has WP, the image is not changed.
// The run stops in a few seconds; exit 0 when all pass.

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <vector>
#include "Vtb_floppy.h"
#include "verilated.h"

static Vtb_floppy *tb;
static uint64_t ticks = 0;
static const int SECTORS = 1440;
static std::vector<uint8_t> disk[2];
static int fails = 0;

// ---------------------------------------------------------------- the mcu model

static uint32_t q_lba = 0;
static int q_slot = 0, q_op = 0, q_bank = 0, q_sec = 0, q_wend = 0;
static uint16_t q_wsum = 0;
static uint8_t q_buf[512];
static int mcu_reads = 0, mcu_writes = 0;
static bool wprot[2] = { false, false };

// the answer: a byte per 4 clocks, after a delay (the mcu takes ms; a short one here)
enum { M_IDLE, M_DELAY, M_DATA, M_SUM, M_RESULT, M_RESULT2 };
static int m_state = M_IDLE, m_cnt = 0, m_k = 0, m_result = 0;
static uint16_t m_sum = 0;

static void mcu_clock(void) {
	// frames of img_sdc
	tb->img_q_ack = 0;
	static int ack_d = 0;
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

	tb->img_data_wr = 0;
	tb->img_result_wr = 0;
	switch (m_state) {
	case M_IDLE:
		if (q_sec && (q_op == 1 || q_wend)) { m_state = M_DELAY; m_cnt = 2000; }
		break;
	case M_DELAY:
		if (--m_cnt) break;
		if (q_op == 1) {
			mcu_reads++;
			m_state = M_DATA; m_k = 0; m_sum = 0; m_cnt = 0;
		}
		else {
			uint16_t s = 0;
			for (int k = 0; k < 512; k++) s += q_buf[k];
			if (s != q_wsum) { printf("FAIL write sum %04x, frames %04x\n", s, q_wsum); fails++; }
			if (q_slot < 2 && q_lba < SECTORS && !wprot[q_slot]) {
				for (int k = 0; k < 512; k++) disk[q_slot][q_lba * 512 + k] = q_buf[k];
				mcu_writes++;
				m_result = 1;
			}
			else m_result = wprot[q_slot & 1] ? 3 : 2;
			m_state = M_RESULT;
		}
		break;
	case M_DATA:
		if (m_cnt++ & 3) break;
		{
			uint8_t b = (q_slot < 2 && q_lba < SECTORS) ? disk[q_slot][q_lba * 512 + m_k] : 0;
			tb->img_data_wr = 1; tb->img_data_addr = m_k; tb->img_data = b;
			m_sum += b;
			if (++m_k == 512) { m_state = M_SUM; }
		}
		break;
	case M_SUM:
		tb->img_sum = m_sum; m_result = (q_slot < 2 && q_lba < SECTORS) ? 1 : 2;
		m_state = M_RESULT;
		break;
	case M_RESULT:
		tb->img_result = m_result; tb->img_result_wr = 1;
		q_sec = 0; q_wend = 0;
		m_state = M_IDLE;
		break;
	}
}

static void tick(void) {
	mcu_clock();
	tb->clk = 1; tb->eval();
	tb->clk = 0; tb->eval();
	ticks++;
}

// ---------------------------------------------------------------- the cpu side

static void wr(int reg, int v) {
	tb->cpu_addr = reg; tb->cpu_din = v; tb->cpu_rw = 0; tb->cpu_sel = 1;
	for (int i = 0; i < 4; i++) tick();
	tb->cpu_sel = 0; tb->cpu_rw = 1;
	for (int i = 0; i < 8; i++) tick();
}

static int rd(int reg) {
	tb->cpu_addr = reg; tb->cpu_rw = 1; tb->cpu_sel = 1;
	for (int i = 0; i < 4; i++) tick();
	int v = tb->cpu_dout;
	tb->cpu_sel = 0;
	for (int i = 0; i < 8; i++) tick();
	return v;
}

static const uint64_t LIMIT = 32000000ull * 3; // 3 s of 32 MHz per command

// waits for the end of a command (irq); returns the status
static int wait_irq(const char *what) {
	uint64_t t0 = ticks;
	while (!tb->irq) {
		tick();
		if (ticks - t0 > LIMIT) { printf("FAIL %s: no irq\n", what); fails++; return -1; }
	}
	return rd(0);
}

static uint8_t pattern(int d, uint32_t off) { return (uint8_t)((off * 7 + (off >> 9) * 13 + d * 101) ^ (off >> 3)); }

// a type II read: the bytes taken on drq
static int read_sector(const char *what, int sector, std::vector<uint8_t> &got) {
	got.clear();
	wr(2, sector);
	wr(0, 0x88);                   // read sector, h: no spin up
	uint64_t t0 = ticks;
	while (!tb->irq) {
		if (tb->drq) got.push_back(rd(3));
		else tick();
		if (ticks - t0 > LIMIT) { printf("FAIL %s: no irq\n", what); fails++; return -1; }
	}
	return rd(0);
}

static int write_sector(const char *what, int sector, const uint8_t *data, int *taken) {
	wr(2, sector);
	wr(0, 0xa8);                   // write sector, h
	uint64_t t0 = ticks;
	int k = 0;
	while (!tb->irq) {
		if (tb->drq && k < 512) wr(3, data[k++]);
		else tick();
		if (ticks - t0 > LIMIT) { printf("FAIL %s: no irq\n", what); fails++; return -1; }
	}
	*taken = k;
	return rd(0);
}

static void check_read(const char *what, int d, int sector, uint32_t lba) {
	std::vector<uint8_t> got;
	int st = read_sector(what, sector, got);
	int bad = -1;
	if (got.size() == 512)
		for (int k = 0; k < 512; k++)
			if (got[k] != disk[d][lba * 512 + k]) { bad = k; break; }
	if (st < 0) return;
	if ((st & 0x1c) || got.size() != 512 || bad >= 0) {
		printf("FAIL %s: status %02x, %zu bytes, first difference at %d (lba %u)\n", what, st, got.size(), bad, lba);
		fails++;
	}
	else printf("ok   %s: status %02x, 512 bytes of lba %u (%.1f ms)\n", what, st, lba, ticks / 32000.0);
}

static void select(int d, int side) {
	tb->drive_n = d ? 1 : 2;       // bit d low
	tb->side_n = side ? 0 : 1;
}

static void mount(int d, uint64_t size) {
	tb->img_size = size; tb->img_mounted = 1 << d;
	tick();
	tb->img_mounted = 0;
	tick();
}

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	for (int d = 0; d < 2; d++) {
		disk[d].resize(SECTORS * 512);
		for (uint32_t i = 0; i < disk[d].size(); i++) disk[d][i] = pattern(d, i);
	}
	tb = new Vtb_floppy;
	tb->reset = 1; tb->cpu_rw = 1; tb->drive_n = 3; tb->side_n = 1;
	for (int i = 0; i < 20; i++) tick();
	tb->reset = 0;
	for (int i = 0; i < 20; i++) tick();
	mount(0, SECTORS * 512);
	mount(1, SECTORS * 512);
	for (int i = 0; i < 100; i++) tick();

	select(0, 0);
	int st = (wr(0, 0x08), wait_irq("restore"));
	printf("%s restore: status %02x\n", (st >= 0 && (st & 0x04)) ? "ok  " : "FAIL", st);
	if (st < 0 || !(st & 0x04)) fails++;

	check_read("A: track 0 side 0 sector 1", 0, 1, 0);

	wr(3, 5); st = (wr(0, 0x18), wait_irq("seek 5"));  // seek to the data register, h
	if (rd(1) != 5) { printf("FAIL seek: track register %d\n", rd(1)); fails++; }
	select(0, 1);
	check_read("A: track 5 side 1 sector 9", 0, 9, 5 * 18 + 9 + 8);

	uint8_t wdata[512];
	for (int k = 0; k < 512; k++) wdata[k] = (uint8_t)(k * 3 + 0x5a);
	int taken = 0;
	int reads0 = mcu_reads, writes0 = mcu_writes;
	st = write_sector("A: write track 5 side 1 sector 4", 4, wdata, &taken);
	uint32_t wlba = 5 * 18 + 9 + 3;
	int bad = -1;
	for (int k = 0; k < 512; k++) if (disk[0][wlba * 512 + k] != wdata[k]) { bad = k; break; }
	if (st < 0 || (st & 0x5c) || taken != 512 || bad >= 0 || mcu_writes != writes0 + 1) {
		printf("FAIL write: status %02x, %d bytes taken, %d mcu writes, first difference at %d\n", st, taken, mcu_writes - writes0, bad);
		fails++;
	}
	else printf("ok   A: write lba %u: status %02x, the image has the 512 bytes (mcu reads %d)\n", wlba, st, mcu_reads - reads0);
	check_read("A: read back the written sector", 0, 4, wlba);

	select(1, 0);
	st = (wr(0, 0x08), wait_irq("B: restore"));
	check_read("B: track 0 side 0 sector 1", 1, 1, 0);

	// write protect (the mount of a read only image)
	wprot[0] = true;
	tb->img_wp = 1;
	select(0, 0);
	std::vector<uint8_t> before(disk[0].begin() + 2 * 512, disk[0].begin() + 3 * 512);
	writes0 = mcu_writes;
	st = (wr(0, 0x08), wait_irq("restore"));
	st = write_sector("A: write protected", 3, wdata, &taken);
	bool same = std::equal(before.begin(), before.end(), disk[0].begin() + 2 * 512);
	if (st < 0 || !(st & 0x40) || mcu_writes != writes0 || !same) {
		printf("FAIL write protect: status %02x, %d mcu writes, image %s\n", st, mcu_writes - writes0, same ? "same" : "changed");
		fails++;
	}
	else printf("ok   A: write protected: status %02x, no write\n", st);

	printf("%s: %d failed, %.1f ms of 32 MHz\n", fails ? "FAIL" : "PASS", fails, ticks / 32000.0);
	delete tb;
	return fails ? 1 : 0;
}
