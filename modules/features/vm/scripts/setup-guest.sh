#!/usr/bin/env bash
set -euo pipefail

autologin="@AUTOLOGIN@"
serial_tty="@SERIAL_TTY@"

if [[ -f /var/lib/hm-vm-early-setup-done ]]; then
  exit 0
fi

sysctl --system >/dev/null 2>&1 || true

if [[ ! -e /usr/lib/systemd/user/dbus.socket && -x /usr/bin/dbus-daemon ]]; then
  mkdir -p /etc/systemd/user/sockets.target.wants
  install -Dm0644 /usr/local/share/hm-vm/dbus.socket /etc/systemd/user/dbus.socket
  install -Dm0644 /usr/local/share/hm-vm/dbus.service /etc/systemd/user/dbus.service
  ln -sfn /etc/systemd/user/dbus.socket /etc/systemd/user/sockets.target.wants/dbus.socket
fi

systemctl daemon-reload
systemctl enable --now hm-vm-activate.service

if [[ $autologin == "1" ]]; then
  systemctl try-restart getty@tty1.service "serial-getty@${serial_tty}.service"
fi

touch /var/lib/hm-vm-early-setup-done
