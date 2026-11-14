#!/usr/bin/env bash
set -euo pipefail

blocky_bin="@BLOCKY_BIN@"
config_file="@CONFIG_FILE@"
out_path="$1"

"$blocky_bin" --config "$config_file" validate
touch "$out_path"
