/*
  feat/earlyoom

Enables earlyoom, for automatic memory management.

Exposes:

- flake.nixosModules."feat/earlyoom":
*/
{
  flake.nixosModules."feat/earlyoom" = {lib, ...}: {
    services.earlyoom = {
      enable = true;

      freeMemThreshold = 10; # Start monitoring when free memory is below 10%
      freeMemKillThreshold = 5; # Kill processes when free memory is below 5%

      # Enable desktop notifications
      # Should only use on machines where all users are trusted
      enableNotifications = true;

      extraArgs = let
        plist = l: "^(" + (lib.strings.concatStringsSep "|" l) + ")$";
      in [
        "--prefer"
        (plist [
          ".zen-wrapped"
          "Web Content"
        ])
        "--avoid"
        (plist [
          "systemd" # Avoid killing systemd processes
        ])
      ];
    };
  };
}
