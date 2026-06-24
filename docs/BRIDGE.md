# Web-app link bridge

Chromium **web-app windows** (`chromium --app=<url>`, e.g. omarchy web apps) handle link
clicks *internally*: a `target=_blank` or cross-site link opens in a new Chromium window and
never calls the system link handler — so `browser-picker` is bypassed. `mailto:` and other
true external protocols still reach the picker; `http(s)` links from app windows do not.

This bridge fixes that with a small MV3 extension + a native-messaging host:

```
app-window link click
  └─▶ extension (background.js)         catches onCreatedNavigationTarget from an app window,
        │                                closes the tab Chromium was about to open
        └─▶ native host (browser-picker-host)   reads the URL off stdin
              └─▶ browser-picker <url>           your normal picker / smart-default rules
```

## Install

```sh
extension/install-bridge.sh          # installs the native host + manifest, and enables auto-load
```

This installs the native host into every Chromium-family config dir (including custom
web-app `--user-data-dir`s and any `~/.config/chromium-*` dir), then **auto-loads the
extension** by adding it to `--load-extension` in `~/.config/chromium-flags.conf` (and any
other browser flags file that already uses `--load-extension`, e.g. omarchy's brave setup).

On Arch/omarchy the Chromium wrapper applies `<browser>-flags.conf` to every launch — all
profiles and `--user-data-dir` web apps — so the extension loads everywhere with no manual
step. **Restart any open browser/web-app windows** to pick it up.

The extension ID is pinned by the `key` field in `manifest.json`, so the host's
`allowed_origins` always matches without copying IDs around.

### Manual fallback

If you'd rather not use the flags file: `chrome://extensions` → **Developer mode** →
**Load unpacked** → select the `extension/` directory (once per data dir that runs web
apps). Don't combine both for the same data dir — pick the flags file *or* a manual load,
or Chromium sees the same ID twice.

## How it decides what to divert

`background.js` only acts when **all** hold:

- the link's **source window** is a web-app window (`APP_WINDOW_TYPES` — `app`/`popup`;
  ordinary `normal` browsing windows are never touched), and
- the **new** window Chromium spawned is not a `popup` (`SKIP_NEW_TYPES`) — scripted
  OAuth/login/payment popups open *as* popups and must return to their opener, so they're
  left alone, and
- the host isn't in `IGNORE_HOSTS` (extra guard for common identity providers).

Every non-`normal`-source navigation is logged to `~/.cache/browser-picker/bridge.log`
(`nav src=… new=… act=… <url>`), so first-run behaviour — including the real window types on
your Chromium build — is visible. Tune the constants at the top of `background.js` if needed.

## Limitations

- A link that navigates the **app window itself** (same tab, not a new window) is not
  intercepted — doing so would break in-app OAuth redirects. Only new-window/new-tab links
  are diverted.
- Loading is per browser data dir. `install-bridge.sh` automates it via the flags file (the
  omarchy mechanism); the manual `chrome://extensions` → Load unpacked path is a fallback.

## Firefox / Zen — not applicable

The bridge is Chromium-only, and that isn't a gap on an omarchy setup:

- **omarchy web apps are always Chromium.** `omarchy-launch-webapp` falls back to
  `chromium.desktop` for any non-Chromium-family default browser, so Firefox/Zen never host
  these web apps even when set as the default browser.
- **No app-window model to intercept.** Firefox has no `--app=`/SSB mode; Zen's web-app
  support (Firefox's upstream Taskbar Apps) currently opens pinned tabs in a normal window
  rather than isolated app windows, and there is no `--app=`-style CLI flag yet — so there
  are no escaping links to catch.
- **Different, signed plumbing.** A Gecko port would need its own WebExtension
  (`browser_specific_settings.gecko.id`), a `~/.mozilla/native-messaging-hosts/` manifest
  keyed by `allowed_extensions`, and a *signed* XPI — the `--load-extension` flags-file
  auto-load this relies on doesn't exist on Firefox.

Revisit only if Zen/Firefox ship real isolated app windows plus an `--app=`-style flag.
