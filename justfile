dev shell="zsh":
    nix develop -c {{shell}}

format:
    nix fmt -- $(fd '^[^.]*\.nix$' .)

check: format
    nix flake check --quiet --show-trace

update-packages:
    #!/usr/bin/env bash
    # Assumes updatable packages have names with prefix "pkg:"
    for pkg in $(nix flake show --json 2>/dev/null | jq -r '.packages | [ .[] | keys[] ] | unique | map(select(startswith("pkg:")))[]'); do
      echo "Updating $pkg..."
      nix run github:Mic92/nix-update -- -F "$pkg" || true
    done

vm-run hostname *args="":
    nix run ".#vm-run-{{hostname}}" -- {{args}}

vm-reset hostname:
    nix run ".#vm-reset-{{hostname}}"

vm-fresh hostname *args="": (vm-reset hostname) (vm-run hostname args)
