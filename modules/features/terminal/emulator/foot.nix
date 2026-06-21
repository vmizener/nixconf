/*
  feat/terminal/emulator/foot

Enables foot terminal emulator.

Exposes:

- flake.homeModules."feat/terminal/emulator/foot":
*/
{
  flake.homeModules."feat/terminal/emulator/foot" = {
    config,
    lib,
    pkgs,
    ...
  }: {
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      nerd-fonts.inconsolata
    ];
    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "HackNerdFont:size=12";
        };
        colors = {
          alpha = "0.7";
        };
        key-bindings = {
          font-increase = "Control+Shift+plus Control+Shift+equal Control+KP_Add";
          font-decrease = "Control+Shift+minus Control+KP_Subtract";
          pipe-scrollback = let
            hasNvim = lib.elem pkgs.neovim config.home.packages;
            editor =
              if hasNvim ? nvim
              then "nvim"
              else "vi";
          in [
            "[sh -c \"f=$(mktemp) && cat - > $f; foot ${editor} $f -u NONE -c 'set nonumber nolist showtabline=0 foldcolumn=0 virtualedit=block' -c 'autocmd VimEnter * normal G' -c 'map q :qa!<CR>' -c 'map i <NOP>' -c 'map I <NOP>' -c 'map a <NOP>' -c 'map A <NOP>' -c 'set clipboard+=unnamedplus'; rm $f\"] Control+Shift+f"
            "[sh -c \"cat - | foot fzf --no-sort --no-mouse -i --tac\"] Control+Shift+slash"
          ];
          show-urls-launch = "Control+Shift+o";
          show-urls-copy = "Control+Shift+y";
        };
      };
    };
  };
}
