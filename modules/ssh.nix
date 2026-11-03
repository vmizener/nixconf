{...}: {
  flake.homeModules."common/ssh" = {
    config,
    lib,
    osConfig ? null,
    ...
  }: let
    cfg = config.mod.ssh;
    reg = cfg.registry;
    aliases = reg.users.${config.home.username} or [];
    missingAliases = builtins.filter (k: !(reg.keys ? ${k})) aliases;
    resolvedKeys =
      aliases
      |> builtins.filter (k: reg.keys ? ${k})
      |> map (k: reg.keys.${k})
      |> (ks: lib.unique (ks ++ cfg.authorizedKeys));
  in {
    mod.ssh = lib.mkIf (osConfig == null) {
      keysFiles = [../secrets/keys.toml];
      registry = lib.mkMerge (map lib.importTOML cfg.keysFiles);
    };

    assertions = [
      {
        assertion = osConfig == null || cfg.keysFiles == [];
        message = "On NixOS hosts, set `mod.ssh.keysFiles` at the NixOS configuration level rather than inside `home-manager.users.${config.home.username}`.";
      }
      {
        assertion = osConfig != null || missingAliases == [];
        message = "mod.ssh: undefined key alias(es) for user '${config.home.username}': ${lib.concatStringsSep ", " missingAliases}";
      }
    ];

    home.file.".ssh/authorized_keys" = lib.mkIf (osConfig == null && resolvedKeys != []) {
      text = lib.concatLines resolvedKeys;
    };
  };

  flake.nixosModules."common/ssh" = {
    config,
    lib,
    options,
    ...
  }: let
    cfg = config.mod.ssh;
    reg = cfg.registry;
    hostName = config.networking.hostName;
    hostUsers = reg.hosts.${hostName} or {};
    hmUsers = lib.optionalAttrs (options ? home-manager) config.home-manager.users;
    allAliases = lib.unique (
      lib.concatLists (builtins.attrValues reg.users)
      ++ lib.concatLists (lib.concatMap builtins.attrValues (builtins.attrValues reg.hosts))
    );
    missingAliases = builtins.filter (k: !(reg.keys ? ${k})) allAliases;
    missingHostUsers =
      builtins.attrNames hostUsers
      |> builtins.filter (u: !(config.users.users ? ${u}));
  in {
    options.users.users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule ({name, ...}: let
          userAliases = (reg.users.${name} or []) ++ (hostUsers.${name} or []);
          hmKeys =
            if hmUsers ? ${name}
            then hmUsers.${name}.mod.ssh.authorizedKeys
            else [];
        in {
          config.openssh.authorizedKeys.keys =
            userAliases
            |> builtins.filter (k: reg.keys ? ${k})
            |> map (k: reg.keys.${k})
            |> (ks: lib.unique (ks ++ hmKeys));
        })
      );
    };

    config = {
      mod.ssh = {
        keysFiles = [../secrets/keys.toml];
        registry = lib.mkMerge (map lib.importTOML cfg.keysFiles);
      };

      assertions = [
        {
          assertion = missingAliases == [];
          message = "mod.ssh: undefined key alias(es) referenced: ${lib.concatStringsSep ", " missingAliases}";
        }
        {
          assertion = missingHostUsers == [];
          message = "mod.ssh: [hosts.${hostName}] references user(s) not declared on '${hostName}': ${lib.concatStringsSep ", " missingHostUsers}";
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
