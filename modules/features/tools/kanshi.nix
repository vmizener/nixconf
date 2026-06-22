/*
  feat/tools/kanshi

Enables the Kanshi display configuration tool.

Exposes:

- flake.homeModules."feat/tools/kanshi":
*/
{
  flake.homeModules."common/options" = {
  };
  flake.homeModules."feat/tools/kanshi" = {
    config,
    pkgs,
    ...
  }: let
    # flakepath = "${config.home.sessionVariables.NH_FLAKE}";
    # execThemeReset = (builtins.toString (pkgs.writeShellScript "kanshi-theme-reset" ''
    #   ${flakepath}/scripts/run theme::reset
    # ''));
  in {
    home.packages = with pkgs; [kanshi];
    services.kanshi = {
      enable = true;
      settings = [
        # Outputs
        {
          output = {
            # x1 carbon gen12
            alias = "laptop";
            criteria = "Chimei Innolux Corporation 0x1450 Unknown";
            scale = 1.5;
            mode = "--custom 2880x1800@59.969Hz"; # custom configured via wdisplays
            position = "0,0";
          };
        }
        # Profiles
        {
          profile.name = "nomad";
          profile.outputs = [
            {
              criteria = "$laptop";
              status = "enable";
            }
          ];
          # profile.exec = execThemeReset;
        }
        {
          profile.name = "baohaus";
          profile.outputs = [
            {
              criteria = "Dell Inc. DELL U2415 CFV9N7CN28NL";
              status = "enable";
              position = "0,0";
              scale = 1.0;
            }
            {
              criteria = "Dell Inc. DELL U2415 CFV9N7CN202L";
              status = "enable";
              position = "1920,0";
              scale = 1.0;
            }
          ];
          # profile.exec = execThemeReset;
        }
        {
          profile.name = "cloe";
          profile.outputs = [
            {
              criteria = "$laptop";
              status = "enable";
            }
            {
              criteria = "Lenovo Group Limited * *";
              status = "enable";
              position = "1920,0";
              scale = 1.25;
            }
          ];
          # profile.exec = execThemeReset;
        }
        {
          profile.name = "googs";
          profile.outputs = [
            {
              criteria = "Dell Inc. DELL P3223QE G2CXWN3";
              status = "enable";
              position = "0,0";
              scale = 1.0;
            }
            {
              criteria = "$laptop";
              status = "enable";
              position = "740,2160";
            }
          ];
          # profile.exec = execThemeReset;
        }
        {
          profile.name = "tony";
          profile.outputs = [
            {
              criteria = "Dell Inc. DELL P3223QE GC68F34";
              status = "enable";
              position = "0,0";
              scale = 1.0;
            }
            {
              criteria = "$laptop";
              status = "enable";
              position = "740,2160";
            }
          ];
          # profile.exec = execThemeReset;
        }
      ];
    };
  };
}
