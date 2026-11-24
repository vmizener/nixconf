/*
  common/site (meta)

Declares `options.site.meta` consumer-flake file layout pointers (`config.toml`,
`keys.toml`, `secrets.yaml`) and loads `site.meta.configFiles` across declared
`options.site.*` namespaces.
*/
{
  config,
  lib,
  options,
  self,
  ...
}: let
  siteMeta = config.site.meta;
  toml = import ./_toml.nix {inherit lib;};
  loaded = toml.loadTomlFiles {
    files = siteMeta.configFiles;
    optSet = removeAttrs options.site ["meta" "ssh"];
    sourceLabel = "site.meta.configFiles";
  };
in {
  options.site.meta = {
    path = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = self;
      defaultText = lib.literalExpression "self";
      description = "Base directory or flake input containing default site files (`config.toml`, `keys.toml`, `secrets.yaml`).";
    };
    configFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = let
        defaultFile = "${siteMeta.path}/config.toml";
      in
        lib.optional
        (siteMeta.path != null && builtins.pathExists defaultFile)
        defaultFile;
      defaultText = lib.literalExpression ''
        lib.optional
          (config.site.meta.path != null && builtins.pathExists "''${config.site.meta.path}/config.toml")
          "''${config.site.meta.path}/config.toml"
      '';
      description = "TOML files merged into `site.*` namespaces (excluding `site.meta` and `site.ssh`).";
    };
    keysFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = let
        defaultFile = "${siteMeta.path}/keys.toml";
      in
        lib.optional
        (siteMeta.path != null && builtins.pathExists defaultFile)
        defaultFile;
      defaultText = lib.literalExpression ''
        lib.optional
          (config.site.meta.path != null && builtins.pathExists "''${config.site.meta.path}/keys.toml")
          "''${config.site.meta.path}/keys.toml"
      '';
      description = "TOML files merged into `site.ssh.{keys,authorize}`.";
    };
    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default =
        if siteMeta.path != null
        then "${siteMeta.path}/secrets.yaml"
        else null;
      defaultText = lib.literalExpression ''
        if config.site.meta.path != null
        then "''${config.site.meta.path}/secrets.yaml"
        else null
      '';
      description = "Default `sops-nix` secrets file wired to `sops.defaultSopsFile`.";
    };
    assertions = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [];
      internal = true;
      description = "Schema validation assertions collected across `site.meta.{configFiles,keysFiles}`.";
    };
  };

  config.site =
    loaded.config
    // {
      meta.assertions = loaded.assertions;
    };
}
