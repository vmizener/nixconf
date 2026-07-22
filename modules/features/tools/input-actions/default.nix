/*
  feat/tools/input-actions

Enables the Input Actions utility for binding keyboard,
mouse, touchpad, and touchscreen actions to system actions.

Note that the homeModule depends on the nixosModule.

Exposes:

- flake.nixosModules."feat/tools/input-actions":
- flake.homeModules."feat/tools/input-actions":
*/
{inputs, ...}: {
  flake.nixosModules."feat/tools/input-actions" = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
    inputactions-ctl = inputs.inputactions-ctl.packages.${system}.default;
    inputactions-standalone = inputs.inputactions-standalone.packages.${system}.default;
  in {
    environment.systemPackages = [
      inputactions-ctl
      inputactions-standalone
    ];

    systemd.services = {
      inputactionsd = {
        description = "inputactionsd gesture daemon (root)";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          ExecStart = "${inputactions-standalone}/bin/inputactionsd";
          Restart = "on-failure";
        };
      };
    };
  };
  flake.homeModules."feat/tools/input-actions" = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
    inputactions-standalone = inputs.inputactions-standalone.packages.${system}.default;
  in {
    systemd.user.services = {
      inputactions-client = {
        Install = {
          WantedBy = ["graphical-session.target"];
        };
        Unit = {
          Description = "inputactions-client autostart";
          After = ["inputactionsd.service"];
          PartOf = ["graphical-session.target"];
        };
        Service = {
          ExecStart = "${inputactions-standalone}/bin/inputactions-client";
          Restart = "on-failure";
        };
      };
    };
  };
}
