/*
  feat/io/audio

Provides audio support.

Exposes:

- flake.nixosModules."feat/io/audio":
*/
{...}: let
  moduleName = "feat/io/audio";
in {
  flake.nixosModules.${moduleName} = {...}: {
    mod.meta.imported = [moduleName];
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
