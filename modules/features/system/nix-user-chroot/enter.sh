#!/usr/bin/env bash
set -euo pipefail

home_dir="@HOME_DIR@"
nix_dir="@NIX_DIR@"
default_shell="@DEFAULT_SHELL@"

export HOME="$home_dir"
cd "$HOME" || exit 1
echo "home: $HOME"
if [[ $# -eq 0 ]]; then
  read -r -a shell_args <<<"$default_shell"
  set -- "${shell_args[@]}"
fi

# shellcheck disable=SC2016
exec "$nix_dir/nix-user-chroot" "$nix_dir/root-nix" /bin/sh -c '
  rm -rf /homeless-shelter 2>/dev/null || true
  mount -o remount,bind,ro / 2>/dev/null || true
  exec "$@"
' -- "$@"
