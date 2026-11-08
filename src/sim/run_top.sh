#!/bin/bash
# Builds the verilator model of sim_top.v (the machine of rtl/sv2v with sdram.v, st_sram, st_hid
# and the video chain on memory models) and runs sim_top with the given arguments (sim_top.cpp).
#   ./run_top.sh --ms 400 --ppm sim/build/top --every 5
set -e
cd "$(dirname "$0")"
mkdir -p build
cd ..
SRC=$( (sed -n 's/^verilog work "\(rtl\/sv2v\/.*\)"/\1/p' atarist.prj; echo ../modules/rtl/mem/kg_sdpram.v ../modules/rtl/mcu/img_sdc.v rtl/st/st_sram.v rtl/st/st_hid.v rtl/st/st_video_out.v sim/sim_top.v) | tr '\n' ' ')
BIN=sim/build/top/Vsim_top
if [ ! -x $BIN ] || [ -n "$(find $SRC sim/sim_top.cpp sim/run_top.sh -newer $BIN 2>/dev/null)" ]; then
	verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN \
		--no-timing --top-module sim_top -Mdir sim/build/top --cc $SRC \
		--exe $PWD/sim/sim_top.cpp -o Vsim_top > sim/build/verilator_top.log 2>&1 || { tail -30 sim/build/verilator_top.log; exit 1; }
	make -s -j8 -C sim/build/top -f Vsim_top.mk > sim/build/make_top.log 2>&1 || { tail -30 sim/build/make_top.log; exit 1; }
fi
# from src/: the $readmem paths of the sources (rtl/...)
exec $BIN "$@"
