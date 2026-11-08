# План ядра Atari ST / STE для Karabas Go / Mini / Mini G

Цель: Atari ST и STE (520 / 1040 ST, STE, 4 МБ ST RAM) на платах Karabas (XC6SLX25, ISE 14.7). Основа — [MiSTeryNano](https://github.com/harbaum/MiSTeryNano) Тилля Харбаума (порт [MiSTery](https://github.com/gyurco/MiSTery) Дьёрдя Сомбатхейи на Tang Nano 20K и другие платы), так же как NanoMig стал основой ядра Amiga (`karabas-go-core-nanomig`). Файлы идут через прошивку (OSD, `FL`, `F`, burst, `img_sdc`): загрузчика и soft-CPU в ядре нет. Железо и карта памяти: `docs/HARDWARE.md`. Открытые вопросы: `docs/BACKLOG.md`.

## Что изучено

### MiSTeryNano (harbaum/MiSTeryNano, c8e4601, 2026-08-14)

| Часть | Файлы | Лицензия | XST, LUT (2026-11-08, отдельно, без правок) |
|---|---|---|---|
| CPU 68000, потактово точный | `fx68k/` (Jorge Cwik, SystemVerilog) | GPL v3 | 3773, 4 RAMB16 |
| GSTMCU (Glue + MMU) и Shifter STE | `gstmcu/hdl/` (gyurco, по схемам Christian Zietz) | GPL | 808 + 484 |
| Blitter | `atarist/stBlitter.sv` | GPL | 834 |
| IKBD: HD6301 + ПЗУ клавиатуры | `ikbd/` (HD63701 — MiSTer, `ikbd.hex` — ПЗУ Atari) | GPL / ПЗУ Atari | 1950 |
| MFP 68901, 2 × ACIA 6850 | `atarist/mfp*.v`, `acia.v` | GPL | 734 + 116 × 2 |
| FDC WD1772 | `fdc1772/` (общий модуль MiST, `.st`) | GPL | 1669 |
| DMA + ACSI | `atarist/dma.v`, `acsi.v` | GPL | **9351** (буфер ACSI 512 Б с асинхронным чтением ушёл в LUT) |
| YM2149 | `jt49/` (jotego) | GPL v3 | 394 |
| SDRAM (16 бит, Primer 25K) | `tang/primer25k/sdram.v` (Harbaum) | GPL v3 | — |
| Связь с MCU, OSD, HID, SD | `misc/` (FPGA Companion) | GPL v3 | не берём: у нас `kg_mcu` |

Весь `atarist` после `sv2v` (две правки: `$clog2` в `fdc1772`, смешанные присваивания `old_flg`) — **19 878 LUT (132 %)**, 8834 триггера, 9 RAMB16, 2 DSP48. Без раздутого буфера ACSI около 11 500 LUT (77 %): впритык, как nanomig (91 % LUT на Mini G).

Интерфейсы `atarist.v` уже такие, как нам нужно: секторный интерфейс SD MiST (`sd_lba`, `sd_rd`, `sd_wr`, `sd_ack`, `sd_buff_addr`, `sd_dout_strobe`) для дискет и отдельный для ACSI (`acsi_*`, как `sdc_*` у nanomig: `img_sdc` подходит), матрица клавиатуры, джойстики, шина DRAM (`ram_ras_n`, `ram_cash_n`, `ram_casl_n`, `ram_ref`), шина TOS (`rom_n`, `rom_addr`), RGB 4:4:4 + синхро. Один клок `clk_32` (32,084988 МГц).

### Другие

- [gyurco/MiSTery](https://github.com/gyurco/MiSTery): исходное ядро MiST, тот же код.
- MiST / MiSTer `Atari ST` (Harbaum, на TG68K, старый) — не берём.
- [EmuTOS](https://emutos.sourceforge.io/) (GPL v2): свободная замена TOS, 192 / 256 КБ, работает на ST и STE.

## Решения

Решения пользователя (2026-11-08):

1. **CPU fx68k через `sv2v`** (как в оригинале: GSTMCU рассчитан на его шину phi1 / phi2, потактовая точность нужна играм и демо). TG68K не берём.
2. **ST RAM в SDRAM, TOS в SRAM.** ST RAM до 4 МБ (+ 8 МБ extra RAM апстрима) в SDRAM платы (MT48LC16M16A2, 16 бит) контроллером `sdram.v` апстрима на 32 МГц; TOS (192 / 256 КБ, ST и STE) — в SRAM, его пишет загрузчик прошивки. SRAM остаётся почти свободной: место для кадрового буфера, если понадобится.

Подтверждены пользователем 2026-11-08 (вместе с ПЗУ IKBD апстрима в репозитории и `.kg`):

3. **Имя `atarist`** (`atarist.kg`, папка `/atarist`), порядок 17.
4. **TOS — файл `FL`** (`.img`, `.rom`, автозагрузка, по умолчанию `/atarist/tos.img`), как Kickstart в nanomig. В `.kg` встроен **EmuTOS** (свободный), чтобы ядро стартовало без файла. ПЗУ Atari в репозиторий не кладём; ПЗУ IKBD апстрима — вопрос в BACKLOG.
5. **Видео.** ST в цвете при 50 Гц: строка 64 мкс (512 тактов 8 МГц), 313 строк. Удвоение строк даёт 31,25 кГц и 626 строк — почти ровно 576p50 (625), как Amber в nanomig, который монитор пользователя принимает. Ф1: удвоитель строк → HDMI 576p50 с окном DE 720 × 576. 60 Гц (NTSC, 263 строки) и монохром 640 × 400 @ 71 Гц монитор, скорее всего, не примет: для них кадровый буфер в SRAM с выводом в стандартном режиме (Ф3).
6. **Свой верх платы**, общий код через modules (`kg_mcu`, `img_sdc`, OSD, HDMI, PCM5102), Makefile, `sv2v` для SV. Импортированный код помечается `// karabas:`. Первым — Mini G, затем Go и Mini.
7. **Mini G2:** SDRAM ~CS на T3 (`FLASH_CS_N`). Ядро с RAM в SDRAM на G2 не заработает, пока T3 = 1; в верхах Mini / Mini G вести T3 = 0 (безопасно: флеш конфигурации на Mini не ставится).

## Архитектура

```
 atarist (апстрим)  ├── fx68k ── GSTMCU (Glue/MMU) ── Shifter ── RGB 4:4:4 → удвоитель строк → OSD → HDMI 576p50
                    ├── MFP, ACIA × 2, IKBD (HD6301), YM2149, DMA-звук STE, Blitter
                    ├── DMA ─┬─ FDC 1772 ── sd_* ─┐
                    │        └─ ACSI ─── acsi_* ─┴─ img_sdc ── kg_mcu (file mounter)
                    ├── шина DRAM ── sdram.v (32 МГц) ── SDRAM платы: ST RAM 4 МБ (+ 8 МБ)
                    └── шина TOS ─── SRAM платы ← загрузчик (ROM loader / FL)
 kg_mcu ──── HID (клавиатура → матрица IKBD, мышь, джойстики), soft switches, RTC, OSD
```

## Фазы

Каждая фаза: своя ветка, один PR в конце. Симуляция до железа. Перед любой проверкой на плате — спросить пользователя.

### Ф0. Импорт и проверка размера

Импорт апстрима без изменений (отдельный коммит), `sv2v` для SV, правки под XST, буфер ACSI и микрокод HD6301 — в BRAM. `make atarist-xst`: весь `atarist` без защёлок, цель — не больше ~75 % LUT. Симуляция (verilator, как `sim/` апстрима): EmuTOS стартует, картинка кадра из видеовыхода.

Итог Ф0 (2026-11-08): апстрим импортирован без изменений (fdfcf3b). `src/tools/sv2v.sh` прогоняет через `sv2v` весь апстрим (и SV, и `.v` с конструкциями SV) — по файлу на модуль в `src/rtl/sv2v/`, их и читает XST. Правки в исходниках (`// karabas:`): пути `$readmem` от `src/`; `$clog2` в `fdc1772`; регистры блока RTC в `atarist.v` вынесены на уровень модуля (`sv2v` сделал из начального значения блокирующее присваивание на каждом такте); буфер сектора ACSI в `dma.v` — в BRAM (один порт записи, по копии на каждого читателя, чтение с прежним таймингом; было 9000 LUT). `make atarist-xst`: **11 392 LUT (75 %)**, 4713 триггеров, 10 RAMB16, 2 DSP48, один клок, защёлок нет, оценка XST 43,9 МГц (нужно 32). `src/sim/run_boot.sh` (verilator, ОЗУ и TOS — массивы C++ на шинах `atarist`, кадры в PPM; 50 мс за 4 с): EmuTOS 1.4 находит 1 МБ, ставит экран на F8000, рисует заставку «EmuTOS Version 1.4», к 400 мс видит A: и B:. Ещё можно ужать: таблица делителей UART в MFP (1024 × 24 в LUT).

### Ф1. ST на Mini G

PLL 50 → 32,08 МГц, SDRAM, TOS из SRAM (загрузчик и `FL`), удвоитель строк, HDMI 576p50, OSD, звук YM и DMA-звук STE (HDMI и PCM5102), клавиатура и мышь USB → IKBD, джойстики, сброс. На плате: рабочий стол TOS / EmuTOS, мышь, клавиатура.

Ход Ф1 (2026-11-08, ветка `f1-minig`): верх Mini G (`karabas_minig_top.v`). Клок 32,000 МГц (PLL 50 × 16 / 25) вместо 32,084988: строка ST ровно 64 мкс, удвоенная — 31,25 кГц (`SYSTEM_CLOCK` MFP поправлен). ST RAM 4 МБ в SDRAM через `sdram.v` апстрима (шина 16 бит, два AUTO REFRESH при инициализации, WRITE на такт позже с данными и DQM в регистрах — данные записи шины ST готовы только после фронта state 1), `/CS` SDRAM на `FLASH_CS_N` для Mini G2. TOS в SRAM (`st_sram`): EmuTOS из `.kg` по адресу 100000, файл TOS (FL 7) по адресу 0, после загрузки файла читается он. HID (`st_hid`): отчёт USB-клавиатуры опрашивается последовательно через одну таблицу в матрицу IKBD, мышь — квадратурой, джойстики, F12 — сброс. Видео как у MiSTeryNano: `video_analyzer` + `scandoubler` + развёртка `st_video_out` (1024 × 626, окно 720 × 576, 576p50; NTSC 720 × 480; моно 640 × 400 @ 71 Гц), OSD, HDMI со звуком YM / DMA, PCM5102. Симуляция `run_top.sh` с моделями SDRAM и SRAM: EmuTOS видит 4 МБ, режим PAL, заставка в окне, клавиша доходит до IKBD. Сборка: 76 % LUT, 89 % слайсов, 12 RAMB16, `clk_sys` с запасом 1,0 нс (до исправления записи SDRAM).

### Ф2. Дискеты

`.st` в A: и B: через `img_sdc` (F-слоты 0 и 1), чтение и запись, защита записи, смена диска. На плате: игры с дискет.

### Ф3. Жёсткий диск и настройки

ACSI 0 и 1 (`.hd`, F-слоты 2 и 3), опции ST / STE, Blitter, объём памяти, часы из `kg_mcu` (`rtc`), 60 Гц и монохром (кадровый буфер в SRAM, если удвоитель не подходит монитору).

### Ф4. Go и Mini, выпуск

Верхи Go и Mini, `core.json` на все платы, README (en + ru), выпуск в `karabas-go` и `cores.json`.

### Потом (BACKLOG)

MIDI (USB MIDI IN прошивки → ACIA MIDI, выход — SAM2695), физический дисковод Go, последовательный порт через USB-UART / ESP, принтер, донглы Cubase.
