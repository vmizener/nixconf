/*
  feat/system/audio

Provides audio support.

Exposes:

- flake.nixosModules."feat/system/audio":
*/
{
  flake.nixosModules."feat/system/audio" = {...}: {
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
