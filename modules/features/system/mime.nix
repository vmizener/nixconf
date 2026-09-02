/*
  feat/system/mime

Sets up MIME-type support and default XDG applications.

Exposes:

- flake.homeModules."feat/system/mime":
*/
{
  flake.homeModules."common/options" = {lib, ...}: {
    options.features.system.mime = {
      enable = lib.mkEnableOption "XDG MIME types and default application lists";
      # Add entries for general MIME type categories.
      # Use `lib.mkOrder N` to specify priority when assigning options.
      categories = let
        mkCategory = name:
          lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "List of desktop entries for ${name} in priority order.";
          };
      in {
        browsers = mkCategory "web browsers";
        editors = mkCategory "text editors";
        fileManagers = mkCategory "file managers";
        imageViewers = mkCategory "image viewers";
        pdfViewers = mkCategory "PDF viewers";
        terminals = mkCategory "terminal emulators";
        audioPlayers = mkCategory "audio media players";
        videoPlayers = mkCategory "video media players";
      };
      # Add entries for general MIME type categories by mapping desktop entries to priority numbers.
      # Lower numbers take precedence (e.g. 100 comes before 150).
      add = let
        mkAdd = name:
          lib.mkOption {
            type = lib.types.attrsOf (lib.types.either lib.types.int (lib.types.enum [true]));
            default = {};
            description = "Map of desktop entries to priority for ${name}.";
            example = lib.literalExpression ''
              {
                "helium.desktop" = 100;
              }
            '';
          };
      in {
        browser = mkAdd "web browsers";
        editor = mkAdd "text editors";
        fileManager = mkAdd "file managers";
        imageViewer = mkAdd "image viewers";
        pdfViewer = mkAdd "PDF viewers";
        terminal = mkAdd "terminal emulators";
        audioPlayer = mkAdd "audio media players";
        videoPlayer = mkAdd "video media players";
      };
      # Add entries associated with specific MIME types.
      # Note that these entries will appear as options (e.g. in "Open With" menus), but never be selected for automatic execution (as with the defaultApplications list).
      associations = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {};
        description = "Additional associations to map to specific MIME types.";
        example = lib.literalExpression ''
          {
            "x-scheme-handler/mailto" = [ "thunderbird.desktop" ];
          }
        '';
      };
    };
  };
  flake.homeModules."feat/system/mime" = {
    config,
    lib,
    pkgs,
    ...
  }: {
    features.system.mime.enable = true;
    home.packages = with pkgs; [
      handlr-regex # https://github.com/Anomalocaridid/handlr-regex
      xdg-utils
    ];
    xdg = {
      mime.enable = true;
      mimeApps = let
        cfg = config.features.system.mime;

        resolveCategory = addMap: explicitList: let
          pairs =
            lib.mapAttrsToList (name: val: {
              inherit name;
              priority =
                if val == true
                then 100
                else val;
            })
            addMap;
          sorted =
            builtins.sort (
              a: b: a.priority < b.priority || (a.priority == b.priority && a.name < b.name)
            )
            pairs;
          sortedNames = map (p: p.name) sorted;
        in
          lib.unique (sortedNames ++ explicitList);

        getCategory = singular: plural:
          resolveCategory cfg.add.${singular} cfg.categories.${plural};

        setCategory = category: mimes:
          if category == []
          then {} # Don't override if option is empty (the default)
          else lib.genAttrs mimes (_: category);
      in {
        enable = true;
        defaultApplications = lib.attrsets.zipAttrsWith (_: values: lib.lists.flatten values) [
          (setCategory
            (getCategory "browser" "browsers")
            [
              "application/xhtml+xml"
              "text/html"
              "x-scheme-handler/http"
              "x-scheme-handler/https"
              "x-scheme-handler/about"
              "x-scheme-handler/unknown"
            ])
          (setCategory
            (getCategory "editor" "editors")
            [
              "text/plain"
              "text/markdown"
              "text/x-shellscript"
            ])
          (setCategory
            (getCategory "fileManager" "fileManagers")
            [
              "inode/directory"
              "x-scheme-handler/file"
            ])
          (setCategory
            (getCategory "imageViewer" "imageViewers")
            [
              "image/jpeg"
              "image/gif"
              "image/png"
              "image/svg+xml"
              "image/webp"
            ])
          (setCategory
            (getCategory "pdfViewer" "pdfViewers")
            [
              "application/pdf"
            ])
          (setCategory
            (getCategory "terminal" "terminals")
            [
              "x-scheme-handler/terminal"
            ])
          (setCategory
            (getCategory "audioPlayer" "audioPlayers")
            [
              "audio/flac"
              "audio/mpeg"
              "audio/wav"
            ])
          (setCategory
            (getCategory "videoPlayer" "videoPlayers")
            [
              "video/mp4"
              "video/quicktime"
              "video/webm"
              "video/x-matroska"
            ])
        ];
        associations.added = cfg.associations;
      };
    };
  };
}
