#!/bin/bash
# Builds and runs tb_acsi (dma + acsi of rtl/sv2v, img_sdc, a model of the mcu firmware). Seconds.
set -e
cd "$(dirname "$0")"
mkdir -p build
cd ..
SRC="rtl/sv2v/dma.v rtl/sv2v/acsi.v ../modules/rtl/mem/kg_sdpram.v ../modules/rtl/mcu/img_sdc.v sim/tb_acsi.v"
BIN=sim/build/acsi/Vtb_acsi
if [ ! -x $BIN ] || [ -n "$(find $SRC sim/tb_acsi.cpp sim/run_acsi.sh -newer $BIN 2>/dev/null)" ]; then
	verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-UNOPTFLAT \
		--no-timing --top-module tb_acsi -Mdir sim/build/acsi --cc $SRC \
		--exe $PWD/sim/tb_acsi.cpp -CFLAGS -std=gnu++17 -o Vtb_acsi > sim/build/verilator_acsi.log 2>&1 || { tail -30 sim/build/verilator_acsi.log; exit 1; }
	make -s -j8 -C sim/build/acsi -f Vtb_acsi.mk > sim/build/make_acsi.log 2>&1 || { tail -30 sim/build/make_acsi.log; exit 1; }
fi
exec $BIN "$@"
