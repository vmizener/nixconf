flake_dir := justfile_directory()

# List recipes
default:
    just --list

# Show flake outputs
show *args="":
    ./scripts/show-flake.sh {{args}} | jq

# Bootstrap or migrate nix-user-chroot Home-Manager environment
chroot-init *args="":
    FLAKE_DIR="{{flake_dir}}" ./scripts/chroot-init.sh {{args}}

# Open nix dev shell
[group('dev')]
dev shell="zsh":
    nix develop -c env SHELL="$(which {{shell}})" {{shell}}

# Format repo files
[group('dev')]
format:
    nix fmt

# Format & run nix checks
[group('dev')]
check: format
    nix flake check --quiet --show-trace

# Update non-flake input packages
[group('dev')]
update-packages:
    ./scripts/update-packages.sh

# Update assets manifest
[group('dev')]
update-manifest *args="":
    ./scripts/update-assets-manifest.py {{args}}

# Launch VM for given host (see `just show` for host options)
[group('vm')]
vm-run hostname *args="":
    nix run "{{flake_dir}}#vm:run-{{hostname}}" -- {{args}}

# Reset VM of given host
[group('vm')]
vm-reset hostname:
    nix run "{{flake_dir}}#vm:reset-{{hostname}}"

# Reset then launch VM of given host
[group('vm')]
vm-fresh hostname *args="": (vm-reset hostname) (vm-run hostname args)
