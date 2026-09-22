#!/usr/bin/env bash
# Kernel-inhibit the touchscreen right before detach, so the clipboard never
# sees live touch events while unplugged and re-attaches with a clean slate.
# Optional: touch.inhibit_on_detach=1 in /etc/surfacebook/tablet.conf.
. "$(dirname "$(readlink -f "$0")")/../lib.sh"

if [ "$(sh_cfg touch.inhibit_on_detach 0)" != "1" ]; then
  exit 0
fi

# NOTE: on this hardware the laptop's touchscreen is the IPTS digitizer the
# kernel does not expose, so this is a no-op unless the display serves one.
for dev in $(touch_devices); do
  echo 1 > "$dev/inhibited" 2>/dev/null && log_ev "inhibited $dev"
done
exit 0