pkgs: {
  # KDE Breeze GTK, Qt, icon, and cursor themes
  breeze = with pkgs; [
    kdePackages.breeze
    kdePackages.breeze-gtk
    kdePackages.breeze-icons
    kdePackages.breeze.qt5
  ];
}
