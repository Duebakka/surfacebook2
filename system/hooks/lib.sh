# Shared helpers for Surface Book 2 hook scripts.
# Source me from hooks/*.d/*.sh, never execute directly.

SB_CONF="/etc/surfacebook/tablet.conf"
SB_HOOKS="$(cd "$(dirname "$(readlink -f "$0")")" >/dev/null 2>&1 && pwd)"
SB_LOG="/var/log/surfacebook-hooks.log"

log_ev() {
  printf '[%s] %s\n' "$(date +%F_%T)" "$*" >> "$SB_LOG"
}

# sh_cfg KEY [default] - read KEY=VALUE from $SB_CONF (quotes stripped).
sh_cfg() {
  local key="$1" def="${2:-}" val=""
  if [[ -f $SB_CONF ]]; then
    val="$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$SB_CONF" | tail -n 1)"
  fi
  val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
  echo "${val:-$def}"
}

# Direct-input (touchscreen / digitizer) sysfs paths.
touch_devices() {
  local p v
  for p in /sys/class/input/input*; do
    [[ -e $p/properties ]] || continue
    v="$(< "$p/properties")"
    v=$(( v & 2 )) || continue
    [[ $v -gt 0 ]] && echo "$p"
  done
  return 0
}