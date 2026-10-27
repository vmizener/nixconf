#!/usr/bin/env bash
set -euo pipefail

# Prevent inherited devShell shellHook (e.g. pre-commit) from running in nix-shell
unset shellHook

function sops() {
  nix-shell -p sops --run "sops ${*@Q}"
}

for file in secrets/*.yaml; do
  sops updatekeys -y "$file"
done
echo "Done"
