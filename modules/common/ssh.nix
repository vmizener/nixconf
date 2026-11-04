{
  config,
  lib,
  self,
  ...
}: let
  moduleName = "common/ssh";
  flakeSsh = config.inventory.ssh;
  resolveKeys = aliases:
    aliases
    |> builtins.filter (k: flakeSsh.keys ? ${k})
    |> map (k: flakeSsh.keys.${k});
in {
  # Cross-host SSH public key inventory and target user/host authorization mappings
  options.inventory.ssh = {
    keysFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "TOML files merged into inventory.ssh.{keys,authorize} (use lib.mkForce to replace defaults).";
    };
    keys = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Named client SSH public keys (alias -> public key string, e.g. '\"bao@baohaus\"').";
    };
    authorize = {
      allHosts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {};
        description = "Client key aliases authorized for each target user across all hosts (populated from [authorize.all_hosts]).";
      };
      hosts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf (lib.types.listOf lib.types.str));
        default = {};
        description = "Additional per-host client key aliases authorized for each target user on NixOS hosts (populated from [authorize.hosts.<host>]).";
      };
    };
  };

  config = let
    tomlConfigs = map lib.importTOML flakeSsh.keysFiles;
    allowedSections = ["keys" "authorize"];
    allowedAuthorizeSections = ["all_hosts" "hosts"];
    unknownSections =
      lib.unique (lib.concatMap builtins.attrNames tomlConfigs)
      |> builtins.filter (s: !(builtins.elem s allowedSections));
    unknownAuthorizeSections =
      lib.unique (lib.concatMap (t: builtins.attrNames (t.authorize or {})) tomlConfigs)
      |> builtins.filter (s: !(builtins.elem s allowedAuthorizeSections));
    tomlSchemaAssertions = [
      {
        assertion = unknownSections == [];
        message = "inventory.ssh.keysFiles: unexpected top-level section(s): ${lib.concatStringsSep ", " unknownSections} (allowed: ${lib.concatStringsSep ", " allowedSections})";
      }
      {
        assertion = unknownAuthorizeSections == [];
        message = "inventory.ssh.keysFiles: unexpected [authorize] subsection(s): ${lib.concatStringsSep ", " unknownAuthorizeSections} (allowed: ${lib.concatStringsSep ", " allowedAuthorizeSections})";
      }
    ];
  in {
    inventory.ssh = {
      keysFiles = [../../secrets/keys.toml];
      keys = lib.mkMerge (map (t: t.keys or {}) tomlConfigs);
      authorize = {
        allHosts = lib.mkMerge (map (t: t.authorize.all_hosts or {}) tomlConfigs);
        hosts = lib.mkMerge (map (t: t.authorize.hosts or {}) tomlConfigs);
      };
    };

    flake.homeModules."common/options" = {lib, ...}: {
      options.mod.${moduleName}.authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "SSH public keys authorized for this Home-Manager user (seeded from inventory.ssh.authorize.allHosts on standalone HM; use lib.mkForce to replace).";
      };
    };

    flake.homeModules.${moduleName} = {
      config,
      lib,
      osConfig ? null,
      ...
    }: let
      keys = lib.unique config.mod.${moduleName}.authorizedKeys;
    in {
      mod.meta.imported = [moduleName];
      mod.${moduleName}.authorizedKeys =
        lib.mkIf (osConfig == null)
        (resolveKeys (flakeSsh.authorize.allHosts.${config.home.username} or []));

      assertions = lib.optionals (osConfig == null) (let
        userAliases = flakeSsh.authorize.allHosts.${config.home.username} or [];
        missingAliases = builtins.filter (k: !(flakeSsh.keys ? ${k})) userAliases;
      in
        tomlSchemaAssertions
        ++ [
          {
            assertion = missingAliases == [];
            message = "inventory.ssh.authorize.allHosts: undefined key alias(es) for user '${config.home.username}': ${lib.concatStringsSep ", " missingAliases}";
          }
        ]);

      home.file.".ssh/authorized_keys" = lib.mkIf (osConfig == null && keys != []) {
        text = lib.concatLines keys;
      };
    };

    flake.nixosModules.${moduleName} = {
      config,
      lib,
      options,
      ...
    }: let
      hostName = config.networking.hostName;
      hostUsers = flakeSsh.authorize.hosts.${hostName} or {};
      hmUsers = lib.optionalAttrs (options ? home-manager) config.home-manager.users;
    in {
      options.users.users = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule ({name, ...}: let
            userAliases = (flakeSsh.authorize.allHosts.${name} or []) ++ (hostUsers.${name} or []);
            hmKeys =
              if hmUsers ? ${name}
              then hmUsers.${name}.mod.${moduleName}.authorizedKeys
              else [];
          in {
            config.openssh.authorizedKeys.keys = lib.unique (resolveKeys userAliases ++ hmKeys);
          })
        );
      };

      config = {
        mod.meta.imported = [moduleName];

        assertions = let
          unknownHosts =
            builtins.attrNames flakeSsh.authorize.hosts
            |> builtins.filter (h: !(self.nixosConfigurations ? ${h}));
          missingAliases =
            (
              lib.concatLists (builtins.attrValues flakeSsh.authorize.allHosts)
              ++ lib.concatLists (lib.concatMap builtins.attrValues (builtins.attrValues flakeSsh.authorize.hosts))
            )
            |> lib.unique
            |> builtins.filter (k: !(flakeSsh.keys ? ${k}));
          missingHostUsers =
            builtins.attrNames hostUsers
            |> builtins.filter (u: !(config.users.users ? ${u}));
        in
          tomlSchemaAssertions
          ++ [
            {
              assertion = unknownHosts == [];
              message = "inventory.ssh.authorize.hosts: references unknown NixOS host(s): ${lib.concatStringsSep ", " unknownHosts}";
            }
            {
              assertion = missingAliases == [];
              message = "inventory.ssh.authorize: undefined key alias(es) referenced: ${lib.concatStringsSep ", " missingAliases}";
            }
            {
              assertion = missingHostUsers == [];
              message = "inventory.ssh.authorize.hosts.${hostName}: references user(s) not declared on '${hostName}': ${lib.concatStringsSep ", " missingHostUsers}";
            }
          ];

        services.openssh = {
          enable = true;
          settings = {
            KbdInteractiveAuthentication = false;
            PasswordAuthentication = false;
            PermitRootLogin = "prohibit-password";
          };
        };
      };
    };
  };
}
