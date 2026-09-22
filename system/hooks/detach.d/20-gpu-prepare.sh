#!/usr/bin/env bash
# Remove the NVIDIA PCI device before the latch opens.
#
# Default off (gpu.remove_on_detach=0): the SB2's GTX 1050 detaches fine
# without this thanks to the surface hw quirk; the GPU driver simply stays
# bound to a device that has left the bus and resumes when the clip is put
# back. Setting gpu.remove_on_detach=1 removes the device first so the
# driver fully releases it, at the cost of a minute of re-init on re-attach.
. "$(dirname "$(readlink -f "$0")")/../lib.sh"

[ "$(sh_cfg gpu.remove_on_detach 0)" = "1" ] || exit 0

SLOT="$(sh_cfg gpu.slot 0000:01:00.0)"
case "$SLOT" in *[!0-9a-fA-F:_.-]*|"") log_ev "bad gpu.slot '$SLOT'"; exit 0 ;; esac

if [ -e "/sys/bus/pci/devices/$SLOT/remove" ]; then
  if echo 1 > "/sys/bus/pci/devices/$SLOT/remove" 2>/dev/null; then
    log_ev "removed $SLOT (GPU) before detach"
  else
    log_ev "failed to remove $SLOT"
  fi
fi
exit 0