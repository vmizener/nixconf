/*
  feat/ai

Shared AI provider option definitions for NixOS and Home-Manager AI modules.
*/
{...}: let
  aiOptions = {lib, ...}: {
    options.mod.ai = {
      providers = lib.mkOption {
        description = "Registered AI model providers";
        default = {};
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              api = lib.mkOption {
                type = lib.types.str;
                default = "openai-completions";
                description = "API protocol type";
              };
              apiKey = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "API key or placeholder for authentication";
              };
              baseUrl = lib.mkOption {
                type = lib.types.str;
                description = "Base URL for the provider API endpoint";
              };
              models = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "List of model IDs available from this provider";
              };
              compat = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = {};
                description = "Provider compatibility flags";
              };
            };
          }
        );
      };
    };
  };
in {
  flake.nixosModules."common/options" = aiOptions;
  flake.homeModules."common/options" = aiOptions;
}
