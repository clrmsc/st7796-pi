# ST7796S SPI-дисплей для Raspberry Pi

Установка 4" SPI-дисплея на ST7796S (480×320) с тачем XPT2046 на Raspberry Pi OS Trixie/Bookworm.
Используется штатный DRM-драйвер `panel-mipi-dbi`, а не устаревший `fbtft`. Рассчитано на Pi Zero, должно работать на любой Pi.

## Установка

```bash
git clone https://github.com/clrmsc/st7796-pi.git st7796-pi
cd st7796-pi
sudo ./install.sh
sudo reboot
```

## Подключение (SPI0)

| Модуль | Пин Pi | GPIO |
|---|---|---|
| VCC | 1 (3.3V) / 2 (5V, если на модуле есть стабилизатор) | — |
| GND | 6 | — |
| CS | 24 | GPIO8 (CE0) |
| RESET | 22 | GPIO25 |
| DC/RS | 18 | GPIO24 |
| SDI/MOSI | 19 | GPIO10 |
| SCK | 23 | GPIO11 |
| LED | 12 | GPIO18 |
| SDO/MISO | 21 | GPIO9 (можно не подключать) |
| T_CLK | 23 | GPIO11 |
| T_DIN | 19 | GPIO10 |
| T_DO | 21 | GPIO9 |
| T_CS | 26 | GPIO7 (CE1) |
| T_IRQ | 11 | GPIO17 |

## Опции

```
--rotate 0|90|180|270   ориентация (по умолчанию 90: альбомная, 480x320)
--dc N / --reset N      другие GPIO для DC и RESET
--bl N|none             GPIO подсветки (none: LED подключён к 3.3V)
--speed HZ              частота SPI (по умолчанию 32 МГц)
--no-touch              без тача
--irq N                 GPIO прерывания тача
--invert                инверсия цветов (часто нужна для IPS)
--rgb                   поменять местами красный и синий
--console               вывести текстовую консоль на экран
```

Скрипт можно запускать повторно с другими опциями: старый блок в `config.txt` заменяется.

## Если что-то не так

- **Белый экран.** Проверьте DC, RESET и CS. Попробуйте `--speed 16000000`.
- **Негатив.** Запустите с `--invert`.
- **Красный и синий перепутаны.** Запустите с `--rgb`.
- **Тач реагирует зеркально.** Поправьте матрицу в `/etc/udev/rules.d/99-st7796-touch.rules`.
- **Диагностика:** `./diag.sh` — собирает всю информацию.
- **Проверка:** `dmesg | grep -iE 'mipi|panel|ads7846'`, `ls /dev/fb*`.
  Тест: `cat /dev/urandom | sudo tee /dev/fb1 >/dev/null`.

## Удаление

```bash
sudo ./uninstall.sh
```
