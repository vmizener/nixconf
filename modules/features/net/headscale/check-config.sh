#!/usr/bin/env bash
set -euo pipefail

headscale_bin="@HEADSCALE_BIN@"
config_file="@CONFIG_FILE@"
oidc_secret_path="@OIDC_SECRET_PATH@"
out_path="$1"

mkdir -p "$TMPDIR/state" "$TMPDIR/run"
printf '%s' 'dummy-oidc-secret' >"$TMPDIR/oidc_secret"

sed_args=(
  -e "s|/var/lib/headscale|${TMPDIR}/state|g"
  -e "s|/run/headscale|${TMPDIR}/run|g"
)
if [[ -n $oidc_secret_path ]]; then
  sed_args+=(-e "s|${oidc_secret_path}|${TMPDIR}/oidc_secret|g")
fi

sed "${sed_args[@]}" "$config_file" >"$TMPDIR/headscale.yaml"
"$headscale_bin" configtest --config "$TMPDIR/headscale.yaml"
touch "$out_path"
