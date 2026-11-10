/*
  host/goug

Lightweight, hardwareless NixOS host dedicated exclusively to testing features
(primarily UI/desktop modules) inside a QEMU VM (`just vm-run goug`). It has no
associated physical hardware or `hardware/goug` module.

Exposes:

- flake.nixosConfigurations.goug
- flake.nixosModules."host/goug"
*/
{
  self,
  inputs,
  lib,
  ...
}: let
  hostname = "goug";
in {
  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules."host/${hostname}"
    ];
  };
  flake.nixosModules."host/${hostname}" = {...}: {
    imports = [
      self.nixosModules."common"
      self.nixosModules."users/mustadio@${hostname}"

      self.nixosModules."feat/system/keyring"
      self.nixosModules."feat/system/locale"
      self.nixosModules."feat/system/systools"
      self.nixosModules."feat/vm"
    ];
    mod."feat/vm" = {
      isVm = true;
      autologinUser = "mustadio";
      cores = 8;
      memorySize = 16384;
    };

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    system.stateVersion = "25.11";
    networking.hostName = hostname;
    users.mutableUsers = false;

    hardware = {
      graphics.enable = true;
      uinput.enable = true;
    };
    fonts.enableDefaultPackages = true;
  };
}
