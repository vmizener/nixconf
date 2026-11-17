#!/usr/bin/env bash
set -euo pipefail

secret_file="@COOKIE_SECRET_PATH@"
openssl_bin="@OPENSSL_BIN@"

if [[ ! -f $secret_file ]] || [[ $(wc -c <"$secret_file") -ne 32 ]]; then
  umask 0077
  tmp_file="${secret_file}.tmp"
  "$openssl_bin" rand -hex 16 | tr -d '\n' >"$tmp_file"
  mv "$tmp_file" "$secret_file"
fi
