#!/usr/bin/env bash
set -euo pipefail

function sops() {
  nix-shell -p sops --run "sops ${*@Q}"
}

for file in secrets/*.yaml; do
    sops updatekeys -y "$file"
done
echo "Done"
