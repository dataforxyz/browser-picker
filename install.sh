#!/usr/bin/env bash
# Install browser-picker: symlink the executables, register the .desktop files,
# seed config from the examples, and set the picker as the default link handler.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/browser-picker"

mkdir -p "$BIN" "$APPS" "$CFG"

# Executables: symlinked so edits in the repo go live immediately.
ln -sf "$REPO/bin/browser-picker"           "$BIN/browser-picker"
ln -sf "$REPO/bin/browser-picker-rules"     "$BIN/browser-picker-rules"
ln -sf "$REPO/bin/browser-picker-recommend" "$BIN/browser-picker-recommend"

# Desktop entries: expand @BINDIR@ to the absolute bin path (xdg needs an abs Exec).
for d in browser-picker browser-picker-rules; do
  sed "s|@BINDIR@|$BIN|g" "$REPO/applications/$d.desktop" > "$APPS/$d.desktop"
done
update-desktop-database "$APPS" 2>/dev/null || true

# Seed config from examples without clobbering an existing setup.
[ -f "$CFG/browsers.conf" ] || cp "$REPO/config/browsers.conf.example" "$CFG/browsers.conf"
[ -f "$CFG/rules.conf" ]    || cp "$REPO/config/rules.conf.example"    "$CFG/rules.conf"

# Make the picker the default for web links.
command -v xdg-settings >/dev/null 2>&1 && \
  xdg-settings set default-web-browser browser-picker.desktop 2>/dev/null || true
xdg-mime default browser-picker.desktop \
  x-scheme-handler/http x-scheme-handler/https x-scheme-handler/mailto 2>/dev/null || true

cat <<EOF
Installed browser-picker.
  • Manage rules:   browser-picker-rules   (or "Browser Picker Rules" in your launcher)
  • Detect profiles: open the rules app and click "⟳ Rescan profiles"
  • Config lives in: $CFG
Click any link to see the picker. Requires a dmenu-capable menu — walker (preferred)
or any program providing 'walker --dmenu'.
EOF
