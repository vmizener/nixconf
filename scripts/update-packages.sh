#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe # Needed so `readarray` works inside pipelines

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Assumes updatable packages have names with prefix "pkg:"
nix eval --json ".#packages.$(nix config show system)" \
  --apply 'builtins.mapAttrs (_: p: p.passthru.nixUpdateArgs or [])' |
  jq -c 'to_entries[] | select(.key | startswith("pkg:"))' |
  readarray -t entries

status=0
for entry in "${entries[@]}"; do
  pkg="$(jq -r '.key' <<<"${entry}")"
  readarray -t extra_args < <(jq -r '.value[]' <<<"${entry}")

  echo "Updating ${pkg}..."
  nix run github:Mic92/nix-update -- -F "${extra_args[@]}" "${pkg}" || status=1
done

exit "${status}"
