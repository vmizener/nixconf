# Builds a NoCloud (`cidata`) cloud-init seed ISO for standalone Home-Manager VMs.
{
  autologin,
  fallbackProfileFile,
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

  setupGuestScript = pkgs.replaceVars ./scripts/setup-guest.sh {
    AUTOLOGIN =
      if autologin
      then "1"
      else "0";
    SERIAL_TTY = serialTty;
  };

  writeFilesSpec =
    [
      {
        path = "/etc/sysctl.d/99-hm-vm-userns.conf";
        source = ./units/99-hm-vm-userns.conf;
      }
      {
        path = "/etc/systemd/system/hm-vm-activate.service";
        source = pkgs.replaceVars ./units/hm-vm-activate.service {
          SERIAL_GETTY_UNIT = "serial-getty@${serialTty}.service";
        };
      }
      {
        path = "/usr/local/share/hm-vm/dbus.socket";
        source = ./units/dbus.socket;
      }
      {
        path = "/usr/local/share/hm-vm/dbus.service";
        source = ./units/dbus.service;
      }
      {
        path = "/usr/local/libexec/hm-vm-setup.sh";
        source = setupGuestScript;
        permissions = "0755";
      }
    ]
    ++ lib.optional (fallbackProfileFile != null) {
      path = "/etc/profile.d/hm-vm.sh";
      source = fallbackProfileFile;
    }
    ++ lib.optionals autologin [
      {
        path = "/etc/systemd/system/getty@tty1.service.d/autologin.conf";
        source = pkgs.replaceVars ./units/tty1-autologin.conf {
          USER_NAME = username;
        };
      }
      {
        path = "/etc/systemd/system/serial-getty@${serialTty}.service.d/autologin.conf";
        source = pkgs.replaceVars ./units/serial-autologin.conf {
          USER_NAME = username;
        };
      }
    ];

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
    runcmd = [
      ["/usr/local/libexec/hm-vm-setup.sh"]
    ];
  };

  metaDataFile = pkgs.writeText "hm-vm-meta-data-${hostName}.json" (
    builtins.toJSON {
      instance-id = "hm-vm-${hostName}";
      local-hostname = hostName;
    }
    + "\n"
  );

  cloudConfigFile = pkgs.writeText "hm-vm-cloud-config-${hostName}.json" (
    builtins.toJSON cloudConfig
  );

  jqRawArgs =
    writeFilesSpec
    |> lib.imap0 (i: f: "--rawfile c${toString i} ${lib.escapeShellArg "${f.source}"}")
    |> lib.concatStringsSep " ";

  jqWriteFilesExpr =
    writeFilesSpec
    |> lib.imap0 (
      i: f:
        "{ path: ${builtins.toJSON f.path}, content: \$c${toString i}"
        + lib.optionalString ((f.permissions or null) != null) ", permissions: ${builtins.toJSON f.permissions}"
        + " }"
    )
    |> lib.concatStringsSep ", ";
in
  pkgs.runCommand "hm-vm-seed-${hostName}.iso" {
    nativeBuildInputs = [
      pkgs.cdrtools
      pkgs.jq
      pkgs.shellcheck
    ];
  } (
    ''
      shellcheck -s bash "${setupGuestScript}"
    ''
    + lib.optionalString (fallbackProfileFile != null) ''
      shellcheck -s sh "${fallbackProfileFile}"
    ''
    + ''
      mkdir -p seed
      cp "${metaDataFile}" seed/meta-data
      {
        printf '#cloud-config\n'
        jq ${jqRawArgs} '.write_files = [${jqWriteFilesExpr}]' "${cloudConfigFile}"
      } > seed/user-data
      mkisofs -quiet -output "$out" -volid cidata -joliet -rock seed/user-data seed/meta-data
    ''
  )
