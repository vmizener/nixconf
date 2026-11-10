#!/usr/bin/env bash
set -euo pipefail

storage_dir="@STORAGE_DIR@"
host_name="@HOST_NAME@"
disk_image="${NIX_DISK_IMAGE:-$storage_dir/$host_name.qcow2}"

if [[ -f $disk_image ]]; then
  echo "Removing $disk_image"
  rm "$disk_image"
else
  echo "No image found at $disk_image"
fi
