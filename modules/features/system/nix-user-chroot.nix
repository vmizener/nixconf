/*
  feat/system/nix-user-chroot

Configures a rootless user-space Nix + Home-Manager environment using
nix-user-chroot for read-only or non-NixOS hosts (inspired by
https://github.com/quag/user-nix-steam-deck).

Layout on the host filesystem (default `nixDir = "/home/${username}/nix"`):
  - `${nixDir}/nix-user-chroot`: static nix-user-chroot binary
  - `${nixDir}/root-nix`: backing directory bind-mounted to `/nix` inside the chroot
  - `${nixDir}/home`: isolated `$HOME` inside the chroot
  - `${nixDir}/home/${username}`: symlink to `/home/${username}` on the host
  - `${nixDir}/enter`: helper script to enter the chroot environment

Exposes:

- flake.homeModules."feat/system/nix-user-chroot":
*/
{...}: let
  moduleName = "feat/system/nix-user-chroot";
in {
  flake.homeModules."common/options" = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    options.mod.${moduleName} = {
      hostHomeDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.home.username}";
        description = "Path to the user's host HOME directory outside nix-user-chroot.";
      };
      nixDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.hostHomeDirectory}/nix";
        description = "Base directory for the nix-user-chroot installation on the host.";
      };
      shell = lib.mkOption {
        type = lib.types.str;
        default =
          if config.mod.has "feat/terminal/shell/zsh"
          then "${config.home.profileDirectory}/bin/zsh -l"
          else if config.mod.has "feat/terminal/shell/bash"
          then "${config.home.profileDirectory}/bin/bash -l"
          else "/bin/bash -l";
        description = "Shell command executed by the enter script inside nix-user-chroot.";
      };
    };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
    nixProfile = ''
      . "${config.home.profileDirectory}/etc/profile.d/nix.sh"
    '';
    enterScript = ''
      #!/bin/bash
      export HOME=${config.home.homeDirectory}
      cd ~/
      du -hs ${cfg.nixDir}
      echo "home:" $HOME
      if [ $# -eq 0 ]; then
        set -- ${cfg.shell}
      fi
      exec ${cfg.nixDir}/nix-user-chroot ${cfg.nixDir}/root-nix /bin/sh -c '
        rm -rf /homeless-shelter 2>/dev/null || true
        mount -o remount,bind,ro / 2>/dev/null || true
        exec "$@"
      ' -- "$@"
    '';
  in {
    mod = {
      imported = [moduleName];
      asserts = ["standaloneOnly"];
    };

    home = {
      homeDirectory = lib.mkDefault "${cfg.nixDir}/home";
      packages = with pkgs; [
        nettools
      ];
      activation.setupNixUserChroot = lib.hm.dag.entryAfter ["writeBoundary"] ''
        # Maintain symlink from chroot $HOME/$USER -> host $HOME
        run ln -sfn "${cfg.hostHomeDirectory}" "${config.home.homeDirectory}/${config.home.username}"

        # Keep enter script updated outside the store
        if [ -d "${cfg.nixDir}" ]; then
          $DRY_RUN_CMD cat <<'EOF' > "${cfg.nixDir}/enter.tmp"
        ${enterScript}EOF
          run chmod u+x "${cfg.nixDir}/enter.tmp"
          run mv -f "${cfg.nixDir}/enter.tmp" "${cfg.nixDir}/enter"
        fi
      '';
    };

    # Inside nix-user-chroot, /nix is only mounted in the user namespace and is
    # invisible to the host's systemd --user daemon.
    nix = {
      gc.automatic = lib.mkForce false;
      # Single-user store owned by the user; deduplicate on write since daemon/timers aren't used.
      settings.auto-optimise-store = lib.mkDefault true;
    };
    systemd.user.startServices = lib.mkForce "suggest";
    xdg.portal.enable = lib.mkForce false;

    programs = {
      bash = lib.mkIf (config.mod.has "feat/terminal/shell/bash") {
        profileExtra = nixProfile;
      };
      zsh = lib.mkIf (config.mod.has "feat/terminal/shell/zsh") {
        profileExtra = nixProfile;
      };
    };
  };
}
