#!/usr/bin/env bash
# Remove everything install.sh added.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }

if [[ -f /boot/firmware/config.txt ]]; then BOOT=/boot/firmware; else BOOT=/boot; fi

sed -i '/^# >>> st7796 >>>/,/^# <<< st7796 <<</d' "$BOOT/config.txt"
sed -i 's/ *fbcon=map:[0-9]*//' "$BOOT/cmdline.txt"
rm -f /lib/firmware/st7796s.bin /etc/udev/rules.d/99-st7796-touch.rules

echo "Removed. Reboot to apply: sudo reboot"
