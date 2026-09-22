#!/usr/bin/env sh
# Preserve the stock surface-dtx detach.sh behavior (unmount USB disks,
# signal commence) that ships with surface-dtx-daemon.
set -u

DIST="/etc/surface-dtx/detach.sh.dist"
if [ -x "$DIST" ]; then
  "$DIST"
fi
exit 0