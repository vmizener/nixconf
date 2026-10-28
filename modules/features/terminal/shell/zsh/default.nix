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

        # Leave `enableCompletion = true` so HM still installs `nix-zsh-completions`
        # (needed on standalone HM, where NixOS isn't installing it system-wide) and
        # signals to other HM modules that Zsh completions are enabled, but clear
        # `completionInit` to skip HM's early `compinit` at `mkOrder 570`—`./zshrc`
        # runs `compinit` once after loading plugins and before `zinit cdreplay`.
        completionInit = "";

        history = {
          size = 5000;
          path = "${config.xdg.stateHome}/zsh/history";
          append = true;
          share = true;
          ignoreSpace = true;
          ignoreAllDups = true;
          saveNoDups = true;
          ignoreDups = true;
          findNoDups = true;
        };
        initContent = lib.mkMerge [
          (lib.mkOrder 500 ''
            [[ -f "${hmSessionVars}" ]] && source "${hmSessionVars}"
            [[ -f "${hmNixProfile}" ]] && source "${hmNixProfile}"
            emulate zsh -c "$(${lib.getExe config.programs.direnv.package} export zsh)"
            # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
            # Initialization code that may require console input (password prompts, [y/n]
            # confirmations, etc.) must go above this block; everything else may go below.
            if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
              source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
            fi
          '')
          (lib.mkOrder 1000 (
            lib.strings.concatStringsSep "\n" (
              [
                (builtins.readFile ./zshrc)
                "source ${./p10k.zsh}"
              ]
              ++ (import ./_aliases.nix {
                inherit config lib;
                installed = installedPackages;
              })
              ++ cfg.extraConfig
            )
          ))
        ];
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
    programs.zsh = {
      enable = true;

      # Keep `enableCompletion = true` (links `/share/zsh` + installs `nix-zsh-completions`),
      # but skip `/etc/zshrc`'s `compinit` so it only runs once in `./zshrc`.
      enableGlobalCompInit = false;
    };
  };
}
