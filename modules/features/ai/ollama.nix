/*
  feat/ai/ollama

Enables Ollama OSS LLM local server for AI models.

Exposes:

- flake.nixosModules."feat/ai/ollama":
- flake.homeModules."feat/ai/ollama":
*/
{...}: let
  moduleName = "feat/ai/ollama";

  ################
  # Common options for both Home-Manager and NixOS modules
  ollamaOptions = {
    lib,
    pkgs,
    ...
  }: {
    options.mod.${moduleName} = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ollama;
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
      };
      loadModels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };
  };

  ################
  # Common configs for both Home-Manager and NixOS modules
  ollamaCommon = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
    clientHost =
      if builtins.elem cfg.host ["0.0.0.0" "[::]" ""]
      then "127.0.0.1"
      else cfg.host;
  in {
    mod = {
      imported = [moduleName];
      ai.providers."ollama-local" = lib.mkIf (cfg.loadModels != []) {
        api = "openai-completions";
        apiKey = "ollama";
        baseUrl = "http://${clientHost}:${toString cfg.port}/v1";
        models = cfg.loadModels;
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
        };
      };
    };
    services.ollama = {
      enable = true;
      inherit (cfg) package host port;
    };
  };
in {
  ################
  # NixOS module options
  flake.nixosModules."common/options" = {lib, ...}: {
    imports = [ollamaOptions];
    options.mod.${moduleName}.openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  ################
  # Home-Manager module options
  flake.homeModules."common/options" = {...}: {
    imports = [ollamaOptions];
  };

  ################
  # NixOS config module
  flake.nixosModules.${moduleName} = {config, ...}: let
    cfg = config.mod.${moduleName};
  in {
    imports = [ollamaCommon];
    services.ollama = {
      inherit (cfg) loadModels openFirewall;
    };
  };

  ################
  # Home-Manager config module
  flake.homeModules.${moduleName} = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    imports = [ollamaCommon];
    systemd.user.services.ollama-model-loader = lib.mkIf (cfg.loadModels != []) {
      Unit = {
        Description = "Download ollama models in the background";
        Wants = ["network-online.target"];
        After = [
          "ollama.service"
          "network-online.target"
        ];
        BindsTo = ["ollama.service"];
      };
      Service = {
        Type = "exec";
        Environment = config.systemd.user.services.ollama.Service.Environment;
        Restart = "on-failure";
        RestartSec = "1s";
        RestartMaxDelaySec = "2h";
        RestartSteps = 10;
        ExecStart = pkgs.writeShellScript "ollama-model-loader" ''
          printf "%s\0" ${lib.escapeShellArgs cfg.loadModels} | ${lib.getExe' pkgs.findutils "xargs"} -0 -r -n 1 -P "$(${lib.getExe' pkgs.coreutils "nproc"})" ${lib.getExe cfg.package} pull
        '';
      };
      Install = {
        WantedBy = [
          "default.target"
          "ollama.service"
        ];
      };
    };
  };
}
