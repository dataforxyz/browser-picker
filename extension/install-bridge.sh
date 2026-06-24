#!/usr/bin/env bash
# Install the Browser Picker bridge: the native-messaging host + its manifest, plus
# auto-load of the extension via the browser flags file, so links opened from Chromium
# web-app (--app=) windows route through browser-picker.
#
# Auto-load works the omarchy way: Arch/omarchy Chromium wrappers read
# ~/.config/<browser>-flags.conf and apply those flags to every launch (all profiles and
# --user-data-dir web apps), so adding the extension to --load-extension there installs it
# everywhere with no manual "Load unpacked". A manual fallback is printed at the end.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTDIR="$REPO/extension"
BIN="$HOME/.local/bin"
HOST_NAME="com.dataforxyz.browser_picker"

mkdir -p "$BIN"
ln -sf "$REPO/bin/browser-picker-host" "$BIN/browser-picker-host"

# Derive the extension ID from the public key pinned in manifest.json, so allowed_origins
# matches the ID Chromium will assign — same algorithm Chromium uses (sha256 -> a..p).
EXT_ID="$(python3 - "$EXTDIR/manifest.json" <<'PY'
import base64, hashlib, json, sys
key = json.load(open(sys.argv[1]))["key"]
der = base64.b64decode(key)
h = hashlib.sha256(der).hexdigest()[:32]
print("".join(chr(ord("a") + int(c, 16)) for c in h))
PY
)"
echo "Extension ID: $EXT_ID"

# Write the host manifest into every Chromium-family profile dir that exists.
read -r -d '' MANIFEST <<JSON || true
{
  "name": "$HOST_NAME",
  "description": "Browser Picker bridge native host",
  "path": "$BIN/browser-picker-host",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
JSON

install_manifest() {  # <config-dir>
  mkdir -p "$1/NativeMessagingHosts"
  printf '%s\n' "$MANIFEST" > "$1/NativeMessagingHosts/$HOST_NAME.json"
  echo "  installed host manifest -> $1/NativeMessagingHosts/$HOST_NAME.json"
}

installed=0
# Standard Chromium-family config dirs — only if the browser is actually present.
for dir in \
  "$HOME/.config/chromium" \
  "$HOME/.config/google-chrome" \
  "$HOME/.config/BraveSoftware/Brave-Browser" \
  "$HOME/.config/microsoft-edge" \
  "$HOME/.config/vivaldi" \
  "$HOME/.config/opera"; do
  [ -d "$dir" ] || continue
  install_manifest "$dir"
  installed=$((installed + 1))
done

# Custom data dirs Chromium web apps run in. Two sources, deduped: (1) --user-data-dir in
# the web-app .desktop launchers, and (2) any ~/.config/chromium-* dir — some apps use a
# dedicated dir that ISN'T registered via a .desktop file (e.g. WhatsApp personal/business),
# and Chromium's native-host search is per data dir, so the manifest must live in each.
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  install_manifest "$dir"
  installed=$((installed + 1))
done < <( { grep -hoE -- '--user-data-dir=[^ ]+' "$HOME/.local/share/applications/"*.desktop 2>/dev/null \
              | sed 's/--user-data-dir=//' || true
            for d in "$HOME"/.config/chromium-*; do
              if [ -d "$d" ]; then printf '%s\n' "$d"; fi
            done
          } | sort -u )

[ "$installed" -gt 0 ] || echo "  (no Chromium-family config dirs found yet — run a browser once, then re-run)"

# --- Auto-load via the browser flags file (the omarchy mechanism) -----------------------
# Idempotently ensure $EXTDIR is in the flags file's --load-extension list.
ensure_load_extension() {  # <flags-file>
  local conf="$1"
  mkdir -p "$(dirname "$conf")"
  if [ ! -f "$conf" ]; then
    printf -- '--load-extension=%s\n' "$EXTDIR" > "$conf"
    echo "  created $conf"
  elif grep -qF -- "$EXTDIR" "$conf"; then
    echo "  already enabled in $conf"
  elif grep -q -- '--load-extension=' "$conf"; then
    sed -i --follow-symlinks "s#\(--load-extension=[^[:space:]]*\)#\1,$EXTDIR#" "$conf"
    echo "  added to --load-extension in $conf"
  else
    printf -- '--load-extension=%s\n' "$EXTDIR" >> "$conf"
    echo "  appended --load-extension to $conf"
  fi
}

echo "Enabling auto-load via browser flags files:"
ensure_load_extension "$HOME/.config/chromium-flags.conf"   # primary (plain chromium)
# Also extend any other browser flags file that already manages --load-extension (e.g.
# omarchy's brave setup), so those browsers pick the bridge up too.
for conf in "$HOME"/.config/*-flags.conf; do
  [ -e "$conf" ] || continue
  [ "$conf" = "$HOME/.config/chromium-flags.conf" ] && continue
  grep -q -- '--load-extension=' "$conf" 2>/dev/null && ensure_load_extension "$conf"
done

cat <<EOF

Done — the bridge auto-loads via the flags file(s) above, no manual extension install.
Restart any open browser / web-app windows so they pick up the new flag (already-running
windows won't have it until relaunched).

  • Verify:  open chrome://extensions in a web-app window — you should see the bridge,
             ID $EXT_ID
  • Test:    click a link inside a web app (e.g. WhatsApp) — browser-picker should appear
  • Log:     ~/.cache/browser-picker/bridge.log

Manual fallback (if you'd rather not use the flags file): chrome://extensions ->
Developer mode -> Load unpacked -> $EXTDIR
EOF
