#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (ps: [ ps.pillow ps.tomlkit ])"

from __future__ import annotations

from abc import ABC, abstractmethod
import argparse
import math
from pathlib import Path
import subprocess
import sys
from typing import Any

from PIL import Image, ImageStat
import tomlkit
from tomlkit.items import Table
from tomlkit.toml_document import TOMLDocument

ASSETS_PATH = "assets"
MANIFEST_PATH = f"{ASSETS_PATH}/manifest.toml"

SUPPORTED_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".bmp",
    ".tiff",
}


class Main:
  _repo_root: Path | None
  _handlers: list[BaseAssetHandler]

  @property
  def dry_run(self) -> bool:
    return self.args.dry_run

  @property
  def repo_root(self) -> Path:
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
      if (git_root / "assets/manifest.toml").exists():
        self._repo_root = git_root
        return self._repo_root
    except Exception:
      pass

    script_parent = Path(__file__).resolve().parent.parent
    if (script_parent / "assets/manifest.toml").exists():
      self._repo_root = script_parent
      return self._repo_root

    raise FileNotFoundError(
        "Could not find repository root containing assets/manifest.toml."
    )

  @property
  def assets_dir(self) -> Path:
    return self.repo_root / ASSETS_PATH

  @property
  def manifest_path(self) -> Path:
    return self.repo_root / MANIFEST_PATH

  @property
  def handlers(self) -> list[BaseAssetHandler]:
    return self._handlers

  def __init__(self):
    self._repo_root = None
    self._handlers = []
    parser = argparse.ArgumentParser(
        description="Update assets/manifest.toml with image metadata."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Analyze assets and print changes without modifying manifest.toml",
    )
    self.args = parser.parse_args()

  def register_handler(self, handler: BaseAssetHandler) -> None:
    if handler not in self._handlers:
      self._handlers.append(handler)

  def update_manifest(self) -> None:
    """Update manifest.toml with metadata for all assets in assets_dir."""
    if not self.manifest_path.exists():
      doc = tomlkit.document()
    else:
      with open(self.manifest_path, "r", encoding="utf-8") as f:
        doc = tomlkit.parse(f.read())

    total_added = 0
    total_updated = 0
    all_warnings = []

    for handler in self.handlers:
      added, updated = handler.update_section(doc, self.assets_dir)
      total_added += added
      total_updated += updated
      all_warnings.extend(handler.validate(doc, self.assets_dir))

    for w in all_warnings:
      print(f"Warning: {w}", file=sys.stderr)

    if self.dry_run:
      print(
          f"\n[Dry Run] Would update {self.manifest_path} (added {total_added},"
          f" updated {total_updated})"
      )
      return

    with open(self.manifest_path, "w", encoding="utf-8") as f:
      f.write(tomlkit.dumps(doc))

    print(
        f"\nSaved {self.manifest_path} ({total_added} added, {total_updated}"
        " updated)."
    )


def compute_aspect_ratio(w: int, h: int) -> str:
  """Compute aspect ratio string, snapping to common ratios if within 1%."""
  common_aspect_ratios = [
      (16, 9),
      (16, 10),
      (21, 9),
      (32, 9),
      (4, 3),
      (3, 2),
      (5, 4),
      (1, 1),
  ]
  if h == 0:
    return "0:0"
  ratio = w / h
  for cw, ch in common_aspect_ratios:
    common_ratio = cw / ch
    if abs(ratio - common_ratio) / common_ratio < 0.01:
      return f"{cw}:{ch}"
  g = math.gcd(w, h)
  return f"{w // g}:{h // g}"


