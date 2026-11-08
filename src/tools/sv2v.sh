#!/bin/bash
# Converts the upstream RTL (SystemVerilog and the SV-flavoured .v files of MiSTeryNano) to
# Verilog-2001 for XST with sv2v (/opt/sv2v/sv2v): one file per module in rtl/sv2v/. The tops: atarist
# (the machine) and the parts the board tops use (scandoubler, video_analyzer, keymap, sdram).
# rtl/sv2v/ is generated and in git; change the sources (with a "karabas:" comment), then run this.
set -e
cd "$(dirname "$0")/../rtl"
SV2V=${SV2V:-/opt/sv2v/sv2v}
SRC="atarist/acia.v atarist/acsi.v atarist/dma.v atarist/io_fifo.v atarist/mfp.v atarist/mfp_hbit16.v
 atarist/mfp_srff16.v atarist/mfp_timer.v atarist/stBlitter.sv atarist/ste_joypad.v
 atarist/cubase2_dongle.v atarist/cubase3_dongle.v atarist/fdc_dpram.v atarist/sector_dpram.v
 atarist/atarist.v fdc1772/fdc1772.v fdc1772/floppy.v
 fx68k/fx68k.sv fx68k/fx68kAlu.sv fx68k/uaddrPla.sv
 gstmcu/clockgen.v gstmcu/gstmcu.v gstmcu/gstshifter.v gstmcu/hdegen.v gstmcu/hsyncgen.v
 gstmcu/latch.v gstmcu/mcucontrol.v gstmcu/modules.v gstmcu/register.v gstmcu/shifter_video.v
 gstmcu/sndcnt.v gstmcu/vdegen.v gstmcu/vidcnt.v gstmcu/vsyncgen.v
 ikbd/hd63701/HD63701.v ikbd/hd63701/HD63701_ALU.v ikbd/hd63701/HD63701_CORE.v
 ikbd/hd63701/HD63701_EXEC.v ikbd/hd63701/HD63701_MCROM.v ikbd/hd63701/HD63701_SEQ.v
 ikbd/ikbd.sv ikbd/rom/MCU_BIROM.v
 jt49/filter/jt49_dcrm.v jt49/filter/jt49_dcrm2.v jt49/filter/jt49_dly.v jt49/filter/jt49_mave.v
 jt49/jt49.v jt49/jt49_bus.v jt49/jt49_cen.v jt49/jt49_div.v jt49/jt49_eg.v jt49/jt49_exp.v
 jt49/jt49_noise.v
 misc/scandoubler.v misc/video_analyzer.v misc/atarist_keymap.v sdram/sdram.v"
rm -rf sv2v && mkdir sv2v
$SV2V -I ikbd/hd63701 --top=atarist --top=scandoubler --top=video_analyzer --top=keymap --top=sdram $SRC -w sv2v 2>&1 | grep -v -E '^\s*$|Warning: Number literal|^ *[0-9]* \||^\s*\|' || true
ls sv2v | wc -l
# atarist.prj: the machine alone (make atarist-xst) and the source list of the simulations
{ echo 'verilog work "../modules/rtl/mem/kg_sdpram.v"'; for f in sv2v/*.v; do echo "verilog work \"rtl/$f\""; done; } > ../atarist.prj
