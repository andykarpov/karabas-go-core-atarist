#!/bin/bash
# Builds and runs tb_floppy (fdc1772 of rtl/sv2v + img_sdc + a model of the mcu firmware): read,
# write, seek, both drives, write protect. A few seconds.
set -e
cd "$(dirname "$0")"
mkdir -p build
cd ..
SRC="rtl/sv2v/fdc1772.v rtl/sv2v/floppy.v rtl/sv2v/fdc_dpram.v ../modules/rtl/mcu/img_sdc.v sim/tb_floppy.v"
BIN=sim/build/floppy/Vtb_floppy
if [ ! -x $BIN ] || [ -n "$(find $SRC sim/tb_floppy.cpp sim/run_floppy.sh -newer $BIN 2>/dev/null)" ]; then
	verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN \
		--no-timing --top-module tb_floppy -Mdir sim/build/floppy --cc $SRC \
		--exe $PWD/sim/tb_floppy.cpp -o Vtb_floppy > sim/build/verilator_floppy.log 2>&1 || { tail -30 sim/build/verilator_floppy.log; exit 1; }
	make -s -j8 -C sim/build/floppy -f Vtb_floppy.mk > sim/build/make_floppy.log 2>&1 || { tail -30 sim/build/make_floppy.log; exit 1; }
fi
exec $BIN "$@"
