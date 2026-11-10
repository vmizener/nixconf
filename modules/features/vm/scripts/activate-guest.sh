#!/usr/bin/env bash
set -euo pipefail

use_user_chroot="@USE_USER_CHROOT@"
user_name="@USER_NAME@"
home_dir="@HOME_DIR@"
nix_dir="@NIX_DIR@"
chroot_bin_store_rel="@CHROOT_BIN_STORE_REL@"
nix_bin_dir="@NIX_BIN_DIR@"
activation_pkg="@ACTIVATION_PKG@"
flake_src="@FLAKE_SRC@"
desired_shell="@DESIRED_SHELL@"
guest_packages="@GUEST_PACKAGES@"

if [[ -n $guest_packages && ! -f /var/lib/hm-vm-guest-pkgs-installed ]]; then
  if command -v apt-get >/dev/null 2>&1; then
    read -r -a pkg_list <<<"$guest_packages"
    if DEBIAN_FRONTEND=noninteractive apt-get update \
      -o Acquire::Retries=1 \
      -o Acquire::Languages=none \
      -o Acquire::http::Timeout=5 &&
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkg_list[@]}"; then
      touch /var/lib/hm-vm-guest-pkgs-installed
    else
      echo "warning: guest package install failed; continuing" >&2
    fi
  fi
fi

user_group="$(id -gn "$user_name")"
user_uid="$(id -u "$user_name")"

if [[ $use_user_chroot == "1" ]]; then
  mkdir -p /mnt/host-nix-store \
    "$nix_dir/root-nix/.rw-store/upper" \
    "$nix_dir/root-nix/.rw-store/work" \
    "$nix_dir/root-nix/store" \
    "$nix_dir/root-nix/var" \
    "$home_dir"

  chown -R "$user_name:$user_group" "$nix_dir"

  if ! mountpoint -q /mnt/host-nix-store; then
    mount -t 9p -o trans=virtio,version=9p2000.L,ro,msize=104857600 host-nix-store /mnt/host-nix-store
  fi
  if ! mountpoint -q "$nix_dir/root-nix/store"; then
    mount -t overlay overlay \
      -o "lowerdir=/mnt/host-nix-store,upperdir=$nix_dir/root-nix/.rw-store/upper,workdir=$nix_dir/root-nix/.rw-store/work" \
      "$nix_dir/root-nix/store"
  fi

  cp -f "/mnt/host-nix-store/$chroot_bin_store_rel" "$nix_dir/nix-user-chroot"
  chmod 0755 "$nix_dir/nix-user-chroot"
  chown "$user_name:$user_group" "$nix_dir/nix-user-chroot"

  # shellcheck disable=SC2016
  runuser -u "$user_name" -- env HOME="$home_dir" USER="$user_name" \
    "$nix_dir/nix-user-chroot" "$nix_dir/root-nix" /bin/sh -c \
    '"$1/nix-store" --load-db </mnt/hm-vm/registration && "$2/activate"' \
    _ "$nix_bin_dir" "$activation_pkg"
  exit 0
fi

mkdir -p /nix/.ro-store /nix/.rw-store/upper /nix/.rw-store/work /nix/store /nix/var
chown "$user_name:$user_group" /nix/.rw-store/upper

if ! mountpoint -q /nix/.ro-store; then
  mount -t 9p -o trans=virtio,version=9p2000.L,ro,msize=104857600 host-nix-store /nix/.ro-store
fi
if ! mountpoint -q /nix/store; then
  mount -t overlay overlay \
    -o lowerdir=/nix/.ro-store,upperdir=/nix/.rw-store/upper,workdir=/nix/.rw-store/work \
    /nix/store
fi

mkdir -p \
  "/nix/var/nix/profiles/per-user/$user_name" \
  "/nix/var/nix/gcroots/per-user/$user_name" \
  "$home_dir/.local/state/nix/profiles" \
  "$home_dir/.local/state/home-manager/gcroots" \
  "$home_dir/.config"

chown -R "$user_name:$user_group" \
  /nix/var \
  "$home_dir/.local" \
  "$home_dir/.config"

runuser -u "$user_name" -- "$nix_bin_dir/nix-store" --load-db </mnt/hm-vm/registration

if [[ ! -e "$home_dir/.config/home-manager" || -L "$home_dir/.config/home-manager" ]]; then
  ln -sfn "$flake_src" "$home_dir/.config/home-manager"
  chown -h "$user_name:$user_group" "$home_dir/.config/home-manager"
fi

env_args=(
  "HOME=$home_dir"
  "USER=$user_name"
  "LOGNAME=$user_name"
  "PATH=$nix_bin_dir:/usr/local/bin:/usr/bin:/bin"
)
if [[ -d "/run/user/$user_uid" ]]; then
  env_args+=("XDG_RUNTIME_DIR=/run/user/$user_uid")
fi

runuser -u "$user_name" -- env "${env_args[@]}" "$activation_pkg/activate"

if [[ -n $desired_shell && -x $desired_shell ]]; then
  if ! grep -qxF "$desired_shell" /etc/shells; then
    echo "$desired_shell" >>/etc/shells
  fi
  usermod -s "$desired_shell" "$user_name"
fi
