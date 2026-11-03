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
  # Cross-host SSH public key inventory and user/host authorization mappings
  options.inventory.ssh = {
    keysFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "TOML files merged into inventory.ssh.{keys,users,hosts} (use lib.mkForce to replace defaults).";
    };
    keys = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Named SSH public keys (alias -> public key string).";
    };
    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      description = "Key aliases authorized for each user across all hosts.";
    };
    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.listOf lib.types.str));
      default = {};
      description = "Additional per-host key aliases authorized for each user.";
    };
  };

  config = let
    tomlConfigs = map lib.importTOML flakeSsh.keysFiles;
  in {
    inventory.ssh = {
      keysFiles = [../../secrets/keys.toml];
      keys = lib.mkMerge (map (t: t.keys or {}) tomlConfigs);
      users = lib.mkMerge (map (t: t.users or {}) tomlConfigs);
      hosts = lib.mkMerge (map (t: t.hosts or {}) tomlConfigs);
    };

    flake.homeModules."common/options" = {lib, ...}: {
      options.mod.${moduleName}.authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "SSH public keys authorized for this Home-Manager user (seeded from inventory.ssh on standalone HM; use lib.mkForce to replace).";
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
        (resolveKeys (flakeSsh.users.${config.home.username} or []));

      assertions = lib.optionals (osConfig == null) (let
        userAliases = flakeSsh.users.${config.home.username} or [];
        missingAliases = builtins.filter (k: !(flakeSsh.keys ? ${k})) userAliases;
      in [
        {
          assertion = missingAliases == [];
          message = "inventory.ssh: undefined key alias(es) for user '${config.home.username}': ${lib.concatStringsSep ", " missingAliases}";
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
      hostUsers = flakeSsh.hosts.${hostName} or {};
      hmUsers = lib.optionalAttrs (options ? home-manager) config.home-manager.users;
    in {
      options.users.users = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule ({name, ...}: let
            userAliases = (flakeSsh.users.${name} or []) ++ (hostUsers.${name} or []);
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
          allowedSections = ["keys" "users" "hosts"];
          unknownSections =
            lib.unique (lib.concatMap builtins.attrNames tomlConfigs)
            |> builtins.filter (s: !(builtins.elem s allowedSections));
          unknownHosts =
            builtins.attrNames flakeSsh.hosts
            |> builtins.filter (h: !(self.nixosConfigurations ? ${h}));
          missingAliases =
            (
              lib.concatLists (builtins.attrValues flakeSsh.users)
              ++ lib.concatLists (lib.concatMap builtins.attrValues (builtins.attrValues flakeSsh.hosts))
            )
            |> lib.unique
            |> builtins.filter (k: !(flakeSsh.keys ? ${k}));
          missingHostUsers =
            builtins.attrNames hostUsers
            |> builtins.filter (u: !(config.users.users ? ${u}));
        in [
          {
            assertion = unknownSections == [];
            message = "inventory.ssh.keysFiles: unexpected top-level section(s): ${lib.concatStringsSep ", " unknownSections} (allowed: ${lib.concatStringsSep ", " allowedSections})";
          }
          {
            assertion = unknownHosts == [];
            message = "inventory.ssh.hosts: references unknown NixOS host(s): ${lib.concatStringsSep ", " unknownHosts}";
          }
          {
            assertion = missingAliases == [];
            message = "inventory.ssh: undefined key alias(es) referenced: ${lib.concatStringsSep ", " missingAliases}";
          }
          {
            assertion = missingHostUsers == [];
            message = "inventory.ssh.hosts.${hostName}: references user(s) not declared on '${hostName}': ${lib.concatStringsSep ", " missingHostUsers}";
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
