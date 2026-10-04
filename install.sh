#!/usr/bin/env bash
# Install ST7796S SPI display (panel-mipi-dbi) + optional XPT2046 touch
# for Raspberry Pi OS (Bookworm/Trixie).
set -euo pipefail

ROTATE=90
DC=24
RESET=25
BL=18
SPEED=32000000
TOUCH=1
IRQ=17
INVERT=0
RGB=0
CONSOLE=0

usage() {
    cat <<EOF
Usage: sudo ./install.sh [options]

  --rotate 0|90|180|270   orientation (default: 90, landscape 480x320)
  --dc N                  DC/RS GPIO (default: $DC)
  --reset N               RESET GPIO (default: $RESET)
  --bl N                  backlight GPIO, 'none' to skip (default: $BL)
  --speed HZ              SPI clock (default: $SPEED)
  --no-touch              do not enable XPT2046 touch
  --irq N                 touch IRQ GPIO (default: $IRQ)
  --invert                enable color inversion (IPS panels)
  --rgb                   RGB order instead of BGR (red/blue swapped)
  --console               show text console on the display (fbcon)
  -h, --help              this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rotate)   ROTATE="$2"; shift 2 ;;
        --dc)       DC="$2"; shift 2 ;;
        --reset)    RESET="$2"; shift 2 ;;
        --bl)       BL="$2"; shift 2 ;;
        --speed)    SPEED="$2"; shift 2 ;;
        --no-touch) TOUCH=0; shift ;;
        --irq)      IRQ="$2"; shift 2 ;;
        --invert)   INVERT=1; shift ;;
        --rgb)      RGB=1; shift ;;
        --console)  CONSOLE=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0 $*"; exit 1; }

cd "$(dirname "$(readlink -f "$0")")"

if [[ -f /boot/firmware/config.txt ]]; then
    BOOT=/boot/firmware
else
    BOOT=/boot
fi
CONFIG=$BOOT/config.txt
CMDLINE=$BOOT/cmdline.txt

# MADCTL: MY=0x80 MX=0x40 MV=0x20 BGR=0x08
# Touch: libinput calibration matrix matching the rotation
case "$ROTATE" in
    0)   MADCTL=0x40; W=320; H=480; MATRIX="1 0 0 0 1 0" ;;
    90)  MADCTL=0x20; W=480; H=320; MATRIX="0 1 0 -1 0 1" ;;
    180) MADCTL=0x80; W=320; H=480; MATRIX="-1 0 1 0 -1 1" ;;
    270) MADCTL=0xE0; W=480; H=320; MATRIX="0 -1 1 1 0 0" ;;
    *) echo "--rotate must be 0, 90, 180 or 270"; exit 1 ;;
esac
[[ $RGB -eq 1 ]] || MADCTL=$(printf '0x%02X' $((MADCTL | 0x08)))
if [[ $W -eq 480 ]]; then WMM=85; HMM=56; else WMM=56; HMM=85; fi

echo "==> Building firmware (rotate=$ROTATE, MADCTL=$MADCTL, ${W}x${H})"
FWARGS=(--madctl "$MADCTL")
[[ $INVERT -eq 1 ]] && FWARGS+=(--invert)
python3 mkfw.py st7796s.txt /lib/firmware/st7796s.bin "${FWARGS[@]}"

echo "==> Updating $CONFIG"
cp "$CONFIG" "$CONFIG.bak-st7796"
sed -i '/^# >>> st7796 >>>/,/^# <<< st7796 <<</d' "$CONFIG"
{
    echo "# >>> st7796 >>>"
    echo "dtparam=spi=on"
    echo "dtoverlay=mipi-dbi-spi,spi0-0,speed=$SPEED"
    echo "dtparam=compatible=st7796s\\0panel-mipi-dbi-spi"
    echo "dtparam=width=$W,height=$H,width-mm=$WMM,height-mm=$HMM"
    echo "dtparam=reset-gpio=$RESET,dc-gpio=$DC,write-only"
    [[ "$BL" != "none" ]] && echo "dtparam=backlight-gpio=$BL"
    if [[ $TOUCH -eq 1 ]]; then
        echo "dtoverlay=ads7846,cs=1,penirq=$IRQ,penirq_pull=2,speed=50000,xohms=150,pmax=255"
    fi
    echo "# <<< st7796 <<<"
} >> "$CONFIG"

RULE=/etc/udev/rules.d/99-st7796-touch.rules
if [[ $TOUCH -eq 1 ]]; then
    echo "==> Writing touch calibration $RULE"
    echo "ENV{ID_INPUT_TOUCHSCREEN}==\"1\", ENV{LIBINPUT_CALIBRATION_MATRIX}=\"$MATRIX\"" > "$RULE"
else
    rm -f "$RULE"
fi

if [[ $CONSOLE -eq 1 ]]; then
    echo "==> Enabling console on display ($CMDLINE)"
    cp "$CMDLINE" "$CMDLINE.bak-st7796"
    sed -i 's/ *fbcon=map:[0-9]*//' "$CMDLINE"
    # fb0 = HDMI (if present), the SPI panel becomes fb1
    sed -i '1 s/$/ fbcon=map:1/' "$CMDLINE"
fi

echo
echo "Done. Backup: $CONFIG.bak-st7796"
echo "Reboot to apply:  sudo reboot"
echo "Check after reboot:  dmesg | grep -iE 'mipi|panel|ads7846'; ls /dev/fb*"