def extract_color_metadata(rgb_img: Image.Image) -> dict[str, Any]:
  """Extract color scheme, dominant color, and palette from an RGB image."""
  stat = ImageStat.Stat(rgb_img)
  r, g, b = [int(x) for x in stat.mean[:3]]
  dominant_color = f"#{r:02x}{g:02x}{b:02x}"

  # ITU-R BT.601 standard for luminance
  def luminance(r: int, g: int, b: int) -> float:
    return 0.299 * r + 0.587 * g + 0.114 * b

  lum = luminance(r, g, b)
  color_scheme = "light" if lum >= 128 else "dark"

  width, height = rgb_img.size
  q_img = rgb_img
  if max(width, height) > 2048:
    q_img = rgb_img.copy()
    q_img.thumbnail((2048, 2048), Image.Resampling.BOX)

  q = q_img.quantize(colors=5, method=Image.Quantize.MEDIANCUT)
  raw_pal = q.getpalette() or []
  colors = []
  for i in range(0, min(len(raw_pal), 15), 3):
    colors.append((raw_pal[i], raw_pal[i + 1], raw_pal[i + 2]))

  colors.sort(key=lambda c: luminance(c[0], c[1], c[2]), reverse=True)
  palette = [f"#{cr:02x}{cg:02x}{cb:02x}" for cr, cg, cb in colors]

  return {
      "color_scheme": color_scheme,
      "dominant_color": dominant_color,
      "palette": palette,
  }


class BaseAssetHandler(ABC):
  """Abstract base handler for asset categories in manifest.toml."""

  section: str
  sub_dir: str

  def get_or_create_section(self, doc: TOMLDocument) -> Table:
    """Ensure the category section table exists in the document."""
    if self.section not in doc:
      tbl = tomlkit.table()
      doc.add(self.section, tbl)
      return tbl
    tbl = doc[self.section]
    if not isinstance(tbl, Table):
      new_tbl = tomlkit.table()
      doc[self.section] = new_tbl
      return new_tbl
    return tbl

  @abstractmethod
  def update_section(
      self, doc: TOMLDocument, assets_dir: Path
  ) -> tuple[int, int]:
    """Discover assets, extract metadata, and update the category table."""
    ...

  @abstractmethod
  def validate(self, doc: TOMLDocument, assets_dir: Path) -> list[str]:
    """Validate that assets listed in the manifest exist on disk."""
    ...


class WallpaperHandler(BaseAssetHandler):
  """Handler for single-file wallpaper assets."""

  section = "wallpapers"
  sub_dir = "wallpapers"

  def update_section(
      self, doc: TOMLDocument, assets_dir: Path
  ) -> tuple[int, int]:
    section_table = self.get_or_create_section(doc)
    category_dir = assets_dir / self.sub_dir
    if not category_dir.is_dir():
      return 0, 0

    added_count = 0
    updated_count = 0

    for path in sorted(category_dir.rglob("*")):
      if not path.is_file() or path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        continue

      rel_path = path.relative_to(assets_dir).as_posix()
      key = path.stem

      try:
        with Image.open(path) as raw_img:
          width, height = raw_img.size
          rgb_img = raw_img.convert("RGB")
          aspect_ratio = compute_aspect_ratio(width, height)
          color_meta = extract_color_metadata(rgb_img)
      except Exception as e:
        print(f"Error processing {rel_path}: {e}", file=sys.stderr)
        continue

      is_new = key not in section_table
      if is_new:
        table = tomlkit.table()
        table.add("file", rel_path)
        table.add("width", width)
        table.add("height", height)
        table.add("aspect_ratio", aspect_ratio)
        table.add("color_scheme", color_meta["color_scheme"])
        table.add("dominant_color", color_meta["dominant_color"])
        table.add("palette", color_meta["palette"])
        section_table.add(key, table)
        added_count += 1
        print(f"Added [{self.section}.{key}] ({rel_path})")
      else:
        table = section_table[key]
        table["file"] = rel_path
        table["width"] = width
        table["height"] = height
        table["aspect_ratio"] = aspect_ratio
        table["color_scheme"] = color_meta["color_scheme"]
        table["dominant_color"] = color_meta["dominant_color"]
        table["palette"] = color_meta["palette"]
        updated_count += 1
        print(f"Updated [{self.section}.{key}] ({rel_path})")

    return added_count, updated_count

  def validate(self, doc: TOMLDocument, assets_dir: Path) -> list[str]:
    warnings = []
    if self.section not in doc:
      return warnings

    section_table = doc[self.section]
    for key, table in section_table.items():
      if hasattr(table, "get") and "file" in table:
        asset_file = assets_dir / table["file"]
        if not asset_file.exists():
          warnings.append(
              f"[{self.section}.{key}] points to missing file: {table['file']}"
          )
    return warnings


