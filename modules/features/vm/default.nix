/*
  feat/vm

Provides QEMU virtual machine runner generation for NixOS and standalone
Home-Manager configurations.

Exposes:

- flake.nixosModules."feat/vm":
  - Enables NixOS virtualization features and VM variant overrides.

- flake.homeModules."feat/vm":
  - Enables standalone Home-Manager non-NixOS guest VM configuration.

- perSystem.packages:
  - Generates `vm-run-<hostname>` package (to run the <hostname> VM).
  - Generates `vm-reset-<hostname>` package (to reset the <hostname> VM).
*/
{
  inputs,
  lib,
  self,
  ...
}: let
  moduleName = "feat/vm";
  defaultHmImages = lib.importTOML ./images.toml;

  sharedVmOptions = {
    storageDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/nix-vm";
      description = "Directory to store VM disk images";
    };
    memorySize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4096;
      description = "Memory size in MiB allocated to the VM";
    };
    diskSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20480;
      description = "Virtual disk size in MiB allocated to the VM";
    };
    cores = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Number of CPU cores allocated to the VM";
    };
    graphics = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable graphical SDL display for the VM";
    };
    gl = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OpenGL/VirGL acceleration for the graphical display";
    };
    resolution = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          width = lib.mkOption {
            type = lib.types.ints.positive;
            description = "Horizontal resolution in pixels";
          };
          height = lib.mkOption {
            type = lib.types.ints.positive;
            description = "Vertical resolution in pixels";
          };
        };
      });
      default = {
        width = 640;
        height = 480;
      };
      example = {
        width = 1280;
        height = 720;
      };
      description = "Initial display resolution for graphical VMs";
    };
  };
in {
  flake.nixosModules."common/options" = {...}: {
    options.mod.${moduleName} =
      sharedVmOptions
      // {
        isVm = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Config describes VM";
        };
        autologinUser = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "bao";
          description = "User to automatically log in on TTYs inside the VM";
        };
      };
  };

  flake.homeModules."common/options" = {
    osConfig ? null,
    pkgs,
    ...
  }: let
    platformSystem = pkgs.stdenv.hostPlatform.system;
  in {
    options.mod.${moduleName} =
      sharedVmOptions
      // {
        isVm = lib.mkOption {
          type = lib.types.bool;
          default = osConfig != null && ((osConfig.mod.${moduleName} or {}).isVm or false);
          description = "Config describes VM";
        };
        hostName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "VM hostname override (defaults to the <host> suffix of <user>@<host>)";
        };
        autologin = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Automatically log in the Home-Manager user on VM consoles";
        };
        guestPackages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Extra guest distro packages installed on first boot";
        };
        image = lib.mkOption {
          type = lib.types.either lib.types.path (lib.types.submodule {
            options = {
              url = lib.mkOption {
                type = lib.types.str;
                description = "URL of a cloud-init-enabled qcow2 guest image";
              };
              hash = lib.mkOption {
                type = lib.types.str;
                description = "SRI hash of the qcow2 guest image";
              };
            };
          });
          default =
            defaultHmImages.${platformSystem}
            or (throw "${moduleName}: no default standalone VM image for '${platformSystem}'; set mod.\"${moduleName}\".image explicitly");
          description = "Base cloud-init qcow2 image (path or {url, hash}) for standalone Home-Manager VMs";
        };
      };
  };

  flake.homeModules.${moduleName} = {
    config,
    lib,
    options,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    config = lib.mkMerge [
      {
        mod.meta = {
          imported = [moduleName];
          asserts = ["standaloneOnly"];
        };
      }
      (lib.mkIf cfg.isVm (
        {
          # Mesa's virgl disk cache hashes uninitialized padding in `union virgl_caps`,
          # missing on every boot and leaving stale/corrupted cache state across restarts.
          home.sessionVariables.MESA_SHADER_CACHE_DISABLE = lib.mkIf (cfg.graphics && cfg.gl) (lib.mkDefault "true");
          systemd.user.sessionVariables.MESA_SHADER_CACHE_DISABLE = lib.mkIf (cfg.graphics && cfg.gl) (lib.mkDefault "true");
        }
        // lib.optionalAttrs (options ? sops) {
          sops.validateSopsFiles = lib.mkDefault false;
        }
      ))
    ];
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    options,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    config = lib.mkMerge [
      {
        mod.meta.imported = [moduleName];
        virtualisation.vmVariant =
          {
            mod = {
              meta.flakePath = lib.mkVMOverride "${self}"; # mount flake store source for symlink support
              ${moduleName}.isVm = lib.mkVMOverride true;
            };
            hardware.graphics.enable = lib.mkIf cfg.graphics (lib.mkDefault true);
            services.qemuGuest.enable = true;
            services.getty.autologinUser = lib.mkIf (cfg.autologinUser != null) cfg.autologinUser;
            users.users =
              config.users.users
              |> lib.filterAttrs (_: u: u.isNormalUser)
              |> lib.mapAttrs (_: _: {
                hashedPasswordFile = lib.mkVMOverride null;
                initialPassword = lib.mkVMOverride "vm";
              });
            virtualisation = let
              vgaDevice =
                if cfg.gl
                then "virtio-vga-gl"
                else "virtio-vga";
              resOpts =
                lib.optionalString (cfg.resolution != null)
                ",edid=on,xres=${toString cfg.resolution.width},yres=${toString cfg.resolution.height}";
              sdlOpts =
                if cfg.gl
                then "sdl,gl=on"
                else "sdl";
            in {
              inherit (cfg) memorySize diskSize cores graphics;
              qemu.options = lib.optionals cfg.graphics [
                "-vga none"
                "-device ${vgaDevice}${resOpts}"
                "-display ${sdlOpts}"
              ];
            };
          }
          // lib.optionalAttrs (options ? sops) {
            sops = {
              validateSopsFiles = lib.mkVMOverride false;
              secrets =
                config.sops.secrets
                |> lib.mapAttrs (_: _: {
                  neededForUsers = lib.mkVMOverride false;
                });
            };
          };
      }
      (lib.mkIf cfg.isVm (
        {
          boot.loader.grub.enable = lib.mkDefault false;
          fileSystems."/" = {
            device = lib.mkDefault "/dev/vda";
            fsType = lib.mkDefault "ext4";
          };
          # Mesa's virgl disk cache hashes uninitialized padding in `union virgl_caps`,
          # missing on every boot and leaving stale/corrupted cache state across restarts.
          environment.sessionVariables.MESA_SHADER_CACHE_DISABLE = lib.mkIf (cfg.graphics && cfg.gl) (lib.mkDefault "true");
          systemd.globalEnvironment.MESA_SHADER_CACHE_DISABLE = lib.mkIf (cfg.graphics && cfg.gl) (lib.mkDefault "true");
        }
        // lib.optionalAttrs (options ? sops) {
          sops.validateSopsFiles = lib.mkDefault false;
        }
      ))
    ];
  };

  perSystem = {
    lib,
    pkgs,
    system,
    ...
  }: {
    packages = import ./_packages.nix {
      inherit inputs lib moduleName pkgs self system;
    };
  };
}
