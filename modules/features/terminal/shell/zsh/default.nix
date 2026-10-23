/*
  feat/shell/zsh

Enables interactive Zsh shell environment with Powerlevel10k theme.

Exposes:

- flake.homeModules."feat/terminal/shell/zsh":
  - Enables Zsh for the user.
*/
{...}: let
  moduleName = "feat/terminal/shell/zsh";
in {
  flake.homeModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      extraConfig = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Additional config lines to append to zshrc";
        default = [];
      };
    };
  };
  flake.homeModules.${moduleName} = {
    config,
    lib,
    osConfig ? null,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};

    hmSessionVars = "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";
    hmNixProfile = "${config.home.profileDirectory}/etc/profile.d/nix.sh";
    installedPackages =
      config.home.packages
      ++ lib.optionals (osConfig != null) osConfig.environment.systemPackages;
  in {
    mod = {
      imported = [moduleName];
      asserts = ["pairedNixosFeat"];
    };
    programs = {
      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
      zsh = {
        enable = true;
        dotDir = "${config.xdg.configHome}/zsh";
        initContent = lib.strings.concatStringsSep "\n" (
          [
            ''[[ -f "${hmSessionVars}" ]] && source "${hmSessionVars}"''
            ''[[ -f "${hmNixProfile}" ]] && source "${hmNixProfile}"''
            ''emulate zsh -c "$(direnv export zsh)"''
            "${builtins.readFile ./zshrc}"
            "source ${./p10k.zsh}"
          ]
          ++ (import ./_aliases.nix {
            inherit config lib;
            installed = installedPackages;
          })
          ++ cfg.extraConfig
        );
      };
    };
    home = {
      packages = with pkgs; [
        fzf
      ];
    };
    xdg.configFile."direnv/direnv.toml".text = ''
      [global]
      log_filter="^loading"
    '';
  };
  flake.nixosModules.${moduleName} = {...}: {
    mod.imported = [moduleName];
    programs.zsh.enable = true;
  };
}
