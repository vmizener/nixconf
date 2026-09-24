/*
  feat/ai/pi

Enables Pi, the minimal agent harness.

Exposes:

- flake.homeModules."feat/ai/pi":
*/
{...}: let
  moduleName = "feat/ai/pi";
in {
  flake.homeModules."common/options" = {
    lib,
    pkgs,
    ...
  }: {
    options.mod.${moduleName} = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.pi-coding-agent;
      };
    };
  };
  flake.homeModules.${moduleName} = {config, ...}: let
    cfg = config.mod.${moduleName};
  in {
    mod.imported = [moduleName];
    programs.pi-coding-agent = {
      enable = true;
      package = cfg.package;
      settings = {
        # TODO: make settings configurable
        defaultProvider = "ollama-local";
        defaultModel = {
          id = "qwen2.5-coder:7b";
          name = "Qwen 2.5 Coder 7B";
          input = ["text"];
          reasoning = false;
        };
        defaultThinkingLevel = "medium";
      };
      models = {
        providers = {
          # TODO: read this stuff from ollama module
          "ollama-local" = {
            api = "openai-completions";
            apiKey = "ollama";
            models = [
              {
                id = "qwen2.5-coder:7b";
                name = "Qwen 2.5 Coder 7B";
                input = ["text"];
                reasoning = false;
              }
            ];
            baseUrl = "http://127.0.0.1:11434/v1";
          };
        };
      };
      context = ''
        Stay brief.
        Prefer small, reviewable changes.
        Inspect the repository before editing.
        Do not modify files outside the current project unless explicitly asked.
        Propose changes before making any.
        Run relevant tests after making changes.
      '';
    };
  };
}
