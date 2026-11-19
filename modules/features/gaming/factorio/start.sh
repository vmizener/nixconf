#!/usr/bin/env bash
set -euo pipefail

tr_bin="@TR_BIN@"
start_args_file="@START_ARGS_FILE@"
rcon_bind="@RCON_BIND@"

readarray -t start_args <"$start_args_file"
rcon_pw="$("$tr_bin" -d '\r\n' <"$CREDENTIALS_DIRECTORY/rcon-password")"

exec "${start_args[@]}" \
  "--rcon-bind=$rcon_bind" \
  "--rcon-password=$rcon_pw"
