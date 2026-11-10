# Declarative MIME category definitions for `common/mime`.
{
  browser = {
    description = "web browsers";
    mimes = [
      "application/xhtml+xml"
      "text/html"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/about"
      "x-scheme-handler/unknown"
    ];
  };
  editor = {
    description = "text editors";
    mimes = [
      "text/plain"
      "text/markdown"
      "text/x-shellscript"
    ];
  };
  fileManager = {
    description = "file managers";
    mimes = [
      "inode/directory"
      "x-scheme-handler/file"
    ];
  };
  imageViewer = {
    description = "image viewers";
    mimes = [
      "image/jpeg"
      "image/gif"
      "image/png"
      "image/svg+xml"
      "image/webp"
    ];
  };
  pdfViewer = {
    description = "PDF viewers";
    mimes = [
      "application/pdf"
    ];
  };
  terminal = {
    description = "terminal emulators";
    mimes = [
      "x-scheme-handler/terminal"
    ];
  };
  launcher = {
    description = "application launchers";
    mimes = [
      "x-scheme-handler/launcher"
    ];
  };
  audioPlayer = {
    description = "audio media players";
    mimes = [
      "audio/flac"
      "audio/mpeg"
      "audio/wav"
    ];
  };
  videoPlayer = {
    description = "video media players";
    mimes = [
      "video/mp4"
      "video/quicktime"
      "video/webm"
      "video/x-matroska"
    ];
  };
}
