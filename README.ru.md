# Ядро Atari ST / STE для Karabas Go / Mini / Mini G

[English version](README.md)

Atari ST, Mega ST и STE для плат семейства Karabas Go. Это порт [MiSTeryNano](https://github.com/harbaum/MiSTeryNano) Тилля Харбаума (порт [MiSTery](https://github.com/gyurco/MiSTery) Дьёрдя Сомбатхейи) на Xilinx Spartan-6 XC6SLX25.

| Плата | Файл ядра | Видео | Звук |
|---|---|---|---|
| Karabas Go | `atarist.kg` | VGA | I2S ЦАП (PCM5102) |
| Karabas Mini | `atarist.kg` | HDMI | HDMI, аналоговый выход (сигма-дельта) |
| Karabas Mini G | `atarist.kg` | HDMI | HDMI, I2S ЦАП |

Файл ядра лежит в `src/`. В нём есть EmuTOS (свободное ПО) как TOS по умолчанию и нет ПЗУ Atari.

Состояние: проверено на Mini G. Сборки для Go и Mini на платах ещё не запускались.

## Что умеет

- **Процессор:** 68000 на 8 МГц (fx68k).
- **Чипсет:** ST, Mega ST (с Blitter) или STE (пункт OSD Chipset).
- **Память:** 4 МБ ST RAM.
- **TOS:** EmuTOS встроена. Другой образ TOS можно загрузить с SD-карты.
- **Дискеты:** A: и B:, образы `.st`, чтение и запись.
- **Жёсткие диски:** два диска ACSI, образы `.hd` или `.img`, чтение и запись.
- **Часы:** часы Mega ST, их ведут часы платы.
- **Ввод:** USB-клавиатура и мышь, два джойстика.
- **Видео:** цвет 50 и 60 Гц через удвоитель строк; монохром 640 × 400 при Monitor = Mono: из кадрового буфера, в том же выходе 576p 50 Гц, что и цвет.
- **MIDI:** вход от USB-MIDI-клавиатуры (через прошивку), выход на синтезатор SAM2695 платы.
- **Звук:** YM2149 и DMA-звук STE.

Чего нет: меньших объёмов памяти, последовательного и параллельного портов, физического дисковода Go.

## Как начать

1. Скопируйте `atarist.kg` (один файл для Go, Mini и Mini G) в корень SD-карты.
2. Положите образы дисков в `/atarist` на SD-карте.
3. Выберите Atari ST в меню ядер. Запустится рабочий стол EmuTOS. Диски вставляются через OSD (**Menu+Esc**).

«Menu» — это клавиша Windows на клавиатуре.

## Меню OSD

| Пункт | Значения | Горячая клавиша |
|---|---|---|
| Floppy A, Floppy B | образ `.st` | Menu+F1, Menu+F2 |
| HDD 0, HDD 1 | образ `.hd` или `.img` | Menu+F3, Menu+F4 |
| TOS | файл `.img` или `.rom` (автозагрузка из `/atarist/tos.img`) | Menu+T |
| Chipset | ST / Mega ST / STE | Menu+C |
| Monitor | Color / Mono | Menu+M |
| Reset | сброс машины | F12 |

При смене Chipset или Monitor машина перезапускается. Настройки и выбранные образы запоминаются.

## Образы жёстких дисков

Образу нужна таблица разделов с разделом FAT16. EmuTOS не читает FAT32. В Linux для раздела MBR типа 06, начинающегося с сектора 2048:

```
mformat -i disk.hd@@1M -T <секторов> -c 4 -r 32 -h 16 -s 63 -v NAME ::
```

В оригинальной TOS Atari нет собственного драйвера жёсткого диска: он должен быть на диске (например, AHDI).

## Сборка

Клонируйте с `--recursive` (подмодуль `modules`). ISE 14.7: `cd src && make` для всех плат или `make minig` для одной. План и заметки — в [docs/PLAN.md](docs/PLAN.md).

## Лицензия

GPL v3 ([LICENSE](LICENSE)).
