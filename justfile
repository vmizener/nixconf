dev shell="zsh":
    nix develop -c {{shell}}

format:
    nix fmt -- $(fd '^[^.]*\.nix$' .)

check: format
    nix flake check --quiet --show-trace

show:
    ./scripts/show-flake.sh | jq

update-packages:
    ./scripts/update-packages.sh

vm-run hostname *args="":
    nix run ".#vm-run-{{hostname}}" -- {{args}}

vm-reset hostname:
    nix run ".#vm-reset-{{hostname}}"

vm-fresh hostname *args="": (vm-reset hostname) (vm-run hostname args)
