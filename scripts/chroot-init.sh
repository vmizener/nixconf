#!/usr/bin/env bash
#
# Bootstraps or migrates a rootless nix-user-chroot + Home-Manager environment
# on read-only or non-NixOS hosts.
#
# Inspired by and compatible with: https://github.com/quag/user-nix-steam-deck
set -euo pipefail

oops() {
  echo "$0:" "$@" >&2
  exit 1
}

USER_NAME="${USER:-$(id -un)}"
HOSTNAME="$(uname -n | cut -d. -f1)"
TARGET_CONFIG="${1:-}"
REPO_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"

# Detect architecture for nix-user-chroot static binary
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)
    CHROOT_BIN_TARGET="x86_64-unknown-linux-musl"
    ;;
  aarch64 | arm64)
    CHROOT_BIN_TARGET="aarch64-unknown-linux-musl"
    ;;
  armv7l)
    CHROOT_BIN_TARGET="armv7-unknown-linux-musleabihf"
    ;;
  i686)
    CHROOT_BIN_TARGET="i686-unknown-linux-musl"
    ;;
  *)
    oops "Unsupported architecture: ${ARCH}"
    ;;
esac

# Detect whether we are already inside nix-user-chroot or on the host OS
if [[ "${HOME}" == */nix/home ]]; then
  CHROOT_HOME="${HOME}"
  N="$(dirname "${HOME}")"
  HOST_HOME="/home/${USER_NAME}"
  IN_CHROOT=1
else
  HOST_HOME="${HOME}"
  N="${N:-${HOST_HOME}/nix}"
  CHROOT_HOME="${N}/home"
  IN_CHROOT=0
fi

HM_CONFIG_DIR="${CHROOT_HOME}/.config/home-manager"

echo "Target nix directory: ${N}"
echo "Chroot HOME:          ${CHROOT_HOME}"
echo "Flake repository:     ${REPO_DIR}"

# 1. Ensure nix-user-chroot directory structure and binary exist
if [ ! -d "${N}/root-nix" ] || [ ! -x "${N}/nix-user-chroot" ]; then
  if [ "${IN_CHROOT}" -eq 1 ]; then
    oops "Cannot bootstrap nix-user-chroot from inside chroot when ${N}/nix-user-chroot is missing"
  fi

  mkdir -p "${N}" "${N}/root-nix" "${CHROOT_HOME}"

  if [ ! -x "${N}/nix-user-chroot" ]; then
    echo "Downloading nix-user-chroot (${CHROOT_BIN_TARGET})..."
    wget -O "${N}/nix-user-chroot" \
      "https://github.com/nix-community/nix-user-chroot/releases/download/1.2.2/nix-user-chroot-bin-1.2.2-${CHROOT_BIN_TARGET}" \
      || oops "Failed to download nix-user-chroot"
    chmod u+x "${N}/nix-user-chroot"
  fi
fi

# 2. Point ~/.config/home-manager inside chroot to this repository (overwriting any existing config)
mkdir -p "${CHROOT_HOME}/.config"
if [ "$(realpath -m "${HM_CONFIG_DIR}")" != "$(realpath -m "${REPO_DIR}")" ]; then
  rm -rf "${HM_CONFIG_DIR}"
  echo "Linking ${HM_CONFIG_DIR} -> ${REPO_DIR}..."
  ln -sfn "${REPO_DIR}" "${HM_CONFIG_DIR}"
fi
if [ ! -L "${CHROOT_HOME}/.config/nix/nix.conf" ]; then
  rm -f "${CHROOT_HOME}/.config/nix/nix.conf"
fi
rm -f "${CHROOT_HOME}/home.nix" "${CHROOT_HOME}/README"

# 3. Install/upgrade Nix if needed, then build and activate Home-Manager inside the chroot
ACTIVATE_SCRIPT=$(cat <<EOF
set -euo pipefail

# Prevent non-sandboxed Nix builds from creating /homeless-shelter in the chroot rootfs
rm -rf /homeless-shelter 2>/dev/null || true
mount -o remount,bind,ro / 2>/dev/null || true

if [ -f "\$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "\$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

NIX_FLAGS=(--extra-experimental-features "nix-command flakes pipe-operators")

# Install or upgrade Nix if missing or too old to support readFileType / pipe-operators
if ! command -v nix >/dev/null 2>&1 || ! nix "\${NIX_FLAGS[@]}" eval --expr 'builtins.seq builtins.readFileType (1 |> (x: x))' >/dev/null 2>&1; then
  echo "Installing/updating bootstrap Nix via nixos.org/nix/install..."
  if command -v nix-env >/dev/null 2>&1; then
    nix-env --set-flag priority 10 home-manager-path 2>/dev/null || true
  fi
  wget -O "${N}/nix.install" https://nixos.org/nix/install
  /bin/bash "${N}/nix.install" --no-modify-profile
  . "\$HOME/.nix-profile/etc/profile.d/nix.sh"
  hash -r
fi

# Lower priority of nix-env's nix if present so Home-Manager's nix can take over
if nix-env -q 2>/dev/null | grep -q '^nix-'; then
  nix-env --set-flag priority 10 nix || true
fi

CONFIG_NAME="${TARGET_CONFIG}"
if [ -z "\${CONFIG_NAME}" ]; then
  if nix "\${NIX_FLAGS[@]}" eval "${REPO_DIR}#homeConfigurations.\"${USER_NAME}@${HOSTNAME}\".activationPackage.drvPath" >/dev/null 2>&1; then
    CONFIG_NAME="${USER_NAME}@${HOSTNAME}"
  else
    CONFIG_NAME="${USER_NAME}"
  fi
fi

echo "Building homeConfigurations.\"\${CONFIG_NAME}\"..."
OUT_PATH="\$(nix "\${NIX_FLAGS[@]}" build --no-link --print-out-paths "${REPO_DIR}#homeConfigurations.\"\${CONFIG_NAME}\".activationPackage")"

echo "Activating Home-Manager generation: \${OUT_PATH}"
"\${OUT_PATH}/activate"

if nix-env -q 2>/dev/null | grep -q '^nix-'; then
  echo "Removing bootstrap nix from nix-env..."
  nix-env -e nix
fi
EOF
)

if [ "${IN_CHROOT}" -eq 1 ]; then
  bash -c "${ACTIVATE_SCRIPT}"
else
  HOME="${CHROOT_HOME}" "${N}/nix-user-chroot" "${N}/root-nix" /bin/bash -c "${ACTIVATE_SCRIPT}"
fi

echo
echo "nix-user-chroot + Home-Manager environment is ready!"
echo "Enter the environment with: ${N}/enter"
