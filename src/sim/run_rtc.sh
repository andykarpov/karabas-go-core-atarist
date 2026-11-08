#!/bin/bash
# Builds and runs tb_rtc (kg_mcu_rtc + st_rtc). Seconds.
set -e
cd "$(dirname "$0")"
mkdir -p build
cd ..
SRC="../modules/rtl/mem/kg_sdpram.v ../modules/rtl/mcu/kg_mcu_rtc.v rtl/st/st_rtc.v sim/tb_rtc.v"
verilator -O2 -Wno-fatal -Wno-lint -Wno-style -I../modules/rtl/mcu --no-timing --top-module tb_rtc \
	-Mdir sim/build/rtc --cc $SRC --exe $PWD/sim/tb_rtc.cpp -CFLAGS -std=gnu++17 -o Vtb_rtc > sim/build/verilator_rtc.log 2>&1 || { tail -30 sim/build/verilator_rtc.log; exit 1; }
make -s -j8 -C sim/build/rtc -f Vtb_rtc.mk > sim/build/make_rtc.log 2>&1 || { tail -30 sim/build/make_rtc.log; exit 1; }
exec sim/build/rtc/Vtb_rtc "$@"
