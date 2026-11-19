#!/bin/sh

if [ "$(id -un 2>/dev/null || true)" = "@USER_NAME@" ]; then
  # shellcheck disable=SC1091
  [ -f "@PROFILE_DIR@/etc/profile.d/nix.sh" ] && . "@PROFILE_DIR@/etc/profile.d/nix.sh"
  # shellcheck disable=SC1091
  [ -f "@PROFILE_DIR@/etc/profile.d/hm-session-vars.sh" ] && . "@PROFILE_DIR@/etc/profile.d/hm-session-vars.sh"
  export PATH="@PROFILE_DIR@/bin:$PATH"
fi
