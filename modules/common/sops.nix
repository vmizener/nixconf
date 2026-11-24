/*
  common/sops

Shared `sops-nix` secret management setup across NixOS (host SSH ed25519 age
key) and Home-Manager (per-user XDG age key), wired to `site.meta.secretsFile`.

Exposes:

- flake.homeModules."common/sops"
- flake.nixosModules."common/sops"
*/
{
  inputs,
  lib,
  ...
} @ flake: let
  moduleName = "common/sops";
  inherit (flake.config.site.meta) secretsFile;
in {
  flake.nixosModules.${moduleName} = {...}: {
    imports = [
      inputs.sops-nix.nixosModules.sops
    ];
    mod.meta.imported = [moduleName];
    sops = {
      defaultSopsFile = lib.mkIf (secretsFile != null) (lib.mkDefault secretsFile);
      # Derive host age key from OpenSSH ed25519 key (matches `&host_<hostname>` in .sops.yaml)
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      # Disable sops-nix's default RSA host key -> GPG import (repo only uses age)
      gnupg.sshKeyPaths = [];
    };
  };
  flake.homeModules.${moduleName} = {config, ...}: {
    imports = [
      inputs.sops-nix.homeManagerModules.sops
    ];
    mod.meta.imported = [moduleName];
    sops = {
      defaultSopsFile = lib.mkIf (secretsFile != null) (lib.mkDefault secretsFile);
      # User services can't read /etc/ssh host keys; use per-user key (`&<user>_<hostname>`)
      age = {
        keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
        generateKey = true;
      };
    };
  };
}
