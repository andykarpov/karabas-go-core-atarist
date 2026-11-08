#!/bin/bash
# Builds the verilator model of the Atari ST machine (rtl/sv2v, the files of atarist.prj) and runs
# sim_atarist with the given arguments (see sim_atarist.cpp). The build goes to src/sim/build.
#   ./run_boot.sh --ms 50 --ppm build/frame
set -e
cd "$(dirname "$0")"
SRC=..
mkdir -p build
SOURCES=$(sed -n 's/^verilog work "\(.*\)"/\1/p' $SRC/atarist.prj | sed "s#^#$SRC/#")
STAMP=build/obj/Vatarist
if [ ! -x $STAMP ] || [ -n "$(find $SOURCES sim_atarist.cpp run_boot.sh -newer $STAMP 2>/dev/null)" ]; then
	# the ROM paths of the sources are relative to src/, where XST runs
	(cd $SRC && verilator -O2 -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN \
		--no-timing --top-module atarist -Mdir sim/build/obj --cc $(sed -n 's/^verilog work "\(.*\)"/\1/p' atarist.prj) \
		--exe $PWD/sim/sim_atarist.cpp -o Vatarist > sim/build/verilator.log 2>&1) || { tail -30 build/verilator.log; exit 1; }
	make -s -j8 -C build/obj -f Vatarist.mk > build/make.log 2>&1 || { tail -30 build/make.log; exit 1; }
fi
# run from src/ so that the $readmem paths (rtl/...) resolve
cd $SRC
exec sim/build/obj/Vatarist --tos roms/etos192uk.img "$@"
