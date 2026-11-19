#!/usr/bin/env bash
set -euo pipefail

env_bin="@ENV_BIN@"
ss_bin="@SS_BIN@"
uname_bin="@UNAME_BIN@"

usage() {
  echo "Usage: wp <cmd> [args...]"
}

if (($# == 0)); then
  usage >&2
  exit 2
fi

case "$1" in
-h | --help)
  usage
  exit 0
  ;;
--)
  shift
  if (($# == 0)); then
    usage >&2
    exit 2
  fi
  ;;
esac

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/${UID}}"
if [[ ! -S "${runtime_dir}/wprs-0" ]]; then
  echo "wp: wprsd is not running (${runtime_dir}/wprs-0 not found)" >&2
  exit 1
fi
if [[ -z "$("$ss_bin" -H -x state connected src "${runtime_dir}/wprs.sock" 2>/dev/null)" ]]; then
  host="${HOSTNAME:-$("$uname_bin" -n)}"
  echo "wp: no attached wprs session (run 'wprs ${host} attach' on client)" >&2
  exit 1
fi

wprs_env=(
  WAYLAND_DISPLAY=wprs-0
  DISPLAY=:100
  XDG_SESSION_TYPE=wayland
  SDL_VIDEODRIVER=wayland
  PULSE_SERVER="unix:${runtime_dir}/wprs-pulse"
)

exec "$env_bin" "${wprs_env[@]}" "$@"
