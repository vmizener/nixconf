#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p age sops ssh-to-age "python3.withPackages (ps: [ ps.ruamel-yaml ])"
"""CLI for enrolling local or remote age keys in `.sops.yaml` and re-keying secrets."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from io import StringIO
import os
from pathlib import Path
import subprocess
import sys
from typing import Any

from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import PlainScalarString, ScalarString

SSH_HOST_PUB_PATH = "/etc/ssh/ssh_host_ed25519_key.pub"
PROBE_MARKER = "---SOPS-PROBE---"
TARGET_HELPER = Path(__file__).resolve().parent / "_sops-target.sh"


def prompt_yes_no(question: str, default: bool = False) -> bool:
    """Prompt the user with a yes/no question and return the chosen boolean."""
    suffix = "[Y/n]" if default else "[y/N]"
    reply = input(f"{question} {suffix} ").strip().lower()
    if not reply:
        return default
    return reply in {"y", "yes"}


@dataclass
class TargetInfo:
    """Identity and public-key state discovered on a local or remote target.

    Attributes:
        user: Account username resolved on the target.
        hostname: Unqualified (short) hostname of the target.
        user_keys_path: Path to the user's age `keys.txt` on the target.
        has_user_key: Whether `user_keys_path` already exists on disk.
        user_pub_key: Extracted `age1...` public key if `has_user_key` and requested.
        ssh_host_pub_key: Contents of `/etc/ssh/ssh_host_ed25519_key.pub` if present.
    """

    user: str
    hostname: str
    user_keys_path: str
    has_user_key: bool
    user_pub_key: str | None
    ssh_host_pub_key: str | None


class SopsTarget:
    """Inspects and manages sops age keys locally or on a remote SSH host."""

    def __init__(
        self,
        ssh_target: str | None = None,
        helper_script: Path = TARGET_HELPER,
    ) -> None:
        """Initialize a target runner for the local host or an SSH destination."""
        self.ssh_target = ssh_target
        self.helper_script = helper_script

    @staticmethod
    def _build_remote_payload(script_text: str, stdin_data: str | None = None) -> str:
        """Build stdin payload for `sh -s`, redirecting `stdin_data` via heredoc if set."""
        if stdin_data is None:
            return script_text
        script_nl = "" if script_text.endswith("\n") else "\n"
        data_nl = "" if stdin_data.endswith("\n") else "\n"
        return (
            f"{{\n{script_text}{script_nl}}} <<'__SOPS_STDIN_EOF__'\n"
            f"{stdin_data}{data_nl}"
            f"__SOPS_STDIN_EOF__\n"
        )

    @staticmethod
    def _parse_marked_kv(output: str) -> dict[str, str]:
        """Parse `KEY=VALUE` lines emitted after `PROBE_MARKER`, ignoring prior noise."""
        if PROBE_MARKER in output:
            output = output.split(PROBE_MARKER, 1)[1]
        result: dict[str, str] = {}
        for line in output.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                result[k.strip()] = v.strip()
        return result

    @staticmethod
    def _age_public_from_stdin(key_material: str) -> str:
        """Derive an `age1...` public key locally from secret key material."""
        return subprocess.run(
            ["age-keygen", "-y", "/dev/stdin"],
            input=key_material,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

    def _run(self, subcommand: str, *args: str, stdin_data: str | None = None) -> str:
        """Execute `_sops-target.sh` locally or streamed over `ssh <target> sh -s`."""
        if self.ssh_target is None:
            res = subprocess.run(
                ["sh", str(self.helper_script), subcommand, *args],
                input=stdin_data,
                text=True,
                check=True,
                stdout=subprocess.PIPE,
            )
            return res.stdout

        payload = self._build_remote_payload(
            self.helper_script.read_text(encoding="utf-8"),
            stdin_data=stdin_data,
        )
        res = subprocess.run(
            ["ssh", self.ssh_target, "sh", "-s", "--", subcommand, *args],
            input=payload,
            text=True,
            check=True,
            stdout=subprocess.PIPE,
        )
        return res.stdout

    def probe(self, include_user_key: bool = True) -> TargetInfo:
        """Query user/host identity, existing user age key, and SSH host public key."""
        if self.ssh_target:
            print(f"Inspecting remote target '{self.ssh_target}'...")
        out = self._run("probe", "1" if include_user_key else "0")
        fields = self._parse_marked_kv(out)

        has_user_key = fields.get("HAS_USER_KEY") == "1"
        user_pub = fields.get("USER_PUB") or None

        # Fallback if remote has keys.txt but neither age-keygen nor nix-shell installed
        if has_user_key and include_user_key and not user_pub:
            secret = self._run("read-key")
            user_pub = self._age_public_from_stdin(secret)

        return TargetInfo(
            user=fields["USER"],
            hostname=fields["HOST"],
            user_keys_path=fields["KEYS_FILE"],
            has_user_key=has_user_key,
            user_pub_key=user_pub,
            ssh_host_pub_key=fields.get("HOST_SSH_PUB") or None,
        )

    def ensure_user_key(self, info: TargetInfo) -> str:
        """Ensure the user's age `keys.txt` exists on the target and return its public key."""
        if info.user_pub_key:
            return info.user_pub_key

        out = self._run("create-key")
        fields = self._parse_marked_kv(out)
        location = (
            f"{self.ssh_target}:{info.user_keys_path}"
            if self.ssh_target
            else info.user_keys_path
        )
        if fields.get("USER_PUB"):
            if not info.has_user_key:
                print(f"Created new user key pair at {location}")
            return fields["USER_PUB"]

        # Fallback when remote lacks both age-keygen and nix-shell: generate locally
        keypair = subprocess.run(
            ["age-keygen"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        self._run("write-key", stdin_data=keypair)
        print(f"Created new user key pair at {location}")
        return self._age_public_from_stdin(keypair)


class SopsConfig:
    """Round-trip reader and writer for `.sops.yaml` anchors and creation rules."""

    def __init__(self, doc: Any, yaml: YAML, path: Path | None = None) -> None:
        """Wrap a parsed `ruamel.yaml` document and track in-memory modifications."""
        self.doc = doc
        self._yaml = yaml
        self.path = path
        self.changed = False

    @staticmethod
    def _make_yaml() -> YAML:
        """Configure a round-trip `YAML` instance matching `.sops.yaml` indentation."""
        yaml = YAML(typ="rt")
        yaml.preserve_quotes = True
        yaml.indent(mapping=2, sequence=4, offset=2)
        yaml.width = 4096
        return yaml

    @classmethod
    def from_file(cls, path: Path) -> SopsConfig:
        """Load a `.sops.yaml` document from `path`."""
        if not path.is_file():
            raise FileNotFoundError(f"Failed to find {path}")
        yaml = cls._make_yaml()
        with open(path, "r", encoding="utf-8") as f:
            doc = yaml.load(f)
        return cls(doc=doc, yaml=yaml, path=path)

    @classmethod
    def from_text(cls, text: str, path: Path | None = None) -> SopsConfig:
        """Parse a `.sops.yaml` document from a YAML string."""
        yaml = cls._make_yaml()
        doc = yaml.load(StringIO(text))
        return cls(doc=doc, yaml=yaml, path=path)

    @staticmethod
    def _get_anchor(node: Any) -> str | None:
        """Return the YAML anchor name attached to `node`, or `None` if unanchored."""
        if isinstance(node, ScalarString):
            anc = node.yaml_anchor(any=True)
            if anc is not None and anc.value:
                return str(anc.value)
        return None

    @staticmethod
    def _make_anchored_scalar(anchor: str, value: str) -> PlainScalarString:
        """Create an unquoted YAML scalar with `&anchor` preserved even when unaliased."""
        node = PlainScalarString(value)
        node.yaml_set_anchor(anchor, always_dump=True)
        return node

    def upsert_key(self, anchor: str, pub_key: str) -> PlainScalarString:
        """Insert or update `&anchor pub_key` in `keys`, rebinding `*anchor` aliases if rotated."""
        if "keys" not in self.doc or self.doc["keys"] is None:
            self.doc["keys"] = []
        keys_list = self.doc["keys"]

        for idx, existing in enumerate(keys_list):
            if self._get_anchor(existing) == anchor:
                if str(existing) == pub_key and isinstance(existing, PlainScalarString):
                    existing.yaml_set_anchor(anchor, always_dump=True)
                    print(f"Key '&{anchor}' already up to date")
                    return existing

                new_node = self._make_anchored_scalar(anchor, pub_key)
                keys_list[idx] = new_node
                for rule in self.doc.get("creation_rules") or []:
                    for group in rule.get("key_groups") or []:
                        age_list = group.get("age")
                        if not isinstance(age_list, list):
                            continue
                        for a_idx, item in enumerate(age_list):
                            if item is existing or self._get_anchor(item) == anchor:
                                age_list[a_idx] = new_node
                self.changed = True
                print(f"Updated key '&{anchor}'")
                return new_node

        new_node = self._make_anchored_scalar(anchor, pub_key)
        keys_list.append(new_node)
        self.changed = True
        print(f"Added key '&{anchor}' ({pub_key})")
        return new_node

    def add_to_creation_rules(
        self,
        anchor: str,
        key_node: PlainScalarString,
        assume_yes: bool = False,
    ) -> bool:
        """Add `*anchor` aliases to `creation_rules` age groups, prompting unless `assume_yes`."""
        rule_changed = False
        for rule in self.doc.get("creation_rules") or []:
            path_regex = rule.get("path_regex", "<unnamed>")
            key_groups = rule.get("key_groups") or []
            already_present = any(
                any(
                    self._get_anchor(item) == anchor
                    for item in (group.get("age") or [])
                )
                for group in key_groups
            )
            if already_present:
                continue

            if not assume_yes and not prompt_yes_no(
                f"Add '*{anchor}' to creation rule for '{path_regex}'?", default=False
            ):
                continue

            for group in key_groups:
                if "age" in group and isinstance(group["age"], list):
                    group["age"].append(key_node)
                    rule_changed = True
            print(f"Added '*{anchor}' to creation rule '{path_regex}'")

        if rule_changed:
            self.changed = True
        return rule_changed

    def dumps(self) -> str:
        """Serialize the `.sops.yaml` document to a formatted YAML string."""
        buf = StringIO()
        self._yaml.dump(self.doc, buf)
        return buf.getvalue()

    def save(self, path: Path | None = None) -> None:
        """Write the `.sops.yaml` document to `path` (defaults to `self.path`)."""
        target_path = path or self.path
        if target_path is None:
            raise ValueError("No target path specified for SopsConfig.save().")
        with open(target_path, "w", encoding="utf-8") as f:
            self._yaml.dump(self.doc, f)


class Command:
    """CLI command dispatcher implementing the `init` and `update` subcommands."""

    _repo_root: Path | None

    def __init__(self, argv: list[str] | None = None) -> None:
        """Parse CLI arguments from `argv` (defaults to `sys.argv[1:]`)."""
        self._repo_root = None
        self.args = self._build_parser().parse_args(argv)

    @property
    def dry_run(self) -> bool:
        """Whether file mutations and key generation should only be previewed."""
        return bool(self.args.dry_run)

    @property
    def repo_root(self) -> Path:
        """Locate and cache the repository root directory containing `.sops.yaml`."""
        if self._repo_root is not None:
            return self._repo_root
        try:
            res = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                capture_output=True,
                text=True,
                check=True,
            )
            git_root = Path(res.stdout.strip())
            if (git_root / ".sops.yaml").is_file():
                self._repo_root = git_root
                return self._repo_root
        except Exception:
            pass

        script_parent = Path(__file__).resolve().parent.parent
        if (script_parent / ".sops.yaml").is_file():
            self._repo_root = script_parent
            return self._repo_root

        raise FileNotFoundError("Could not find repository root containing .sops.yaml.")

    @staticmethod
    def _ssh_pub_to_age(ssh_pub_key: str) -> str:
        """Convert an OpenSSH ed25519 public key line to an `age1...` public key."""
        return subprocess.run(
            ["ssh-to-age"],
            input=f"{ssh_pub_key.strip()}\n",
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

    @staticmethod
    def _build_parser() -> argparse.ArgumentParser:
        """Construct the top-level `argparse` parser for `init` and `update`."""
        parser = argparse.ArgumentParser(
            description="Manage .sops.yaml age keys and secret file encryption."
        )
        subparsers = parser.add_subparsers(dest="command", required=True)

        init_parser = subparsers.add_parser(
            "init",
            help="Enroll a local or remote host/user into .sops.yaml",
        )
        init_parser.add_argument(
            "target",
            nargs="?",
            help="Optional SSH target (e.g. 'zeltennia' or 'bao@zeltennia'); defaults to local host",
        )
        scope = init_parser.add_mutually_exclusive_group()
        scope.add_argument(
            "--user-only",
            action="store_true",
            help="Only enroll the user age key (&<user>_<host>)",
        )
        scope.add_argument(
            "--host-only",
            action="store_true",
            help="Only enroll the host SSH key (&host_<host>)",
        )
        init_parser.add_argument(
            "-y",
            "--yes",
            action="store_true",
            help="Accept key and creation-rule prompts non-interactively",
        )
        update_group = init_parser.add_mutually_exclusive_group()
        update_group.add_argument(
            "-u",
            "--update",
            dest="update",
            action="store_true",
            default=None,
            help="Run 'sops updatekeys' automatically after updating .sops.yaml",
        )
        update_group.add_argument(
            "--no-update",
            dest="update",
            action="store_false",
            help="Skip 'sops updatekeys' without prompting",
        )
        init_parser.add_argument(
            "-n",
            "--dry-run",
            action="store_true",
            help="Preview changes without generating keys or writing files",
        )

        upd_parser = subparsers.add_parser(
            "update",
            help="Re-encrypt secrets/*.yaml with current .sops.yaml keys",
        )
        upd_parser.add_argument(
            "files",
            nargs="*",
            help="Secret files to update (defaults to secrets/*.yaml)",
        )
        upd_parser.add_argument(
            "-n",
            "--dry-run",
            action="store_true",
            help="Print files that would be re-keyed without modifying them",
        )

        return parser

    def run(self) -> None:
        """Dispatch the parsed CLI subcommand (`init` or `update`)."""
        if self.args.command == "init":
            self.init()
        elif self.args.command == "update":
            self.update(self.args.files)

    def init(self) -> None:
        """Enroll user and/or host age keys for a local or SSH target into `.sops.yaml`."""
        sops_yaml_path = Path(
            os.environ.get("SOPS_YAML", self.repo_root / ".sops.yaml")
        )
        sops_cfg = SopsConfig.from_file(sops_yaml_path)

        target = SopsTarget(ssh_target=self.args.target)
        info = target.probe(include_user_key=not self.args.host_only)

        user_anchor = f"{info.user}_{info.hostname}"
        host_anchor = f"host_{info.hostname}"
        enrolled_keys: list[tuple[str, str]] = []

        # 1. User age key (`&<user>_<host>`)
        if not self.args.host_only:
            want_user_key = True
            if not self.args.user_only and not self.args.yes:
                if info.has_user_key:
                    want_user_key = prompt_yes_no(
                        f"Found user age key ('{info.user_keys_path}')."
                        f" Add user key ('{user_anchor}')?",
                        default=True,
                    )
                else:
                    want_user_key = prompt_yes_no(
                        f"No user age key at '{info.user_keys_path}'."
                        f" Generate and add user key ('{user_anchor}')?",
                        default=True,
                    )

            if want_user_key:
                if self.dry_run and not info.has_user_key:
                    print(
                        f"[Dry Run] Would generate user age key at {info.user_keys_path}"
                    )
                    user_pub = "age1dryrun00000000000000000000000000000000000000000000000000000"
                else:
                    if info.has_user_key:
                        print(f"Using existing user key pair ({info.user_keys_path})")
                    user_pub = target.ensure_user_key(info)
                enrolled_keys.append((user_anchor, user_pub))

        # 2. Host SSH key (`&host_<host>`)
        if not self.args.user_only:
            if info.ssh_host_pub_key:
                want_host_key = (
                    True
                    if (self.args.host_only or self.args.yes)
                    else prompt_yes_no(
                        f"Found host SSH public key ('{SSH_HOST_PUB_PATH}')."
                        f" Add host key ('{host_anchor}')?",
                        default=False,
                    )
                )
                if want_host_key:
                    host_pub = self._ssh_pub_to_age(info.ssh_host_pub_key)
                    enrolled_keys.append((host_anchor, host_pub))
            elif self.args.host_only:
                raise FileNotFoundError(
                    f"{SSH_HOST_PUB_PATH} not found on target"
                    f" '{self.args.target or info.hostname}'."
                )

        if not enrolled_keys:
            print("No keys selected.")
            return

        nodes = [
            (anchor, sops_cfg.upsert_key(anchor, pub_key))
            for anchor, pub_key in enrolled_keys
        ]
        for anchor, node in nodes:
            sops_cfg.add_to_creation_rules(anchor, node, assume_yes=self.args.yes)

        if self.dry_run:
            print(
                f"\n[Dry Run] Resulting {sops_yaml_path}:\n{sops_cfg.dumps()}",
                end="",
            )
        elif sops_cfg.changed:
            sops_cfg.save()
            print(f"Saved {sops_yaml_path}")

        should_update = False
        if self.args.update is True:
            should_update = True
        elif self.args.update is None and sops_cfg.changed and not self.args.yes:
            should_update = prompt_yes_no(
                "Re-encrypt secret files now ('sops updatekeys')?", default=False
            )

        if should_update:
            self.update()

    def update(self, files: list[str] | None = None) -> None:
        """Run `sops updatekeys -y` across `files` (defaults to `secrets/*.yaml`)."""
        if files:
            targets = [Path(f) for f in files]
        else:
            secrets_dir = self.repo_root / "secrets"
            targets = sorted(secrets_dir.glob("*.yaml"))

        if not targets:
            print("No secret YAML files found to update.")
            return

        for path in targets:
            rel = (
                path.resolve().relative_to(self.repo_root.resolve())
                if path.is_absolute()
                and path.resolve().is_relative_to(self.repo_root.resolve())
                else path
            )
            if self.dry_run:
                print(f"[Dry Run] Would run: sops updatekeys -y {rel}")
                continue
            subprocess.run(
                ["sops", "updatekeys", "-y", str(rel)],
                cwd=self.repo_root,
                check=True,
            )

        if not self.dry_run:
            print("Done")


def main() -> None:
    """CLI entrypoint handling environment cleanup and user-facing exit codes."""
    # Prevent inherited devShell shellHook (e.g. pre-commit) from running in child nix-shells
    os.environ.pop("shellHook", None)

    try:
        Command().run()
    except KeyboardInterrupt:
        print("\nAborted.", file=sys.stderr)
        sys.exit(130)
    except EOFError:
        print("\nAborted (EOF).", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as exc:
        print(
            f"Command failed (exit {exc.returncode}): {' '.join(exc.cmd)}",
            file=sys.stderr,
        )
        sys.exit(exc.returncode)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
