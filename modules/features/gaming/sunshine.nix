/*
  feat/gaming/sunshine

Sunshine is a remote streaming client.

Exposes:

- flake.nixosModules."feat/gaming/sunshine":
*/
{
  flake.nixosModules."feat/gaming/sunshine" = {
    services = {
      sunshine = {
        enable = true;
        autoStart = true;  # optional: starts Sunshine automatically on login
        capSysAdmin = true;
        openFirewall = true;
      };
      udev.extraRules = ''
        KERNEL=="uinput", MODE="0660", GROUP="input", SYMLINK+="uinput"
      '';
    };
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 47984 47989 47990 48010 ];
      allowedUDPPortRanges = [
        { from = 47998; to = 48000; }
        { from = 8000; to = 8010; }
      ];
    };
  };
}

