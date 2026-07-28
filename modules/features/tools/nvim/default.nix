/*
  feat/tools/nvim

Provides Neovim.

Exposes:

- flake.homeModules."feat/tools/nvim":
  - Enables Neovim
*/
{
  flake.homeModules."feat/tools/nvim" = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfgPath = config.flakePath + "/modules/features/tools/nvim/config";
    tsParsers = pkgs.symlinkJoin {
      name = "treesitter-parsers";
      paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
    };
  in {
    features.tools = ["nvim"];
    programs.neovim = {
      enable = true;
      sideloadInitLua = true;
      extraPackages = with pkgs; [
        tree-sitter

        black
        fd
        go
        lua-language-server
        nixd
        nixfmt
        pyright
        ripgrep
        stylua
      ];
      extraWrapperArgs = [
        # uses autocmd rather than direct addition to avoid Lazy removing it on init
        "--add-flags"
        "--cmd 'autocmd VimEnter * lua vim.opt.runtimepath:append(\"${tsParsers}\")'"
      ];
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
    };
    xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink cfgPath;

    # Ensure the symlink target remains alive for GC
    home.activation.nvimConfigGcRoot = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Root name is stable; if `cfgPath` changes across updates, this updates its target
      nix-store --add-root home-manager-nvim-config -r ${lib.escapeShellArg cfgPath}
    '';

    # Mark neovim as preferred editor
    features.system.mime.categories.editors = lib.mkIf config.features.system.mime.enable (lib.mkOrder 100 ["nvim.desktop"]);
    home.sessionVariables.EDITOR = lib.mkOverride 100 "nvim";
  };
}
