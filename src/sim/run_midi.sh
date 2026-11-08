#!/bin/bash
# Builds and runs tb_midi (kg_midi_tx + the MIDI ACIA). Seconds.
set -e
cd "$(dirname "$0")"
mkdir -p build
cd ..
SRC="../modules/rtl/mem/kg_fifo.v ../modules/rtl/audio/kg_midi_tx.v rtl/sv2v/acia.v sim/tb_midi.v"
verilator -O2 -Wno-fatal -Wno-lint -Wno-style --no-timing --top-module tb_midi \
	-Mdir sim/build/midi --cc $SRC --exe $PWD/sim/tb_midi.cpp -CFLAGS -std=gnu++17 -o Vtb_midi > sim/build/verilator_midi.log 2>&1 || { tail -30 sim/build/verilator_midi.log; exit 1; }
make -s -j8 -C sim/build/midi -f Vtb_midi.mk > sim/build/make_midi.log 2>&1 || { tail -30 sim/build/make_midi.log; exit 1; }
exec sim/build/midi/Vtb_midi "$@"
