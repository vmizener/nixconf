{
  lib,
  self,
  ...
}: let
  sshKeysCfg = fromTOML (builtins.readFile ../secrets/keys.toml);
  sshKeyMap = sshKeysCfg.keys or {};
  sshGlobalUsers = sshKeysCfg.users or {};
  sshHostUsers = sshKeysCfg.hosts or {};

  resolveSshKeys = aliases:
    aliases
    |> lib.unique
    |> builtins.filter (k: sshKeyMap ? ${k})
    |> map (k: sshKeyMap.${k});

  sshConfigAssertions = let
    allowedSections = ["keys" "users" "hosts"];
    unknownSections =
      builtins.attrNames sshKeysCfg
      |> builtins.filter (s: !(builtins.elem s allowedSections));
    unknownHosts =
      builtins.attrNames sshHostUsers
      |> builtins.filter (h: !(self.nixosConfigurations ? ${h}));
    missingUserAliases = lib.concatLists (
      lib.mapAttrsToList (
        user: aliases:
          aliases
          |> builtins.filter (k: !(sshKeyMap ? ${k}))
          |> map (k: "users.${user} -> '${k}'")
      )
      sshGlobalUsers
    );
    missingHostAliases = lib.concatLists (
      lib.mapAttrsToList (
        host: usersAttr:
          lib.concatLists (
            lib.mapAttrsToList (
              user: aliases:
                aliases
                |> builtins.filter (k: !(sshKeyMap ? ${k}))
                |> map (k: "hosts.${host}.${user} -> '${k}'")
            )
            usersAttr
          )
      )
      sshHostUsers
    );
    allMissingAliases = missingUserAliases ++ missingHostAliases;
  in [
    {
      assertion = unknownSections == [];
      message = "secrets/keys.toml: unexpected top-level section(s): ${lib.concatStringsSep ", " unknownSections} (allowed: ${lib.concatStringsSep ", " allowedSections})";
    }
    {
      assertion = unknownHosts == [];
      message = "secrets/keys.toml: [hosts] references unknown NixOS host(s): ${lib.concatStringsSep ", " unknownHosts}";
    }
    {
      assertion = allMissingAliases == [];
      message = "secrets/keys.toml: undefined key alias(es) referenced: ${lib.concatStringsSep ", " allMissingAliases}";
    }
  ];
in {
  flake.homeModules."common/ssh" = {
    config,
    lib,
    osConfig ? null,
    ...
  }: let
    standaloneSshKeys = resolveSshKeys (sshGlobalUsers.${config.home.username} or []);
  in {
    assertions = lib.optionals (osConfig == null) sshConfigAssertions;
    home.file.".ssh/authorized_keys" = lib.mkIf (osConfig == null && standaloneSshKeys != []) {
      text = lib.concatLines standaloneSshKeys;
    };
  };

  flake.nixosModules."common/ssh" = {
    config,
    lib,
    ...
  }: let
    hostName = config.networking.hostName;
    hostSshUsers = sshHostUsers.${hostName} or {};
    missingHostUsers =
      builtins.attrNames hostSshUsers
      |> builtins.filter (u: !(config.users.users ? ${u}));
  in {
    options.users.users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule ({name, ...}: {
          config.openssh.authorizedKeys.keys = resolveSshKeys (
            (sshGlobalUsers.${name} or []) ++ (hostSshUsers.${name} or [])
          );
        })
      );
    };

    config = {
      assertions =
        sshConfigAssertions
        ++ [
          {
            assertion = missingHostUsers == [];
            message = "secrets/keys.toml: [hosts.${hostName}] references user(s) not declared on '${hostName}': ${lib.concatStringsSep ", " missingHostUsers}";
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
}
