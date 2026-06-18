/*
  feat/audio

Provides audio support.

Exposes:

- flake.nixosModules."feat/audio":
*/
{
  flake.nixosModules."feat/audio" = {
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

