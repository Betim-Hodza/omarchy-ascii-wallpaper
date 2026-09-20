#!/bin/bash
# Helper for the ascii-wallpaper plugin: wires/unwires the menu entry in
# ~/.config/omarchy/extensions/omarchy-menu.jsonc and cleans up on unload.

set -uo pipefail

readonly plugin_id="betim.ascii-wallpaper"
readonly plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"
readonly state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/ascii-wallpaper"
readonly cleanup_helper="$state_dir/cleanup"
readonly menu_file="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
readonly menu_entry_id="style.asciiwallpaper"

wire_menu() {
  local action="$plugin_dir/ascii-wallpaper-menu"
  python3 - "$menu_file" "$action" <<'PY'
import re, sys, os

path, action = sys.argv[1], sys.argv[2]
entry = ('  "style.asciiwallpaper": {"icon":"\uf120","label":"ASCII Wallpaper",'
         '"aliases":["ascii","asciiwallpaper","ascii-wallpaper"],'
         '"description":"Convert a video into an ASCII-art wallpaper in theme colors",'
         f'"action":"omarchy-launch-floating-terminal-with-presentation {action}"}},')

text = ""
if os.path.exists(path):
    with open(path) as f:
        text = f.read()

lines = text.splitlines()
out, replaced = [], False
for line in lines:
    if '"style.asciiwallpaper"' in line:
        if not replaced:
            out.append(entry)
            replaced = True
        continue  # drop any duplicate lines for this id
    out.append(line)

if not replaced:
    # insert after the opening brace
    for i, line in enumerate(out):
        if "{" in line:
            out.insert(i + 1, entry)
            break
    else:
        out = ["{", entry, "}"]

os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".tmp"
with open(tmp, "w") as f:
    f.write("\n".join(out) + "\n")
os.replace(tmp, path)
PY
  omarchy menu refresh >/dev/null 2>&1 || true
}

unwire_menu() {
  [[ -f $menu_file ]] || return 0
  python3 - "$menu_file" <<'PY'
import sys, os

path = sys.argv[1]
with open(path) as f:
    lines = f.read().splitlines()
out = [l for l in lines if '"style.asciiwallpaper"' not in l]
tmp = path + ".tmp"
with open(tmp, "w") as f:
    f.write("\n".join(out) + "\n")
os.replace(tmp, path)
PY
  omarchy menu refresh >/dev/null 2>&1 || true
}

prepare_cleanup_helper() {
  mkdir -p -m 0700 "$state_dir" 2>/dev/null || return 1
  [[ -L $state_dir ]] && return 1
  local tmp
  tmp=$(mktemp -p "$state_dir" .cleanup.XXXXXX) || return 1
  cp -f "$plugin_dir/ascii-wallpaper.sh" "$tmp" || { rm -f "$tmp"; return 1; }
  chmod 0755 "$tmp"
  mv -f "$tmp" "$cleanup_helper"
  chmod 0755 "$cleanup_helper" 2>/dev/null || true
}

cleanup_after_unload() {
  # Called detached right before the shell unloads the plugin. If the plugin
  # directory is gone (removed) or the plugin is disabled, drop the menu entry.
  for _ in {1..200}; do
    if [[ ! -d $plugin_dir ]]; then
      unwire_menu
      rm -rf "$state_dir"
      return 0
    fi
    sleep 0.01
  done

  local enabled
  enabled=$(omarchy plugin list --json 2>/dev/null \
    | jq -r --arg id "$plugin_id" '.[] | select(.id == $id) | .enabled' 2>/dev/null || true)
  if [[ $enabled == false ]]; then
    unwire_menu
  fi
}

case "${1:-}" in
  --wire-menu)
    prepare_cleanup_helper || true
    wire_menu
    ;;
  --unwire-menu)
    unwire_menu
    ;;
  --cleanup-after-unload)
    cleanup_after_unload
    ;;
  *)
    echo "usage: $0 [--wire-menu|--unwire-menu|--cleanup-after-unload]" >&2
    exit 2
    ;;
esac
