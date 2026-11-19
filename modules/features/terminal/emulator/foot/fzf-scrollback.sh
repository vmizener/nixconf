#!/usr/bin/env bash
set -euo pipefail

foot_bin="@FOOT_BIN@"

f="$(mktemp)"
trap 'rm -f "$f"' EXIT

cat >"$f"

# shellcheck disable=SC2016
"$foot_bin" sh -c 'fzf --no-sort --no-mouse -i --tac < "$1"' sh "$f"
