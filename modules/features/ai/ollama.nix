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
        defaultText = lib.literalExpression "pkgs.ollama";
        description = "Ollama package to use.";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Host address for the Ollama server to bind to.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port for the Ollama server to listen on.";
      };
      loadModels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Ollama model tags to pull in the background and register under `mod.\"common/ai\".providers.\"ollama-local\"`.";
      };
      syncModels = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to prune locally installed Ollama models not listed in `loadModels`.";
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
      meta.imported = [moduleName];
      "common/ai".providers."ollama-local" = lib.mkIf (cfg.loadModels != []) {
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
      description = "Whether to open the Ollama server port in the firewall.";
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
    mod."common/site/net".ports.ollama.tcp = [cfg.port];
    services.ollama = {
      inherit (cfg) loadModels syncModels openFirewall;
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
    ollama = lib.getExe cfg.package;
    awk = lib.getExe pkgs.gawk;
    sed = lib.getExe pkgs.gnused;
    nproc = lib.getExe' pkgs.coreutils "nproc";
    xargs = lib.getExe' pkgs.findutils "xargs";
    declaredModelsRegex = lib.pipe cfg.loadModels [
      (map lib.escapeRegex)
      (lib.concatStringsSep "|")
      (lib.escape ["/"])
      lib.escapeShellArg
    ];
  in {
    imports = [ollamaCommon];
    mod.meta.asserts = ["conflictsNixosFeat"];
    systemd.user.services.ollama-model-loader = lib.mkIf (cfg.loadModels != [] || cfg.syncModels) {
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
          ${lib.optionalString cfg.syncModels ''
            installed=$('${ollama}' list | '${awk}' 'NR > 1 {print $1}')
            ${
              if (cfg.loadModels != [])
              then ''
                echo declared models regex: ${declaredModelsRegex}
                undeclared=$(echo "$installed" | '${sed}' -E /${declaredModelsRegex}/d)
              ''
              else ''
                undeclared="$installed"
              ''
            }
            if [ -n "$undeclared" ]; then
              echo removing: $undeclared
              '${ollama}' rm $undeclared
            fi
          ''}
          ${lib.optionalString (cfg.loadModels != []) ''
            printf "%s\0" ${lib.escapeShellArgs cfg.loadModels} | '${xargs}' -0 -r -n 1 -P "$('${nproc}')" '${ollama}' pull
          ''}
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
