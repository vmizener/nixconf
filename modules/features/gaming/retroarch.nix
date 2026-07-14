/*
  feat/gaming/retroarch

Retroarch.

Exposes:

- flake.homeModules."feat/gaming/retroarch":
*/
{
  flake.nixosModules."common/options" = {...}: {
  };
  flake.homeModules."feat/gaming/retroarch" = {config, ...}: {
    programs.retroarch = {
      enable = true;
      cores = {
        pcsx2.enable = true;
        snes9x.enable = true;
      };
      settings = {
        video_driver = "vulkan";
        video_fullscreen = "true";
        config_save_on_exit = "true";

        input_remapping_directory = "${config.xdg.configHome}/retroarch/remaps";
        joypad_autoconfig_dir = "${config.xdg.configHome}/retroarch/autoconfig";
        savefile_directory = "${config.xdg.configHome}/retroarch/saves";
        state_slot_directory = "${config.xdg.configHome}/retroarch/states";
      };
    };
  };
}
