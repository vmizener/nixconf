#!/usr/bin/env bash
set -euo pipefail

awww_bin="@AWWW_BIN@"
flags="@FLAGS@"
img="@IMG@"

read -r -a flag_args <<<"$flags"

for _ in {1..40}; do
  if "$awww_bin" img "${flag_args[@]}" "$img"; then
    exit 0
  fi
  sleep 0.25
done

echo "awww-daemon did not become ready" >&2
exit 1
