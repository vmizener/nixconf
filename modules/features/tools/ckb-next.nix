/*
  feat/tools/ckb-next

Enables the CKB-Next open-source driver for Corsair keyboards and mice.

Exposes:

- flake.nixosModules."feat/tools/ckb-next":
*/
{
  flake.nixosModules."feat/tools/ckb-next" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    # 06/02/2026 revision (supports Scimitar RGB Elite)
    src = pkgs.fetchFromGitHub {
      owner = "ckb-next";
      repo = "ckb-next";
      rev = "5edd3c14810c1aa93be5adde471071b97ef108b4";
      hash = "sha256-h5jZqiK4hYqlLFPY9jmJEniarSHE4ZcoIX4Qv3QdELc=";
    };
    pkg = pkgs.ckb-next.overrideAttrs (_: {inherit src;});
  in {
    features.tools = ["ckb-next"];
    environment.systemPackages = [pkg];
    hardware.ckb-next = {
      enable = true;
      package = pkg;
    };
    systemd.user.services.ckb-next = {
      enable = true;
      description = "Corsair keyboard next service";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.ckb-next} -b";
        Restart = "on-failure";
        RestartSec = "3";
      };
      wantedBy = ["default.target"];
    };
  };
}
