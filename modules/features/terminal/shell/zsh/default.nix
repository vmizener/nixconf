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
  in {
    mod.meta = {
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
        defaultKeymap = "viins";

        # Leave `enableCompletion = true` so HM installs `nix-zsh-completions` and signals
        # completion support to other HM modules, but skip HM's `compinit` at `mkOrder 570`—
        # ./zshrc (`mkOrder 550`) runs `compinit` once right after p10k instant prompt.
        completionInit = "";

        autosuggestion = {
          enable = true;
          highlight = "fg=#696969";
        };
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
        historySubstringSearch = {
          enable = true;
          searchUpKey = [
            "^[[A"
            "^k"
          ];
          searchDownKey = [
            "^[[B"
            "^j"
          ];
        };
        syntaxHighlighting.enable = true;
        envExtra = ''
          [[ -f "${hmNixProfile}" ]] && source "${hmNixProfile}"
        '';
        initContent = lib.mkOrder 550 "source ${pkgs.replaceVars ./zshrc {
          ALIASES = lib.concatStringsSep "\n" (import ./_aliases.nix {
            inherit config lib;
            installed = config.home.packages ++ lib.optionals (osConfig != null) osConfig.environment.systemPackages;
          });
          DIRENV = lib.getExe config.programs.direnv.package;
          EXTRA_CONFIG = lib.concatStringsSep "\n" cfg.extraConfig;
          FZF_HISTORY_SEARCH = "${pkgs.zsh-fzf-history-search}/share/zsh-fzf-history-search/zsh-fzf-history-search.plugin.zsh";
          FZF_TAB = "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh";
          HM_NIX_PROFILE = hmNixProfile;
          HM_SESSION_VARS = hmSessionVars;
          P10K_CONFIG = "${./p10k.zsh}";
          P10K_THEME = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }}";
      };
    };
    home = {
      packages = with pkgs; [
        fzf
        zsh-completions
      ];
    };
    xdg.configFile."direnv/direnv.toml".text = ''
      [global]
      log_filter="^loading"
    '';
  };
  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
    programs.zsh = {
      enable = true;

      # Keep `enableCompletion = true` (links `/share/zsh` + installs `nix-zsh-completions`),
      # but skip `/etc/zshrc`'s `compinit` so Home-Manager runs it once in `.zshrc`.
      enableGlobalCompInit = false;
    };
  };
}