class IconHandler(BaseAssetHandler):
  """Handler for multi-resolution theme icon assets."""

  section = "icons"
  sub_dir = "icons"

  def _sort_dimensions(self, dims: list[str]) -> list[str]:
    def dim_key(d: str) -> int:
      parts = d.lower().split("x")
      if len(parts) == 2 and parts[0].isdigit() and parts[1].isdigit():
        return int(parts[0]) * int(parts[1])
      return 0

    return sorted(dims, key=dim_key)

  def update_section(
      self, doc: TOMLDocument, assets_dir: Path
  ) -> tuple[int, int]:
    section_table = self.get_or_create_section(doc)
    category_dir = assets_dir / self.sub_dir
    if not category_dir.is_dir():
      return 0, 0

    # Group multi-resolution icons: (theme, context, stem) -> dict
    icon_groups: dict[str, dict[str, Any]] = {}

    for path in sorted(category_dir.rglob("*")):
      if not path.is_file() or path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        continue

      rel_path = path.relative_to(assets_dir)
      # Expected: icons/<theme>/<dimension>/<context>/<stem>.<ext>
      parts = rel_path.parts
      if len(parts) >= 5 and parts[0] == "icons":
        theme = parts[1]
        dimension = parts[2]
        context = parts[3]
        stem = path.stem
        ext = path.suffix
        file_template = f"icons/{theme}/{{dimension}}/{context}/{stem}{ext}"

        if stem not in icon_groups:
          icon_groups[stem] = {
              "theme": theme,
              "context": context,
              "file": file_template,
              "dimensions": [],
              "files_by_dim": {},
          }
        icon_groups[stem]["dimensions"].append(dimension)
        icon_groups[stem]["files_by_dim"][dimension] = path

    added_count = 0
    updated_count = 0

    for key, data in icon_groups.items():
      sorted_dims = self._sort_dimensions(data["dimensions"])
      largest_dim = sorted_dims[-1] if sorted_dims else None
      largest_file = data["files_by_dim"].get(largest_dim)

      color_meta: dict[str, Any] = {
          "color_scheme": "light",
          "dominant_color": "#000000",
          "palette": [],
      }
      if largest_file:
        try:
          with Image.open(largest_file) as raw_img:
            rgb_img = raw_img.convert("RGB")
            color_meta = extract_color_metadata(rgb_img)
        except Exception as e:
          print(f"Error extracting colors for icon {key}: {e}", file=sys.stderr)

      is_new = key not in section_table
      if is_new:
        table = tomlkit.table()
        table.add("theme", data["theme"])
        table.add("context", data["context"])
        table.add("file", data["file"])
        table.add("dimensions", sorted_dims)
        table.add("color_scheme", color_meta["color_scheme"])
        table.add("dominant_color", color_meta["dominant_color"])
        table.add("palette", color_meta["palette"])
        section_table.add(key, table)
        added_count += 1
        print(f"Added [{self.section}.{key}] ({data['file']})")
      else:
        table = section_table[key]
        table["theme"] = data["theme"]
        table["context"] = data["context"]
        table["file"] = data["file"]
        table["dimensions"] = sorted_dims
        table["color_scheme"] = color_meta["color_scheme"]
        table["dominant_color"] = color_meta["dominant_color"]
        table["palette"] = color_meta["palette"]
        updated_count += 1
        print(f"Updated [{self.section}.{key}] ({data['file']})")

    return added_count, updated_count

  def validate(self, doc: TOMLDocument, assets_dir: Path) -> list[str]:
    warnings = []
    if self.section not in doc:
      return warnings

    section_table = doc[self.section]
    for key, table in section_table.items():
      if not hasattr(table, "get") or "file" not in table:
        continue
      template = table["file"]
      dims = table.get("dimensions", [""])
      found = False
      for d in dims:
        expanded = template.replace("{dimension}", d)
        if (assets_dir / expanded).exists():
          found = True
          break
      if not found:
        warnings.append(
            f"[{self.section}.{key}] points to missing icon files: {template}"
        )
    return warnings


def main() -> None:
  main = Main()
  for handler in [IconHandler(), WallpaperHandler()]:
    main.register_handler(handler)
  main.update_manifest()


if __name__ == "__main__":
  main()
