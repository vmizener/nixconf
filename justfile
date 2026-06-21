format:
    nix fmt -- $(find . -type f -name '*.nix')

vm-run hostname *args="":
    nix run .#vm-run-{{hostname}} -- {{args}}

vm-reset hostname:
    nix run .#vm-reset-{{hostname}}

vm-fresh hostname *args="": (vm-reset hostname)
    nix run .#vm-run-{{hostname}} -- {{args}}
