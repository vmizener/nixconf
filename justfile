# List recipes
default:
    just --list

# Open nix dev shell
dev shell="zsh":
    nix develop -c {{shell}}

# Run nix formatter
format:
    nix fmt -- $(fd '^[^.]*\.nix$' .)

# Format & run nix checks
check: format
    nix flake check --quiet --show-trace

# Show flake outputs
show:
    ./scripts/show-flake.sh | jq

# Update non-flake input packages
update-packages:
    ./scripts/update-packages.sh

# Add sops entry for current host/user
[group('sops')]
sops-init:
    ./scripts/sops-init.sh

# Update sops encryption
[group('sops')]
sops-update:
    ./scripts/sops-update.sh

# Launch VM for given host (see `just show` for host options)
[group('vm')]
vm-run hostname *args="":
    nix run ".#vm-run-{{hostname}}" -- {{args}}

# Reset VM of given host
[group('vm')]
vm-reset hostname:
    nix run ".#vm-reset-{{hostname}}"

# Reset then launch VM of given host
[group('vm')]
vm-fresh hostname *args="": (vm-reset hostname) (vm-run hostname args)
