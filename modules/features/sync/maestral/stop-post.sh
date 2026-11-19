#!/usr/bin/env bash
set -euo pipefail

notify_send_bin="@NOTIFY_SEND_BIN@"

if [[ ${SERVICE_RESULT:-} != "success" ]]; then
  "$notify_send_bin" 'Maestral daemon failed'
fi
