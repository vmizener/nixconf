#!/usr/bin/env bash
set -euo pipefail

factorio_bin="@FACTORIO_BIN@"
state_dir="@STATE_DIR@"
runtime_dir="@RUNTIME_DIR@"
save_path="@SAVE_PATH@"
config_file="@CONFIG_FILE@"
mod_dir="@MOD_DIR@"
mods_dat="@MODS_DAT@"
mod_list_file="@MOD_LIST_FILE@"
base_settings_file="@BASE_SETTINGS_FILE@"
map_preset="@MAP_PRESET@"
map_gen_seed="@MAP_GEN_SEED@"
map_gen_settings="@MAP_GEN_SETTINGS@"
map_settings="@MAP_SETTINGS@"
creds_dir="${CREDENTIALS_DIRECTORY:-}"

mkdir -p "$state_dir/mods" "$state_dir/saves"

# Copy factorio.conf into /run so Factorio can rewrite it cleanly on shutdown
cp --no-preserve=mode "$config_file" "$runtime_dir/factorio.conf"
chmod 0600 "$runtime_dir/factorio.conf"

# Sync declarative mod symlinks while preserving manually uploaded .zip mods
find "$state_dir/mods" -maxdepth 1 -type l -lname '/nix/store/*' -delete
if [[ -n $mod_dir ]]; then
  for mod_zip in "$mod_dir"/*.zip; do
    [[ -e $mod_zip ]] || continue
    ln -sf "$mod_zip" "$state_dir/mods/$(basename "$mod_zip")"
  done
fi
if [[ -n $mods_dat ]]; then
  cp --no-preserve=mode "$mods_dat" "$state_dir/mods/mod-settings.dat"
  chmod 0660 "$state_dir/mods/mod-settings.dat"
fi

# Enforce Space Age / DLC & mod toggles in mod-list.json before map creation or start
if [[ -f "$state_dir/mods/mod-list.json" ]]; then
  jq --slurpfile decl "$mod_list_file" '
    reduce ((.mods // []) + $decl[0].mods)[] as $m ({}; .[$m.name] = $m)
    | {mods: ([.[]] | sort_by(.name))}
  ' "$state_dir/mods/mod-list.json" >"$state_dir/mods/mod-list.json.tmp"
  mv "$state_dir/mods/mod-list.json.tmp" "$state_dir/mods/mod-list.json"
else
  cp --no-preserve=mode "$mod_list_file" "$state_dir/mods/mod-list.json"
  chmod 0660 "$state_dir/mods/mod-list.json"
fi

# Materialize server-settings.json in /run with runtime secrets from LoadCredential
settings_file="$runtime_dir/server-settings.json"
cp --no-preserve=mode "$base_settings_file" "$settings_file"
chmod 0600 "$settings_file"

if [[ -n $creds_dir && -f "$creds_dir/token" ]]; then
  jq --rawfile token "$creds_dir/token" \
    '.token = ($token | sub("\\r?\\n$"; ""))' \
    "$settings_file" >"$settings_file.tmp"
  mv "$settings_file.tmp" "$settings_file"
fi
if [[ -n $creds_dir && -f "$creds_dir/game-password" ]]; then
  jq --rawfile pw "$creds_dir/game-password" \
    '.game_password = ($pw | sub("\\r?\\n$"; ""))' \
    "$settings_file" >"$settings_file.tmp"
  mv "$settings_file.tmp" "$settings_file"
fi
if [[ -n $creds_dir && -f "$creds_dir/extra-settings" ]]; then
  jq -s '.[0] * .[1]' "$settings_file" "$creds_dir/extra-settings" >"$settings_file.tmp"
  mv "$settings_file.tmp" "$settings_file"
fi

# Generate initial save if absent (runs after mod-list.json so Space Age / DLC flags apply)
if [[ ! -e $save_path ]]; then
  create_args=(
    "$factorio_bin"
    "--config=$runtime_dir/factorio.conf"
    "--create=$save_path"
  )
  if [[ -n $map_preset ]]; then
    create_args+=("--preset=$map_preset")
  fi
  if [[ -n $map_gen_seed ]]; then
    create_args+=("--map-gen-seed=$map_gen_seed")
  fi
  if [[ -n $map_gen_settings ]]; then
    create_args+=("--map-gen-settings=$map_gen_settings")
  fi
  if [[ -n $map_settings ]]; then
    create_args+=("--map-settings=$map_settings")
  fi
  "${create_args[@]}"
fi
