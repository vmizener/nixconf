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
        default = true;
      };
    };
  };
  flake.nixosModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.imported = [moduleName];
    services.ollama = {
      enable = true;
      package = cfg.package;
      host = cfg.host;
      port = cfg.port;
      loadModels = cfg.loadModels;
    };
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
  };
}
