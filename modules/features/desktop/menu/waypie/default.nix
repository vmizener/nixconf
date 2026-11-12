/*
  feat/desktop/menu/waypie

Enables the Waypie radial menu tool for Wayland.

Exposes:

- flake.homeModules."feat/desktop/menu/waypie":
- local package: "nix run '.#pkg:waypie'"
*/
let
  moduleName = "feat/desktop/menu/waypie";

  pkgName = "waypie";
  version = "2.0.1";

  mkPkg = {
    fetchFromGitHub,
    gdk-pixbuf,
    gobject-introspection,
    gtk4,
    lib,
    librsvg,
    libxkbcommon,
    pkg-config,
    python3,
    rustPlatform,
    wayland,
    wrapGAppsHook4,
  }: let
    pythonEnv = python3.withPackages (ps:
      with ps; [
        pycairo
        pygobject3
      ]);
  in
    rustPlatform.buildRustPackage {
      pname = pkgName;
      inherit version;
      src = fetchFromGitHub {
        owner = "rywby-dot";
        repo = pkgName;
        tag = "v${version}";
        hash = "sha256-IQeDjJzdhV5UHAtKkyuEH6UVcnnr0m6wY/jEFSU1Sso=";
      };
      cargoHash = "sha256-e1LWrM9Dg0+8JP/sl8gIQ39NLLS8qpbHI7lQzOB0jJc=";

      # Resolve symlinks on save so `waypie-config` writes through `mod.meta.link`
      # into the flake repo instead of replacing the `~/.config/waypie/config` symlink.
      patches = [./resolve-config-symlink.patch];

      nativeBuildInputs = [
        gobject-introspection
        pkg-config
        wrapGAppsHook4
      ];
      dontWrapGApps = true;

      buildInputs = [
        gdk-pixbuf
        gtk4
        librsvg
        libxkbcommon
        wayland
      ];

      postInstall = ''
        mkdir -p "$out/libexec/waypie" "$out/share/waypie"
        cp -r config/. "$out/share/waypie/"
        install -m 0644 waypie_config.py waypie_common.py "$out/libexec/waypie/"
      '';

      postFixup = ''
        patchelf --add-rpath "${lib.makeLibraryPath [libxkbcommon wayland]}" "$out/bin/waypie"
        makeWrapper "${pythonEnv}/bin/python3" "$out/bin/waypie-config" \
          --add-flags "$out/libexec/waypie/waypie_config.py" \
          "''${gappsWrapperArgs[@]}"
      '';

      meta = {
        description = "Lightweight Kando-like radial menu for Wayland";
        homepage = "https://github.com/rywby-dot/waypie";
        license = lib.licenses.mit;
        mainProgram = pkgName;
        platforms = lib.platforms.linux;
      };
    };
in {
  flake.homeModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: let
    pkg = pkgs.callPackage mkPkg {};
  in {
    mod.meta.imported = [moduleName];
    home.packages = [pkg];
    xdg.configFile = {
      "waypie/config".source = config.mod.meta.link ./config.toml;
      "waypie/style.css".source = config.mod.meta.link ./style.css;
      "waypie/icons".source = "${pkg}/share/waypie/icons";
    };
    mod."common/handlers".add.menu.waypie = {
      priority = 100;
      label = "Waypie";
      cmd = ["waypie" "--show"];
    };
  };

  perSystem = {pkgs, ...}: {
    packages."pkg:${pkgName}" = pkgs.callPackage mkPkg {};
  };
}
