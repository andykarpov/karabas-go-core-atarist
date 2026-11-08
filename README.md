# Atari ST / STE core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

Atari ST, Mega ST and STE for the Karabas Go board family. A port of [MiSTeryNano](https://github.com/harbaum/MiSTeryNano) (Till Harbaum's port of [MiSTery](https://github.com/gyurco/MiSTery) by Gyorgy Szombathelyi) to the Xilinx Spartan-6 XC6SLX25.

| Board | Core file | Video | Sound |
|---|---|---|---|
| Karabas Go | `atarist.kg` | VGA | I2S DAC (PCM5102) |
| Karabas Mini | `atarist.kg` | HDMI | HDMI, analog output (sigma-delta) |
| Karabas Mini G | `atarist.kg` | HDMI | HDMI, I2S DAC |

The core file is in `src/`. It contains EmuTOS (free software) as the default TOS, and no Atari ROM.

Status: checked on Mini G. The Go and Mini builds have not been run on a board yet.

## Features

- **CPU:** 68000 at 8 MHz (fx68k).
- **Chipset:** ST, Mega ST (with Blitter) or STE (OSD item Chipset).
- **Memory:** 4 MB of ST RAM.
- **TOS:** EmuTOS is built in. Another TOS image can be loaded from the SD card.
- **Floppies:** A: and B:, `.st` images, read and write.
- **Hard disks:** two ACSI drives, `.hd` or `.img` images, read and write.
- **Clock:** the Mega ST clock, kept by the clock of the board.
- **Input:** USB keyboard and mouse, two joysticks.
- **Video:** 50 Hz and 60 Hz colour through a line doubler; 640 x 400 at 71 Hz with Monitor = Mono (not every monitor accepts this mode).
- **Sound:** YM2149 and the STE DMA sound.

Not supported: smaller memory sizes, MIDI, serial and parallel ports, the physical floppy drive of the Go.

## Getting started

1. Copy `atarist.kg` (one file for Go, Mini and Mini G) to the root of the SD card.
2. Put your disk images in `/atarist` on the SD card.
3. Choose Atari ST in the core menu. EmuTOS starts its desktop. Open the OSD (**Menu+Esc**) to insert disks.

"Menu" is the Windows key of the keyboard.

## OSD menu

| Item | Values | Hotkey |
|---|---|---|
| Floppy A, Floppy B | `.st` image | Menu+F1, Menu+F2 |
| HDD 0, HDD 1 | `.hd` or `.img` image | Menu+F3, Menu+F4 |
| TOS | `.img` or `.rom` file (autoloaded from `/atarist/tos.img`) | Menu+T |
| Chipset | ST / Mega ST / STE | Menu+C |
| Monitor | Color / Mono | Menu+M |
| Reset | resets the machine | F12 |

A change of Chipset or Monitor restarts the machine. The settings and the chosen images are remembered.

## Hard disk images

A hard disk image needs a partition table with a FAT16 partition. EmuTOS does not read FAT32. On Linux, with an MBR partition of type 06 at sector 2048:

```
mformat -i disk.hd@@1M -T <sectors> -c 4 -r 32 -h 16 -s 63 -v NAME ::
```

The original Atari TOS has no hard disk driver of its own: it needs one (AHDI, for example) on the disk.

## Building

Clone with `--recursive` (the `modules` submodule). ISE 14.7: `cd src && make` for all boards or `make minig` for one. The plan and the design notes are in [docs/PLAN.md](docs/PLAN.md) (Russian).

## License

GPL v3 ([LICENSE](LICENSE)).
