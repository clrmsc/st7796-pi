#!/usr/bin/env bash
# Collect diagnostics for the ST7796 display setup.
if [[ -f /boot/firmware/config.txt ]]; then BOOT=/boot/firmware; else BOOT=/boot; fi

section() { echo; echo "=== $1 ==="; }

section "system"
uname -a
grep -E 'PRETTY_NAME' /etc/os-release
tr -d '\0' < /proc/device-tree/model; echo

section "config.txt (st7796 block)"
sed -n '/st7796 >>>/,/st7796 <<</p' "$BOOT/config.txt"

section "other dtoverlay/spi lines"
grep -nE '^\s*(dtoverlay|dtparam)' "$BOOT/config.txt"

section "cmdline.txt"
cat "$BOOT/cmdline.txt"

section "firmware"
ls -l /lib/firmware/st7796s.bin && xxd /lib/firmware/st7796s.bin | head -3

section "overlay file"
ls -l "$BOOT"/overlays/mipi-dbi-spi.dtbo

section "modules"
lsmod | grep -iE 'mipi|panel|spi|drm' || echo "(none)"

section "devices"
ls -l /dev/fb* /dev/dri/ /dev/spidev* 2>&1
ls /sys/bus/spi/devices/ 2>&1
for d in /sys/bus/spi/devices/*; do
    echo "$d: $(cat "$d/modalias" 2>/dev/null) driver=$(basename "$(readlink "$d/driver" 2>/dev/null)")"
done

section "dmesg"
dmesg | grep -iE 'mipi|panel|spi|st7796|firmware|drm|fb[0-9]|ads7846' | tail -40
