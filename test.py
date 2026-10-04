#!/usr/bin/env python3
"""Raw hardware test for ST7796/ILI948x SPI panels, bypassing the kernel driver.

Temporarily unbinds panel-mipi-dbi from spi0.0, binds spidev instead and
tries several pin/color-format combinations, filling the screen with
red, green and blue. Watch the display and note which test shows colors.

Needs: sudo apt install -y python3-spidev python3-libgpiod
Run:   sudo ./test.py [--speed HZ]
Reboot afterwards to give the panel back to the kernel driver.
"""
import glob
import os
import sys
import time

import gpiod
import spidev
from gpiod.line import Direction, Value

W, H = 320, 480
SPEED = 8000000
if "--speed" in sys.argv:
    SPEED = int(sys.argv[sys.argv.index("--speed") + 1])

DEV = "/sys/bus/spi/devices/spi0.0"


def sysfs_write(path, value):
    try:
        with open(path, "w") as f:
            f.write(value)
    except OSError:
        pass


def take_over_spi():
    if os.path.exists(DEV + "/driver"):
        drv = os.path.realpath(DEV + "/driver")
        if os.path.basename(drv) != "spidev":
            print(f"Отключаю драйвер {os.path.basename(drv)} от spi0.0")
            sysfs_write(drv + "/unbind", "spi0.0")
    if not os.path.exists("/dev/spidev0.0"):
        sysfs_write(DEV + "/driver_override", "spidev")
        sysfs_write("/sys/bus/spi/drivers/spidev/bind", "spi0.0")
    time.sleep(0.5)
    if not os.path.exists("/dev/spidev0.0"):
        sys.exit("Не удалось получить /dev/spidev0.0")


def find_gpiochip():
    for path in sorted(glob.glob("/dev/gpiochip*")):
        with gpiod.Chip(path) as chip:
            info = chip.get_info()
            if "bcm2835" in info.label or info.num_lines >= 54:
                return path
    return "/dev/gpiochip0"


class Panel:
    def __init__(self, chip, dc, rst):
        self.dc, self.rst = dc, rst
        self.req = gpiod.request_lines(
            chip, consumer="st7796-test",
            config={(dc, rst): gpiod.LineSettings(direction=Direction.OUTPUT)})
        self.spi = spidev.SpiDev()
        self.spi.open(0, 0)
        self.spi.max_speed_hz = SPEED
        self.spi.mode = 0

    def close(self):
        self.spi.close()
        self.req.release()

    def cmd(self, c, *data):
        self.req.set_value(self.dc, Value.INACTIVE)
        self.spi.writebytes2([c])
        if data:
            self.req.set_value(self.dc, Value.ACTIVE)
            self.spi.writebytes2(list(data))

    def reset(self):
        self.req.set_value(self.rst, Value.ACTIVE)
        time.sleep(0.02)
        self.req.set_value(self.rst, Value.INACTIVE)
        time.sleep(0.02)
        self.req.set_value(self.rst, Value.ACTIVE)
        time.sleep(0.15)

    def init(self, bits):
        self.reset()
        self.cmd(0x01)                      # software reset
        time.sleep(0.15)
        self.cmd(0x11)                      # sleep out
        time.sleep(0.12)
        self.cmd(0x3A, 0x55 if bits == 16 else 0x66)
        self.cmd(0x36, 0x48)                # MADCTL portrait, BGR
        self.cmd(0x29)                      # display on
        time.sleep(0.05)

    def fill(self, rgb, bits):
        r, g, b = rgb
        self.cmd(0x2A, 0, 0, (W - 1) >> 8, (W - 1) & 0xFF)
        self.cmd(0x2B, 0, 0, (H - 1) >> 8, (H - 1) & 0xFF)
        self.cmd(0x2C)
        if bits == 16:
            v = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
            px = bytes([v >> 8, v & 0xFF])
        else:
            px = bytes([r, g, b])
        self.req.set_value(self.dc, Value.ACTIVE)
        self.spi.writebytes2(px * (W * H))


def main():
    if os.geteuid() != 0:
        sys.exit("Запустите через sudo")
    take_over_spi()
    chip = find_gpiochip()
    print(f"GPIO: {chip}, SPI: {SPEED} Hz\n")

    tests = [
        (25, 24, 16), (25, 24, 18),
        (24, 25, 16), (24, 25, 18),
    ]
    colors = [("КРАСНЫЙ", (255, 0, 0)), ("ЗЕЛЁНЫЙ", (0, 255, 0)),
              ("СИНИЙ", (0, 0, 255)), ("ЧЁРНЫЙ", (0, 0, 0))]
    for n, (dc, rst, bits) in enumerate(tests, 1):
        print(f"Тест {n}: DC=GPIO{dc}, RST=GPIO{rst}, цвет {bits} бит")
        p = Panel(chip, dc, rst)
        try:
            p.init(bits)
            for name, rgb in colors:
                print(f"   {name}")
                p.fill(rgb, bits)
                time.sleep(1.5)
        finally:
            p.close()
        print()

    print("Готово. Напишите, в каком тесте экран менял цвета.")
    print("После теста перезагрузитесь: sudo reboot")


if __name__ == "__main__":
    main()
