/*
  feat/tools/git

Enables git VCS.

Note that git is also installed by feat/system/systools.
This feature also includes git configs.

Exposes:

- flake.homeModules."feat/tools/git":
*/
let
  moduleName = "feat/tools/git";
in {
  flake.homeModules.${moduleName} = {
    config,
    pkgs,
    ...
  }: {
    mod.imported = [moduleName];
    home.packages = with pkgs; [delta];
    programs.git = {
      enable = true;
      settings = {
        alias = {
          # `git changes FILE`
          # -- Show the change history for FILE
          changes = "log -p -M --follow --stat --";
          # `git squash N`
          # -- Squash the last N commits together into one commit (default: N=2)
          squash = "!f(){ git reset --soft HEAD~\${1:-2} && git commit --edit -m\"$(git log --format=%B --reverse HEAD..HEAD@{1})\"; };f";
          # `git tree`
          # -- Show the commit tree for the current branch
          tree = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
          # `git tree-detail`
          # -- Show a detailed commit tree for the current branch
          tree-detail = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all";
        };
        branch.autosetuprebase = "always";
        color = {
          branch = "auto";
          diff = "auto";
          status = "auto";
          ui = "always";
        };
        core = {
          excludesfile = "${config.xdg.configHome}/git/gitignore";
          pager = "delta -sn";
          fsmonitor = false;
          untrackedCache = true;
        };
        credential.helper = "store";
        mergetool.prompt = false;
        pull.rebase = true;
        push.default = "current";
        stash.showPatch = true;
      };
    };
    xdg.configFile."git/gitignore".text = ''
      # Git ignore file
      # Lines that start with '#' are comments
      # Assign project local ignore patterns in .git/info/exlude
      .direnv
      .pre-commit-config.yaml
      *.pyc
      *.swp
      result*
    '';
  };
}
