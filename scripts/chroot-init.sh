#!/usr/bin/env bash
#
# Bootstraps or migrates a rootless nix-user-chroot + Home-Manager environment
# on read-only or non-NixOS hosts.
#
# Inspired by and compatible with: https://github.com/quag/user-nix-steam-deck
set -euo pipefail

# Pinned bootstrap artifact versions and SHA-256 checksums
CHROOT_VERSION="1.2.2"
NIX_INSTALL_VERSION="2.34.8"
NIX_INSTALL_URL="https://releases.nixos.org/nix/nix-${NIX_INSTALL_VERSION}/install"
NIX_INSTALL_SHA256="96c10e102c88809dd9ec0bee89200c4a51eae4c9f6d8698c26b16788d131e078"

oops() {
  echo "$0:" "$@" >&2
  exit 1
}

fetch_verified() {
  local url="$1"
  local expected_sha256="$2"
  local dest="$3"
  local mode="${4:-}"
  local tmp="${dest}.tmp.$$"
  local actual_sha256

  if command -v wget >/dev/null 2>&1; then
    wget -O "${tmp}" "${url}" || {
      rm -f "${tmp}"
      oops "Failed to download ${url}"
    }
  elif command -v curl >/dev/null 2>&1; then
    curl --fail -L -o "${tmp}" "${url}" || {
      rm -f "${tmp}"
      oops "Failed to download ${url}"
    }
  else
    oops "Neither wget nor curl is installed; cannot download ${url}"
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    actual_sha256="$(sha256sum <"${tmp}")" || {
      rm -f "${tmp}"
      oops "Failed to compute SHA-256 checksum for ${url}"
    }
  elif command -v shasum >/dev/null 2>&1; then
    actual_sha256="$(shasum -a 256 <"${tmp}")" || {
      rm -f "${tmp}"
      oops "Failed to compute SHA-256 checksum for ${url}"
    }
  elif command -v openssl >/dev/null 2>&1; then
    actual_sha256="$(openssl dgst -r -sha256 <"${tmp}")" || {
      rm -f "${tmp}"
      oops "Failed to compute SHA-256 checksum for ${url}"
    }
  else
    rm -f "${tmp}"
    oops "Cannot verify SHA-256 checksum for ${url} (need sha256sum, shasum, or openssl)"
  fi

  actual_sha256="${actual_sha256%% *}"
  if [ "${actual_sha256,,}" != "${expected_sha256,,}" ]; then
    rm -f "${tmp}"
    oops "SHA-256 mismatch for ${url}: expected ${expected_sha256}, got ${actual_sha256}"
  fi

  if [ -n "${mode}" ]; then
    chmod "${mode}" "${tmp}"
  fi
  mv -f "${tmp}" "${dest}"
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
  CHROOT_BIN_SHA256="e11aff604bb8d3ffd1d9c0c68cd636816d7eb8da540de18ee3a41ccad7ac0972"
  ;;
aarch64 | arm64)
  CHROOT_BIN_TARGET="aarch64-unknown-linux-musl"
  CHROOT_BIN_SHA256="7702c17c58544d4df4539b9948c03e2851f644d548c0ab6d66e0fd93d949d113"
  ;;
armv7l)
  CHROOT_BIN_TARGET="armv7-unknown-linux-musleabihf"
  CHROOT_BIN_SHA256="60645e640c57af89b6958a980352ab63f53d2955bf1ffb82e574ecae7cae057c"
  ;;
i686)
  CHROOT_BIN_TARGET="i686-unknown-linux-musl"
  CHROOT_BIN_SHA256="570b70c85db9633c6eb5a9351582810767c197472c1052109906ca719c9b888b"
  ;;
*)
  oops "Unsupported architecture: ${ARCH}"
  ;;
esac

# Detect whether we are already inside nix-user-chroot or on the host OS
if [[ ${HOME} == */nix/home ]]; then
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
    echo "Downloading nix-user-chroot ${CHROOT_VERSION} (${CHROOT_BIN_TARGET})..."
    fetch_verified \
      "https://github.com/nix-community/nix-user-chroot/releases/download/${CHROOT_VERSION}/nix-user-chroot-bin-${CHROOT_VERSION}-${CHROOT_BIN_TARGET}" \
      "${CHROOT_BIN_SHA256}" \
      "${N}/nix-user-chroot" \
      "u+x"
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
ACTIVATE_SCRIPT=$(
  cat <<EOF
set -euo pipefail
$(declare -f oops fetch_verified)

# Prevent non-sandboxed Nix builds from creating /homeless-shelter in the chroot rootfs
rm -rf /homeless-shelter 2>/dev/null || true
mount -o remount,bind,ro / 2>/dev/null || true

if [ -f "\$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "\$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

NIX_FLAGS=(--extra-experimental-features "nix-command flakes pipe-operators")

# Install or upgrade Nix if missing or too old to support readFileType / pipe-operators
if ! command -v nix >/dev/null 2>&1 || ! nix "\${NIX_FLAGS[@]}" eval --expr 'builtins.seq builtins.readFileType (1 |> (x: x))' >/dev/null 2>&1; then
  echo "Installing/updating bootstrap Nix ${NIX_INSTALL_VERSION}..."
  if command -v nix-env >/dev/null 2>&1; then
    nix-env --set-flag priority 10 home-manager-path 2>/dev/null || true
  fi
  fetch_verified "${NIX_INSTALL_URL}" "${NIX_INSTALL_SHA256}" "${N}/nix.install"
  /bin/bash "${N}/nix.install" --no-modify-profile
  rm -f "${N}/nix.install"
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
  bash -c "${ACTIVATE_SCRIPT}" "$0"
else
  HOME="${CHROOT_HOME}" "${N}/nix-user-chroot" "${N}/root-nix" /bin/bash -c "${ACTIVATE_SCRIPT}" "$0"
fi

echo
echo "nix-user-chroot + Home-Manager environment is ready!"
echo "Enter the environment with: ${N}/enter"
