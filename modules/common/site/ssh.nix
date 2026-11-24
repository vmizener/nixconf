/*
  common/site/ssh

Cross-host SSH client public key registry (`options.site.ssh`, populated from
`site.meta.keysFiles`) and NixOS/Home-Manager `authorized_keys` + `sshd` broker
(`common/site/ssh`).

Exposes:

- options.site.ssh
- flake.homeModules."common/options" (options.mod."common/site/ssh")
- flake.homeModules."common/site/ssh"
- flake.nixosModules."common/site/ssh"
*/
{
  lib,
  self,
  ...
} @ flake: let
  moduleName = "common/site/ssh";
  siteSsh = flake.config.site.ssh;
  toml = import ./_toml.nix {inherit lib;};
  loaded = toml.loadTomlFiles {
    files = flake.config.site.meta.keysFiles;
    optSet = flake.options.site.ssh;
    sourceLabel = "site.meta.keysFiles";
  };
  resolveKeys = aliases:
    aliases
    |> builtins.filter (k: siteSsh.keys ? ${k})
    |> map (k: siteSsh.keys.${k});
in {
  options.site.ssh = {
    keys = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Named client SSH public keys (alias -> public key string, e.g. `'\"bao@baohaus\"'`).";
    };
    authorize = {
      allHosts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {};
        description = "Client key aliases authorized for each target user across all hosts (populated from `[authorize.all_hosts]`).";
      };
      hosts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf (lib.types.listOf lib.types.str));
        default = {};
        description = "Additional per-host client key aliases authorized for each target user on NixOS hosts (populated from `[authorize.hosts.<host>]`).";
      };
    };
  };

  config = {
    site = {
      ssh = loaded.config;
      meta.assertions = loaded.assertions;
    };

    flake.homeModules."common/options" = {lib, ...}: {
      options.mod.${moduleName}.authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "SSH public keys authorized for this Home-Manager user (seeded from `site.ssh.authorize.allHosts` on standalone HM; use `lib.mkForce` to replace).";
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
        (resolveKeys (siteSsh.authorize.allHosts.${config.home.username} or []));

      assertions = lib.optionals (osConfig == null) (let
        userAliases = siteSsh.authorize.allHosts.${config.home.username} or [];
        missingAliases = builtins.filter (k: !(siteSsh.keys ? ${k})) userAliases;
      in [
        {
          assertion = missingAliases == [];
          message = "site.ssh.authorize.allHosts: undefined key alias(es) for user '${config.home.username}': ${lib.concatStringsSep ", " missingAliases}";
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
      hostUsers = siteSsh.authorize.hosts.${hostName} or {};
      hmUsers = lib.optionalAttrs (options ? home-manager) config.home-manager.users;
    in {
      options.users.users = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule ({name, ...}: let
            userAliases = (siteSsh.authorize.allHosts.${name} or []) ++ (hostUsers.${name} or []);
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
        mod = {
          meta.imported = [moduleName];
          "common/firewall".ingress.sshd = {
            enable = config.services.openssh.enable && !config.services.openssh.openFirewall;
            zones = ["lan" "vpn"];
            tcp = config.services.openssh.ports;
          };
        };

        assertions = let
          unknownHosts =
            builtins.attrNames siteSsh.authorize.hosts
            |> builtins.filter (h: !(self.nixosConfigurations ? ${h}));
          missingAliases =
            (
              lib.concatLists (builtins.attrValues siteSsh.authorize.allHosts)
              ++ lib.concatLists (lib.concatMap builtins.attrValues (builtins.attrValues siteSsh.authorize.hosts))
            )
            |> lib.unique
            |> builtins.filter (k: !(siteSsh.keys ? ${k}));
          missingHostUsers =
            builtins.attrNames hostUsers
            |> builtins.filter (u: !(config.users.users ? ${u}));
        in [
          {
            assertion = unknownHosts == [];
            message = "site.ssh.authorize.hosts: references unknown NixOS host(s): ${lib.concatStringsSep ", " unknownHosts}";
          }
          {
            assertion = missingAliases == [];
            message = "site.ssh.authorize: undefined key alias(es) referenced: ${lib.concatStringsSep ", " missingAliases}";
          }
          {
            assertion = missingHostUsers == [];
            message = "site.ssh.authorize.hosts.${hostName}: references user(s) not declared on '${hostName}': ${lib.concatStringsSep ", " missingHostUsers}";
          }
        ];

        services.openssh = {
          enable = lib.mkDefault true;
          openFirewall = lib.mkDefault false;
          settings = {
            KbdInteractiveAuthentication = lib.mkDefault false;
            PasswordAuthentication = lib.mkDefault false;
            PermitRootLogin = lib.mkDefault "prohibit-password";
          };
        };
      };
    };
  };
}
