/*
  feat/tools/git

Enables git VCS.

Note that git is also installed by feat/systools.
This feature also includes git configs.

Exposes:

- flake.homeModules."feat/tools/git":
*/
{
  flake.homeModules."feat/tools/git" = {...}: {
    features.tools = ["git"];
    programs.git = {
      enable = true;
      settings = {
        alias = {
          changes = "log -p -M --follow --stat --";
        };
        branch.autosetuprebase = "always";
        color = {
          branch = "auto";
          diff = "auto";
          status = "auto";
          ui = "always";
        };
        core = {
          excludesfile = "~/.gitignore";
          pager = "delta -sn";
          fsmonitor = true;
          untrackedCache = true;
        };
        credential.helper = "store";
        mergetool.prompt = false;
        pull.rebase = true;
        push.default = "current";
        stash.showPatch = true;
      };
    };
  };
}
