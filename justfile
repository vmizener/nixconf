format:
    nix fmt -- $(fd '^[^.]*\.nix$' .)

check: format
    nix flake check --quiet --show-trace

vm-run hostname *args="":
    nix run ".#vm-run-{{hostname}}" -- {{args}}

vm-reset hostname:
    nix run ".#vm-reset-{{hostname}}"

vm-fresh hostname *args="": (vm-reset hostname) (vm-run hostname args)
