# Aggregates VM runner (`vm-run-<host>`) and reset (`vm-reset-<host>`) packages
# across NixOS (`_nixos-vm.nix`) and standalone Home-Manager (`_hm-vm.nix`).
{
  inputs,
  lib,
  moduleName,
  pkgs,
  self,
  system,
}: let
  nixglPkg = inputs.nixgl.packages.${system}.nixGLIntel or null;
  nixglBin =
    if nixglPkg != null
    then "${nixglPkg}/bin/nixGLIntel"
    else "";

  mkBinScript = name: src: replacements: let
    script = pkgs.replaceVars src replacements;
  in
    pkgs.runCommand name {
      nativeBuildInputs = [pkgs.shellcheck];
      meta.mainProgram = name;
    } ''
      install -Dm755 "${script}" "$out/bin/${name}"
      shellcheck -s bash "$out/bin/${name}"
    '';

  mkResetPkg = {
    hostName,
    name,
    storageDir,
  }:
    mkBinScript name ./scripts/vm-reset.sh {
      HOST_NAME = hostName;
      STORAGE_DIR = storageDir;
    };

  nixosVmPackages = import ./_nixos-vm.nix {
    inherit lib mkBinScript mkResetPkg moduleName nixglBin self system;
  };

  hmVmPackages = import ./_hm-vm.nix {
    inherit lib mkBinScript mkResetPkg moduleName nixglBin pkgs self system;
  };

  collidingPackages = builtins.attrNames (builtins.intersectAttrs nixosVmPackages hmVmPackages);
in
  if collidingPackages != []
  then throw "${moduleName}: colliding NixOS and standalone Home-Manager VM package(s): ${lib.concatStringsSep ", " collidingPackages}"
  else nixosVmPackages // hmVmPackages
