pkgs: {
  # Everyday CLI/TUI utilities useful in any shell environment
  core = with pkgs; [
    bat # Modern `cat` command
    bc # Simple calculator
    delta # Modern `diff` command
    eza # Modern `ls` command
    fd # Modern `find` command
    findutils # Basic GNU directory search utilities
    fzf # Fuzzy finder and menu selection tool
    git # Popular VCS
    gnumake # Binary compiler
    jq # JSON parser
    just # Modern Makefile alternative
    manix # Fast CLI documentation searcher for Nix
    mlocate # Utility to index and quickly search for files
    nh # Nix CLI wrapper
    ripgrep # Modern `grep` command
    tmux # Terminal multiplexer
    tree # Simple tree-based directory visualizer
    unzip # Extraction utility for .zip files
    vim # Vi Improved
    wget # Simple HTTP/HTTPS/FTP retrieval tool
    yazi # Terminal file manager
    zip # Archiver utility for .zip files
  ];

  # System monitoring, process management, and hardware inspection
  sysadmin = with pkgs; [
    btop # TUI-based system monitor
    fastfetch # System information tool
    killall # Kill process and all its children at once
    pstree # Show processes as a tree
    smartmontools # Tools for monitoring disk health
    usbutils # Tools for working with USB devices (e.g. `lsusb`)
  ];

  # GUI apps, X11/Wayland utilities, and graphical/media viewers
  desktop = with pkgs; [
    blobdrop # Drag-and-drop files from terminal
    dex # Generates and executes DesktopEntry files for MIME applications
    gparted # Graphical disk partitioning tool
    hardinfo2 # System info and benchmarking tool
    imagemagick # Image editing library
    libnotify # Library for desktop notifications
    libsixel # SIXEL library for console graphics
    lsix # Thumbnail support in terminal via SIXEL graphics
    pavucontrol # PulseAudio volume control
    st # Simple Terminal for X
    tdf # TUI-based PDF viewer
    timg # Display images in terminal
    wev # Wayland event viewer
  ];
}
