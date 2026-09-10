/*
  feat/system/audio

Provides audio support.

Exposes:

- flake.nixosModules."feat/system/audio":
*/
{...}: let
  moduleName = "feat/system/audio";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod.imported = [moduleName];
    security.rtkit.enable = true;
    services = {
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        # jack.enable = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };
      pulseaudio.enable = false;
    };
  };
}
