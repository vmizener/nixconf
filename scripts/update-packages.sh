#!/usr/bin/env bash

# Assumes updatable packages have names with prefix "pkg:"
for pkg in $(nix flake show --json 2>/dev/null | jq -r '.packages | [ .[] | keys[] ] | unique | map(select(startswith("pkg:")))[]'); do
  echo "Updating $pkg..."
  nix run github:Mic92/nix-update -- -F "$pkg" || true
done
