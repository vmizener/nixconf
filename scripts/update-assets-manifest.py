#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (ps: [ ps.pillow ps.tomlkit ])"

from __future__ import annotations

import argparse
import math
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageStat
import tomlkit

SUPPORTED_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".bmp",
    ".tiff",
}

COMMON_ASPECT_RATIOS = [
    (16, 9),
    (16, 10),
    (21, 9),
    (32, 9),
    (4, 3),
    (3, 2),
    (5, 4),
    (1, 1),
]


def find_repo_root() -> Path:
  """Find the repository root containing assets/manifest.toml."""
  # 1. Check current working directory and its parents
  cwd = Path.cwd().resolve()
  for parent in [cwd, *cwd.parents]:
    if (parent / "assets/manifest.toml").exists():
      return parent

  # 2. Try git rev-parse
  try:
    res = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    git_root = Path(res.stdout.strip())
    if (git_root / "assets/manifest.toml").exists():
      return git_root
  except Exception:
    pass

  # 3. Fallback to location relative to this script
  script_parent = Path(__file__).resolve().parent.parent
  if (script_parent / "assets/manifest.toml").exists():
    return script_parent

  raise FileNotFoundError(
      "Could not find repository root containing assets/manifest.toml."
  )


def compute_aspect_ratio(w: int, h: int) -> str:
  """Compute aspect ratio string, snapping to common ratios if within 1%."""
  if h == 0:
    return "0:0"
  ratio = w / h
  for cw, ch in COMMON_ASPECT_RATIOS:
    common_ratio = cw / ch
    if abs(ratio - common_ratio) / common_ratio < 0.01:
      return f"{cw}:{ch}"
  g = math.gcd(w, h)
  return f"{w // g}:{h // g}"


def extract_asset_metadata(file_path: Path) -> dict:
  """Extract width, height, aspect ratio, color scheme, dominant color, and palette."""
  with Image.open(file_path) as raw_img:
    width, height = raw_img.size
    # Process first frame if animated image
    rgb_img = raw_img.convert("RGB")

  aspect_ratio = compute_aspect_ratio(width, height)

  # Dominant color from RGB mean
  stat = ImageStat.Stat(rgb_img)
  r, g, b = [int(x) for x in stat.mean[:3]]
  dominant_color = f"#{r:02x}{g:02x}{b:02x}"

  # Relative luminance (ITU-R BT.601)
  lum = 0.299 * r + 0.587 * g + 0.114 * b
  color_scheme = "light" if lum >= 128 else "dark"

  # Downscale copy for fast quantization if large
  q_img = rgb_img
  if max(width, height) > 2048:
    q_img = rgb_img.copy()
    q_img.thumbnail((2048, 2048), Image.Resampling.BOX)

  q = q_img.quantize(colors=5, method=Image.Quantize.MEDIANCUT)
  raw_pal = q.getpalette() or []
  colors = []
  for i in range(0, min(len(raw_pal), 15), 3):
    colors.append((raw_pal[i], raw_pal[i + 1], raw_pal[i + 2]))

  # Sort palette colors descending by luminance
  colors.sort(
      key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2], reverse=True
  )
  palette = [f"#{cr:02x}{cg:02x}{cb:02x}" for cr, cg, cb in colors]

  return {
      "width": width,
      "height": height,
      "aspect_ratio": aspect_ratio,
      "color_scheme": color_scheme,
      "dominant_color": dominant_color,
      "palette": palette,
  }


def update_manifest(
    manifest_path: Path, assets_dir: Path, dry_run: bool = False
) -> None:
  """Update manifest.toml with metadata for all assets in assets_dir."""
  if not manifest_path.exists():
    doc = tomlkit.document()
  else:
    with open(manifest_path, "r", encoding="utf-8") as f:
      doc = tomlkit.parse(f.read())

  # Map existing entries by file path and key
  existing_files: dict[str, str] = {}
  for key, table in doc.items():
    if hasattr(table, "get") and "file" in table:
      existing_files[table["file"]] = key

  # Collect all image assets in assets dir
  found_assets: list[tuple[str, Path]] = []
  for path in sorted(assets_dir.rglob("*")):
    if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS:
      rel_path = path.relative_to(assets_dir).as_posix()
      found_assets.append((rel_path, path))

  added_count = 0
  updated_count = 0

  for rel_path, full_path in found_assets:
    try:
      meta = extract_asset_metadata(full_path)
    except Exception as e:
      print(f"Error processing {rel_path}: {e}", file=sys.stderr)
      continue

    # Determine table key: either existing entry matching file, or file stem
    if rel_path in existing_files:
      key = existing_files[rel_path]
      is_new = False
    elif full_path.stem in doc:
      key = full_path.stem
      is_new = False
    else:
      key = full_path.stem
      is_new = True

    if is_new:
      new_table = tomlkit.table()
      new_table.add("file", rel_path)
      new_table.add("width", meta["width"])
      new_table.add("height", meta["height"])
      new_table.add("aspect_ratio", meta["aspect_ratio"])
      new_table.add("color_scheme", meta["color_scheme"])
      new_table.add("dominant_color", meta["dominant_color"])
      new_table.add("palette", meta["palette"])
      doc.add(key, new_table)
      added_count += 1
      print(f"Added [{key}] ({rel_path})")
    else:
      table = doc[key]
      table["file"] = rel_path
      table["width"] = meta["width"]
      table["height"] = meta["height"]
      table["aspect_ratio"] = meta["aspect_ratio"]
      table["color_scheme"] = meta["color_scheme"]
      table["dominant_color"] = meta["dominant_color"]
      table["palette"] = meta["palette"]
      updated_count += 1
      print(f"Updated [{key}] ({rel_path})")

  # Warn about entries whose files do not exist
  for key, table in doc.items():
    if hasattr(table, "get") and "file" in table:
      asset_file = assets_dir / table["file"]
      if not asset_file.exists():
        print(
            f"Warning: [{key}] points to missing file: {table['file']}",
            file=sys.stderr,
        )

  if dry_run:
    print(
        f"\n[Dry Run] Would update {manifest_path} (added {added_count},"
        f" updated {updated_count})"
    )
    return

  with open(manifest_path, "w", encoding="utf-8") as f:
    f.write(tomlkit.dumps(doc))

  print(
      f"\nSaved {manifest_path} ({added_count} added, {updated_count} updated)."
  )


def main() -> None:
  parser = argparse.ArgumentParser(
      description="Update assets/manifest.toml with image metadata."
  )
  parser.add_argument(
      "--dry-run",
      action="store_true",
      help="Analyze assets and print changes without modifying manifest.toml",
  )

  args = parser.parse_args()

  try:
    repo_root = find_repo_root()
  except FileNotFoundError as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)

  manifest_path = repo_root / "assets/manifest.toml"
  assets_dir = repo_root / "assets"

  if not assets_dir.is_dir():
    print(f"Error: assets directory not found: {assets_dir}", file=sys.stderr)
    sys.exit(1)

  update_manifest(manifest_path, assets_dir, dry_run=args.dry_run)


if __name__ == "__main__":
  main()
