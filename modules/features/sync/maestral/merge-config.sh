#!/usr/bin/env bash
set -euo pipefail

config_path="@CONFIG_PATH@"
rendered_config="@RENDERED_CONFIG@"
extra_config_file="@EXTRA_CONFIG_FILE@"
crudini_bin="@CRUDINI_BIN@"

mkdir -p "$(dirname "$config_path")"
if [[ -f $config_path && ! -L $config_path ]]; then
  chmod 0600 "$config_path"
  # Use crudini to merge ini files
  "$crudini_bin" --merge "$config_path" <"$rendered_config"
else
  rm -f "$config_path"
  install -m 0600 "$rendered_config" "$config_path"
fi

if [[ -n $extra_config_file ]]; then
  "$crudini_bin" --merge "$config_path" <"$extra_config_file"
fi
