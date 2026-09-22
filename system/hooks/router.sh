#!/usr/bin/env bash
# router.sh - dispatch surface-dtx handler events to the hook chains.
#
# The dtx daemon runs this as the [handler.*] executable for the detach,
# detach_abort, and attach events:
#
#   /etc/surface-dtx/{detach,detach_abort,attach}.sh  ->  router.sh <event>
#
# Hooks live in detach.d/ and attach.d/. detach runs detach.d/* then signals
# the daemon to proceed (EXIT_DETACH_COMMENCE); detach_abort and attach run
# their chains and exit 0. A hook that exits 91 vetoes the detach (the
# surfacebook config fenceposts an explicit "abort" hook for that).
set -euo pipefail

EVENT="${1:?usage: router.sh <detach|detach_abort|attach>}"
ROUTER_DIR="$(cd "$(dirname "$(readlink -f "$0")")" >/dev/null 2>&1 && pwd)"

case "$EVENT" in
  detach|detach_abort|attach) ;;
  *) echo "router.sh: unknown event '$EVENT'" >&2; exit 1 ;;
esac

LOG="${SB_LOG:-/var/log/surfacebook-hooks.log}"
log() { printf '[%s] %s\n' "$(date +%F_%T)" "$*" >> "$LOG"; }

export SB_EVENT="$EVENT"

for script in "$ROUTER_DIR/$EVENT.d/"*.sh; do
  [[ -e $script ]] || continue
  log ">> $EVENT: running $(basename "$script")"
  "$script" >> "$LOG" 2>&1 || {
    rc=$?
    log "!! $EVENT: $(basename "$script") failed ($rc)"
    if [[ $rc -eq 91 && $EVENT == detach ]]; then
      log "!! detach vetoed by $(basename "$script")"
      exit 91
    fi
  }
done

# detach: tell the daemon to proceed (net effect of the stock script).
[[ $EVENT == detach ]] && exit "${EXIT_DETACH_COMMENCE:-0}"
exit 0