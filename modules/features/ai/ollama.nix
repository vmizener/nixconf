/*
  feat/ai/ollama

Enables Ollama OSS LLM local server for AI models.

Exposes:

- flake.nixosModules."feat/ai/ollama":
*/
{...}: let
  moduleName = "feat/ai/ollama";
in {
  flake.nixosModules."common/options" = {
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
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
  flake.nixosModules.${moduleName} = {
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
      package = cfg.package;
      host = cfg.host;
      port = cfg.port;
      loadModels = cfg.loadModels;
      openFirewall = cfg.openFirewall;
    };
  };
}
