#!/usr/bin/env bash
set -euo pipefail

mode="@MODE@"
host_name="@HOST_NAME@"
storage_dir="@STORAGE_DIR@"
graphics="@GRAPHICS@"
gl="@GL@"
nixgl_bin="@NIXGL_BIN@"
nixos_vm_bin="@NIXOS_VM_BIN@"
qemu_bin="@QEMU_BIN@"
qemu_img_bin="@QEMU_IMG_BIN@"
base_image="@BASE_IMAGE@"
disk_size="@DISK_SIZE@"
qemu_args_file="@QEMU_ARGS_FILE@"
display_args_file="@DISPLAY_ARGS_FILE@"

mkdir -p "$storage_dir"
export NIX_DISK_IMAGE="${NIX_DISK_IMAGE:-$storage_dir/$host_name.qcow2}"

if [[ $mode == "hm" && ! -f $NIX_DISK_IMAGE ]]; then
  echo "Creating VM disk overlay at $NIX_DISK_IMAGE (backed by $base_image)..."
  "$qemu_img_bin" create \
    -f qcow2 \
    -F qcow2 \
    -b "$base_image" \
    "$NIX_DISK_IMAGE" \
    "$disk_size" >/dev/null
fi

kvm_args=()
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  kvm_args=(-enable-kvm -cpu host)
else
  echo "warning: /dev/kvm is not accessible; QEMU will fall back to slow TCG emulation" >&2
  kvm_args=(-cpu max)
fi

headless_override=0
for arg in "$@"; do
  if [[ $arg == "-nographic" ]]; then
    headless_override=1
    break
  fi
done

wrapper=()
if [[ $headless_override -eq 0 && $graphics == "1" ]]; then
  if [[ $gl == "1" ]]; then
    has_host_gpu=0
    for node in /dev/dri/renderD*; do
      if [[ -r $node && -w $node ]]; then
        has_host_gpu=1
        break
      fi
    done

    if [[ $has_host_gpu -eq 0 ]]; then
      export LIBGL_ALWAYS_SOFTWARE=1
      export LP_NUM_THREADS="${LP_NUM_THREADS:-4}"
    fi

    if [[ ! -d /run/opengl-driver ]]; then
      if command -v nixGL >/dev/null 2>&1; then
        wrapper=(nixGL)
      elif [[ -n $nixgl_bin ]]; then
        wrapper=("$nixgl_bin")
      fi
    fi
  else
    export SDL_RENDER_DRIVER="${SDL_RENDER_DRIVER:-software}"
  fi
fi

if [[ $mode == "nixos" ]]; then
  exec "${wrapper[@]}" "$nixos_vm_bin" "$@"
fi

readarray -t static_args <"$qemu_args_file"
display_args=()
if [[ $graphics == "1" ]]; then
  if [[ $headless_override -eq 0 ]]; then
    readarray -t display_args <"$display_args_file"
  fi
else
  display_args=(-nographic)
fi

exec "${wrapper[@]}" "$qemu_bin" \
  "${kvm_args[@]}" \
  -name "$host_name" \
  -drive "file=$NIX_DISK_IMAGE,format=qcow2,if=virtio,cache=writeback,discard=unmap" \
  "${static_args[@]}" \
  "${display_args[@]}" \
  "$@"
