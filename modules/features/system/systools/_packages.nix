pkgs: {
  # Lightweight CLI/TUI utilities useful in any shell environment
  core = with pkgs; [
    bat # Modern `cat` command
    bc # Simple calculator
    delta # Modern `diff` command
    eza # Modern `ls` command
    fd # Modern `find` command
    findutils # Basic GNU directory search utilities
    fzf # Fuzzy finder and menu selection tool
    gnumake # Binary compiler
    manix # Fast CLI documentation searcher for Nix
    ov # Modern terminal pager
    ripgrep # Modern `grep` command
    tmux # Terminal multiplexer
    tree # Simple tree-based directory visualizer
    unzip # Extraction utility for .zip files
    vim # Vi Improved
    zip # Archiver utility for .zip files
  ];

  # System monitoring, process management, network, and hardware inspection
  sysadmin = with pkgs; [
    btop # TUI-based system monitor
    curlie # Frontend wrapper to `curl`
    dig # DNS query
    doggo # `dig` alternative in go
    duf # `df` alternative in go
    dust # `du` alternative in rust
    fastfetch # System information tool
    killall # Kill process and all its children at once
    mlocate # Utility to index and quickly search for files
    pstree # Show processes as a tree
    smartmontools # Tools for monitoring disk health
    usbutils # Tools for working with USB devices (e.g. `lsusb`)
  ];

  # Terminal media/document viewers, converters, and file previewers
  media = with pkgs; [
    imagemagick # CLI image manipulation and conversion tools
    libsixel # SIXEL console graphics utilities (`img2sixel`, `sixel2png`)
    lsix # Thumbnail support in terminal via SIXEL graphics
    tdf # TUI-based PDF viewer
    timg # Display images in terminal
    yazi # Terminal file manager
  ];

  # GUI apps and X11/Wayland/XDG desktop session utilities
  desktop = with pkgs; [
    blobdrop # Drag-and-drop files from terminal
    dex # Generates and executes DesktopEntry files for MIME applications
    gparted # Graphical disk partitioning tool
    hardinfo2 # System info and benchmarking tool
    libnotify # Desktop notification CLI (`notify-send`) and library
    pavucontrol # PulseAudio volume control
    st # Simple Terminal for X
    wev # Wayland event viewer
  ];
}
