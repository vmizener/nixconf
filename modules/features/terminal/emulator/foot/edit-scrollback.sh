#!/usr/bin/env bash
set -euo pipefail

foot_bin="@FOOT_BIN@"
editor_cmd_file="@EDITOR_CMD_FILE@"
readarray -t editor_cmd <"$editor_cmd_file"

f="$(mktemp)"
trap 'rm -f "$f"' EXIT

cat >"$f"

case "${editor_cmd[0]##*/}" in
nvim | vim)
  "$foot_bin" "${editor_cmd[@]}" -u NONE "$f" \
    -c 'set nonumber nolist showtabline=0 foldcolumn=0 virtualedit=block' \
    -c 'autocmd VimEnter * normal G' \
    -c 'map q :qa!<CR>' \
    -c 'map i <NOP>' \
    -c 'map I <NOP>' \
    -c 'map a <NOP>' \
    -c 'map A <NOP>' \
    -c 'set clipboard+=unnamedplus'
  ;;
*)
  "$foot_bin" "${editor_cmd[@]}" "$f"
  ;;
esac
