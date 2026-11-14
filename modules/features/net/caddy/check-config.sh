#!/usr/bin/env bash
set -euo pipefail

caddy_bin="@CADDY_BIN@"
config_file="@CONFIG_FILE@"
log_dir="@LOG_DIR@"
mode="@MODE@"
out_path="$1"

export XDG_DATA_HOME="$TMPDIR/data"
export XDG_CONFIG_HOME="$TMPDIR/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$TMPDIR/log"

sed "s|${log_dir}|${TMPDIR}/log|g" "$config_file" >"$TMPDIR/Caddyfile"

if [[ $mode == "adapt" ]]; then
  "$caddy_bin" adapt --adapter caddyfile --config "$TMPDIR/Caddyfile" >/dev/null
else
  "$caddy_bin" validate --adapter caddyfile --config "$TMPDIR/Caddyfile"
fi

touch "$out_path"
