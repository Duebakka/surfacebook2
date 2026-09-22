#!/usr/bin/env bash
# Re-enable the touchscreen after the clipboard is back. Mirrors
# detach.d/10-inhibit-touch.sh (only has effect with touch.inhibit_on_detach=1).
. "$(dirname "$(readlink -f "$0")")/../lib.sh"

if [ "$(sh_cfg touch.inhibit_on_detach 0)" != "1" ]; then
  exit 0
fi

for dev in $(touch_devices); do
  echo 0 > "$dev/inhibited" 2>/dev/null && log_ev "uninhibited $dev"
done
exit 0