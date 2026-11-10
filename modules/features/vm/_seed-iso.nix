# Builds a NoCloud (`cidata`) cloud-init seed ISO for standalone Home-Manager VMs.
{
  autologin,
  fallbackProfileScript,
  hostName,
  lib,
  pkgs,
  system,
  username,
}: let
  serialTty =
    if system == "aarch64-linux"
    then "ttyAMA0"
    else "ttyS0";

  hmActivateUnit = ''
    [Unit]
    Description=Activate Standalone Home-Manager Generation
    After=local-fs.target cloud-init-local.service cloud-init-network.service cloud-init.service
    Before=systemd-user-sessions.service getty@tty1.service serial-getty@${serialTty}.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStartPre=/bin/mkdir -p /mnt/hm-vm
    ExecStartPre=/bin/sh -c 'mountpoint -q /mnt/hm-vm || mount -t 9p -o trans=virtio,version=9p2000.L,ro hm-vm /mnt/hm-vm'
    ExecStart=/mnt/hm-vm/activate-guest.sh

    [Install]
    WantedBy=multi-user.target
  '';

  userDbusSocket = ''
    [Unit]
    Description=D-Bus User Message Bus Socket

    [Socket]
    ListenStream=%t/bus
    ExecStartPost=-/usr/bin/systemctl --user set-environment DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus

    [Install]
    WantedBy=sockets.target
  '';

  userDbusService = ''
    [Unit]
    Description=D-Bus User Message Bus
    Requires=dbus.socket

    [Service]
    Type=notify
    ExecStart=/usr/bin/dbus-daemon --session --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
    ExecReload=/usr/bin/dbus-send --print-reply --session --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
    OOMScoreAdjust=-900
  '';

  tty1AutologinDropin = ''
    [Service]
    ExecStart=
    ExecStart=-/sbin/agetty --autologin ${username} --noclear %I $TERM
  '';

  serialAutologinDropin = ''
    [Service]
    ExecStart=
    ExecStart=-/sbin/agetty --autologin ${username} --keep-baud 115200,57600,38400,9600 - $TERM
  '';

  earlySetupScript =
    ''
      set -eu
      if [ -f /var/lib/hm-vm-early-setup-done ]; then
        exit 0
      fi

      mkdir -p /etc/sysctl.d /etc/systemd/system
      printf '%s\n' 'kernel.apparmor_restrict_unprivileged_userns = 0' > /etc/sysctl.d/99-hm-vm-userns.conf
      sysctl --system >/dev/null 2>&1 || true

      if [ ! -e /usr/lib/systemd/user/dbus.socket ] && [ -x /usr/bin/dbus-daemon ]; then
        mkdir -p /etc/systemd/user/sockets.target.wants
        printf '%s' ${lib.escapeShellArg userDbusSocket} > /etc/systemd/user/dbus.socket
        printf '%s' ${lib.escapeShellArg userDbusService} > /etc/systemd/user/dbus.service
        ln -sfn /etc/systemd/user/dbus.socket /etc/systemd/user/sockets.target.wants/dbus.socket
      fi

      printf '%s' ${lib.escapeShellArg hmActivateUnit} > /etc/systemd/system/hm-vm-activate.service
    ''
    + lib.optionalString (fallbackProfileScript != "") ''
      mkdir -p /etc/profile.d
      printf '%s' ${lib.escapeShellArg fallbackProfileScript} > /etc/profile.d/hm-vm.sh
    ''
    + lib.optionalString autologin ''
      mkdir -p /etc/systemd/system/getty@tty1.service.d /etc/systemd/system/serial-getty@${serialTty}.service.d
      printf '%s' ${lib.escapeShellArg tty1AutologinDropin} > /etc/systemd/system/getty@tty1.service.d/autologin.conf
      printf '%s' ${lib.escapeShellArg serialAutologinDropin} > /etc/systemd/system/serial-getty@${serialTty}.service.d/autologin.conf
    ''
    + ''
      systemctl daemon-reload
      systemctl enable hm-vm-activate.service
      systemctl --no-block start hm-vm-activate.service
      touch /var/lib/hm-vm-early-setup-done
    '';

  cloudConfig = {
    hostname = hostName;
    manage_etc_hosts = true;
    users = [
      {
        name = username;
        gecos = username;
        lock_passwd = false;
        plain_text_passwd = "vm";
        sudo = "ALL=(ALL) NOPASSWD:ALL";
        groups = ["adm" "audio" "cdrom" "dialout" "dip" "floppy" "input" "netdev" "plugdev" "render" "sudo" "video"];
        shell = "/bin/bash";
      }
    ];
    bootcmd = [
      ["sh" "-c" earlySetupScript]
    ];
  };

  metaData = builtins.toJSON {
    instance-id = "hm-vm-${hostName}";
    local-hostname = hostName;
  };
  userData = "#cloud-config\n" + builtins.toJSON cloudConfig + "\n";
in
  pkgs.runCommand "hm-vm-seed-${hostName}.iso" {
    nativeBuildInputs = [pkgs.cdrtools];
  } ''
    mkdir -p seed
    printf '%s\n' ${lib.escapeShellArg metaData} > seed/meta-data
    printf '%s' ${lib.escapeShellArg userData} > seed/user-data
    mkisofs -quiet -output "$out" -volid cidata -joliet -rock seed/user-data seed/meta-data
  ''
