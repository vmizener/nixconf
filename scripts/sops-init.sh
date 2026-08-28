#!/usr/bin/env bash
set -euo pipefail

function age_keygen() {
  nix-shell -p age --run "age-keygen ${*@Q}"
}
function ssh_to_age() {
  nix-shell -p ssh-to-age --run "ssh-to-age ${*@Q}"
}
function sops() {
  nix-shell -p sops --run "sops ${*@Q}"
}
function yq() {
  nix-shell -p yq-go --run "yq ${*@Q}"
}

# Find `.sops.yaml`
SOURCE_DIR="$(dirname "${BASH_SOURCE[0]}")"
SOPS_YAML="${SOPS_YAML:-$SOURCE_DIR/../.sops.yaml}"
if [ ! -f "${SOPS_YAML}" ]; then
  echo "Failed to find .sops.yaml" >&2
  exit 1
fi

USER_NAME="${USER:-$(id -un)}"
HOSTNAME="$(uname -n | cut -d. -f1)"

# Find/generate user keys
SOPS_KEYS="${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/keys.txt"
mkdir -p "$(dirname "${SOPS_KEYS}")"

if [ ! -f "${SOPS_KEYS}" ]; then
  age_keygen -o "${SOPS_KEYS}"
  echo "Created new local user key pair"
else
  echo "Using existing local user key pair"
fi

USER_ANCHOR="${USER_NAME}_${HOSTNAME}"
USER_PUB_KEY="$(age_keygen -y "${SOPS_KEYS}")"

# Collect keys to manage (user key + optional host SSH key)
declare -a ANCHORS=("$USER_ANCHOR")
declare -A PUB_KEYS
PUB_KEYS["$USER_ANCHOR"]="$USER_PUB_KEY"

SSH_HOST_PUB="/etc/ssh/ssh_host_ed25519_key.pub"
if [ -f "${SSH_HOST_PUB}" ]; then
  read -r -p "Found host SSH public key ('${SSH_HOST_PUB}'). Add host key ('host_${HOSTNAME}')? [y/N] " add_host_key
  if [[ "${add_host_key}" =~ ^[yY]([eE][sS])?$ ]]; then
    HOST_ANCHOR="host_${HOSTNAME}"
    HOST_PUB_KEY="$(ssh_to_age -i "${SSH_HOST_PUB}")"
    ANCHORS+=("$HOST_ANCHOR")
    PUB_KEYS["$HOST_ANCHOR"]="$HOST_PUB_KEY"
  fi
fi

# Add keys to sops yaml if missing
for anchor in "${ANCHORS[@]}"; do
  export ANCHOR="$anchor"
  export KEY="${PUB_KEYS[$anchor]}"
  yq -i '
    (
      select(
        [.keys[] | select(anchor == env(ANCHOR))] | length == 0
      ).keys
    ) += [
      env(KEY) | . anchor = env(ANCHOR)
    ]
  ' "${SOPS_YAML}"
done

# Prompt adding keys to secret creation rules
readarray -t CREATION_RULES < <(yq eval '.creation_rules[].path_regex' "${SOPS_YAML}")
for anchor in "${ANCHORS[@]}"; do
  for rule in "${CREATION_RULES[@]}"; do
    [ -z "${rule}" ] && continue
    read -r -p "Add '${anchor}' to creation rule for '${rule}'? [y/N] " response
    if [[ "${response}" =~ ^[yY]([eE][sS])?$ ]]; then
      export PATH_REGEX="${rule}"
      export ANCHOR="${anchor}"
      yq -i '
        (
          .creation_rules[] |
          select(.path_regex == env(PATH_REGEX)) |
          select([.key_groups[].age[] | select(alias == env(ANCHOR))] | length == 0) |
          .key_groups[].age
        ) += [
          "" | . alias = env(ANCHOR)
        ]
      ' "${SOPS_YAML}"
    fi
  done
done
