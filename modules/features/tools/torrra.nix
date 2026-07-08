/*
  feat/tools/torrra

Torrent search tool for CLI.

Exposes:

- flake.homeModules."feat/tools/torrra":
*/
{inputs, ...}: {
  flake.homeModules."feat/tools/torrra" = {
    config,
    lib,
    pkgs,
    ...
  }: {
    features.tools = ["torrra"];
    home.packages = [inputs.torrra.packages.${pkgs.stdenv.hostPlatform.system}.default];

    # Copy a writable config
    home.activation."torrra-config" = let
      toml = pkgs.formats.toml {};
      cfgFile = config.lib.file.mkOutOfStoreSymlink (toml.generate "config.toml" {
        general = {
          download_path = "${config.home.homeDirectory}/Downloads/Torrents";
          theme = "textual-dark";
          use_cache = true;
        };
        indexers = {
          default = "jackett";
          jackett = {
            # Get this info from jackett
            url = "http://localhost:9117";
            api_key = "o0nqlfxefdqni64o3lgv5dx47fmarnzr";
          };
        };
      });
      target = "${config.xdg.configHome}/torrra/config.toml";
    in lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$(dirname "${target}")"
      cp -f "${cfgFile}" "${target}"
      chmod +w "${target}"
    '';
  };
}
