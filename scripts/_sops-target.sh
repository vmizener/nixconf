#!/bin/sh
# Target helper for scripts/sops.py.
# Runs locally or streamed over `ssh <target> sh -s -- <subcommand> [args...]`.
set -eu

unset -v shellHook || true
export PATH="$PATH:/run/current-system/sw/bin:$HOME/.nix-profile/bin"

PROBE_MARKER="---SOPS-PROBE---"
SSH_HOST_PUB_PATH="/etc/ssh/ssh_host_ed25519_key.pub"
KEYS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/keys.txt"

cmd="${1:-}"
case "$cmd" in
probe)
  include_user_key="${2:-1}"
  user="${USER:-${LOGNAME:-$(id -un)}}"
  host="$(uname -n | cut -d. -f1)"

  printf '%s\n' "$PROBE_MARKER"
  printf 'USER=%s\n' "$user"
  printf 'HOST=%s\n' "$host"
  printf 'KEYS_FILE=%s\n' "$KEYS_FILE"

  if [ -f "$KEYS_FILE" ]; then
    printf 'HAS_USER_KEY=1\n'
    if [ "$include_user_key" = "1" ]; then
      if command -v age-keygen >/dev/null 2>&1; then
        printf 'USER_PUB=%s\n' "$(age-keygen -y "$KEYS_FILE")"
      elif command -v nix-shell >/dev/null 2>&1; then
        # shellcheck disable=SC2016
        printf 'USER_PUB=%s\n' "$(KEYS_FILE="$KEYS_FILE" nix-shell -p age --run 'age-keygen -y "$KEYS_FILE"')"
      fi
    fi
  else
    printf 'HAS_USER_KEY=0\n'
  fi

  if [ -f "$SSH_HOST_PUB_PATH" ]; then
    printf 'HOST_SSH_PUB=%s\n' "$(cat "$SSH_HOST_PUB_PATH")"
  fi
  ;;

create-key)
  umask 077
  mkdir -p "$(dirname "$KEYS_FILE")"

  printf '%s\n' "$PROBE_MARKER"
  if command -v age-keygen >/dev/null 2>&1; then
    [ -f "$KEYS_FILE" ] || age-keygen -o "$KEYS_FILE" >/dev/null 2>&1
    printf 'USER_PUB=%s\n' "$(age-keygen -y "$KEYS_FILE")"
  elif command -v nix-shell >/dev/null 2>&1; then
    # shellcheck disable=SC2016
    pub="$(KEYS_FILE="$KEYS_FILE" nix-shell -p age --run '[ -f "$KEYS_FILE" ] || age-keygen -o "$KEYS_FILE" >/dev/null 2>&1; age-keygen -y "$KEYS_FILE"')"
    printf 'USER_PUB=%s\n' "$pub"
  else
    printf 'NEEDS_LOCAL_KEYGEN=1\n'
  fi
  ;;

read-key)
  cat "$KEYS_FILE"
  ;;

write-key)
  umask 077
  mkdir -p "$(dirname "$KEYS_FILE")"
  if [ ! -f "$KEYS_FILE" ]; then
    cat >"$KEYS_FILE"
  fi
  ;;

*)
  printf 'Usage: %s {probe [0|1]|create-key|read-key|write-key}\n' "$0" >&2
  exit 2
  ;;
esac
