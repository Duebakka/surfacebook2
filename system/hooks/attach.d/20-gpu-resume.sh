#!/usr/bin/env bash
# Re-probe the NVIDIA device the clip detached with, so the driver binds it
# again on re-attach (gpu.remove_on_detach=1 only).
. "$(dirname "$(readlink -f "$0")")/../lib.sh"

[ "$(sh_cfg gpu.remove_on_detach 0)" = "1" ] || exit 0

SLOT="$(sh_cfg gpu.slot 0000:01:00.0)"
case "$SLOT" in *[!0-9a-fA-F:_.-]*|"") log_ev "bad gpu.slot '$SLOT'"; exit 0 ;; esac

if [ -d "/sys/bus/pci/devices/$SLOT" ]; then
  log_ev "attached; $SLOT already present"
  exit 0
fi
if echo 1 > /sys/bus/pci/rescan 2>/dev/null; then
  log_ev "rescanning PCI bus for $SLOT"
else
  log_ev "PCI rescan failed"
fi
exit 0