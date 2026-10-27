{inputs, ...}: {
  flake.nixosModules."common/sops" = {...}: {
    imports = [
      inputs.sops-nix.nixosModules.sops
    ];
    sops = {
      defaultSopsFile = ../secrets/secrets.yaml;
      # Derive host age key from OpenSSH ed25519 key (matches `&host_<hostname>` in .sops.yaml)
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      # Disable sops-nix's default RSA host key -> GPG import (repo only uses age)
      gnupg.sshKeyPaths = [];
    };
  };
  flake.homeModules."common/sops" = {config, ...}: {
    imports = [
      inputs.sops-nix.homeManagerModules.sops
    ];
    sops = {
      defaultSopsFile = ../secrets/secrets.yaml;
      # User services can't read /etc/ssh host keys; use per-user key (`&<user>_<hostname>`)
      age = {
        keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
        generateKey = true;
      };
    };
  };
}
