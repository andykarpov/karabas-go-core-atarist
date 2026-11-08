# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

An Atari ST / STE core for the Karabas Go, Mini and Mini G boards (Xilinx Spartan-6 XC6SLX25, ISE 14.7, XST): a port of [MiSTeryNano](https://github.com/harbaum/MiSTeryNano) (Till Harbaum's port of gyurco's MiSTery), as `karabas-go-core-nanomig` is a port of NanoMig.

Status: skeleton, no RTL yet. Docs, in Russian: `docs/PLAN.md` (research, decisions, phases), `docs/HARDWARE.md` (memory map, board layout), `docs/BACKLOG.md`. Follow the phases; record a changed decision in PLAN.md.

User decisions (2026-11-08): the CPU is **fx68k converted with `sv2v`** (not TG68K); **ST RAM in the SDRAM** (upstream `sdram.v`, 32 MHz), **TOS in the SRAM** (written by the firmware loader). All file work goes through the firmware (OSD, `FL` / `F` items, burst, `img_sdc`): no loader or soft CPU in the core. The core is GPL v3 (`LICENSE`).

Templates: `../karabas-go-core-nanomig` (68000 machine, `img_sdc` with a floppy and HDF, the Kickstart `FL` autoload, SDRAM fast RAM with `SDR_CLK` = inverted clock, 576p50 from a line doubler) and `../karabas-go-core-rk` (Makefile, board files, sim harness).

## Layout

- `src/Makefile`: the ISE flow, as in core-rk (`make minig`, `make minig-xst`, `make minig-report`, `make atarist-xst` = the machine alone, the fit check of Ф0). `src/karabas_<board>.{prj,xst,ut,ucf}`: its inputs.
- `src/make_core.py`: a symlink to `../../karabas-go-tools/make_core/make_core.py`. `src/tools/check_osd.py`: the slot check of `make core`.
- `src/core.json`: the core file description (kgo2, `atarist.kg`).
- `upstream/`: the MiSTeryNano top files (`misterynano.sv`, `top.sv` of the Tang Nano 20K and Primer 25K, README), a reference for the wiring, not built.
- `modules/`: the git submodule [karabas-go-modules](https://github.com/andykarpov/karabas-go-modules). Clone with `--recursive`. A change to a module is made there (branch + PR) and taken here by moving the submodule commit.

## Rules of the core

The rules of core-rk / core-specialist apply: standard video timing with syncs always present (the user's monitor rejects anything else), `FT_CLK_OUT` about 8 MHz on Mini / Mini G, Go `FDC_*` outputs 0 when unused, OSD switch index = item position unless `"index"`, an OSD value shows 10 characters at most, FL slots 0..7 only (one array with the F slots), Verilog-2001 for XST (`sv2v` for SV, no declarations in unnamed blocks), imported code marked `// karabas:`.

- Mini / Mini G tops drive T3 (`FLASH_CS_N`) = 0: on Mini G2 it is the SDRAM ~CS.
- ROMs are not ours: only those the user allowed go into the repo and the `.kg` (EmuTOS is free; Atari TOS is not).
- **Ask the user before every check on the board** (and the HDMI capture), even inside a phase. Ask before a firmware flash.
- One branch per phase of `docs/PLAN.md`, one PR at its end.
- Heavy builds: Mini G only until Ф4; map with cost table 2 first.

## Memory

The Claude Code memory of this repo is shared with all karabas-go repos: `~/.claude/projects/<this project>/memory` is a symlink to `../karabas-go-notes` (private repo `andykarpov/karabas-go-notes`). Its `MEMORY.md` is split by repo; commit and push it after every memory change.
