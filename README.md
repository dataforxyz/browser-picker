# browser-picker

A Linux default-browser replacement that pops up a **menu of every browser + profile**
each time you open a link — with **smart-default rules** so chosen sites skip the menu and
open directly in the right profile.

Built for [omarchy](https://omarchy.org) / Hyprland + [walker](https://github.com/abenz1267/walker),
but works with any `dmenu`-style menu.

![flow](https://img.shields.io/badge/wayland-friendly-blue)

## Why

If you keep several browsers and many profiles (work, personal, clients, AI accounts…),
a single "default browser" is the wrong model. browser-picker lets you decide *per link*,
and remembers the decisions you want to make permanent.

## Features

- **Picker on every link** — choose browser + profile from a menu (`walker --dmenu`).
- **Smart defaults** — rules like `github.com/myorg/myrepo → Chromium (Work)` open
  directly, no menu. Plain text = substring match (covers a URL *and its child paths*);
  `*`/`?` = glob. First match wins.
- **In-flow rule creation** — pick *📌 Always open this site in…* from the menu and a GTK
  editor opens **pre-filled** from the current URL; trim the scope, pick a profile, Save.
- **GTK rules editor** — enable/disable, edit patterns, reorder priority (▲▼), and
  **⟳ Rescan profiles** to auto-detect installed browsers/profiles.
- **Routes** `http`, `https`, and `mailto`.

## Install

```sh
git clone https://github.com/dataforxyz/browser-picker
cd browser-picker
./install.sh
```

`install.sh` symlinks the executables into `~/.local/bin`, installs the `.desktop`
launchers, seeds `~/.config/browser-picker/` from the examples (without overwriting an
existing config), and registers the picker as the default web/link handler.

> Ensure `~/.local/bin` is on your `PATH`.

### Requirements

- A `dmenu`-capable menu — [walker](https://github.com/abenz1267/walker) preferred
  (uses omarchy's `omarchy-launch-walker` if present, else `walker --dmenu`).
- Python 3 + PyGObject (GTK 4) for the rules editor (`python-gobject` on Arch).
- `xdg-utils`, `util-linux` (`setsid`).

## Configuration

Two files in `~/.config/browser-picker/`:

- **`browsers.conf`** — `Label|||command` per line. Auto-fill with *Rescan profiles*.
- **`rules.conf`** — `enabled|||pattern|||label` per line. Managed by the editor.

Both are read fresh on every link click — no daemon, no restart.

## How it works

`browser-picker` is registered as an `x-scheme-handler/*` handler. On each link it checks
`rules.conf` for the first enabled match and launches that profile directly; otherwise it
shows the menu. Profiles are launched detached via `setsid`.

Profile detection reads Chromium-family `Local State` (`profile.info_cache`) and
Firefox-family `profiles.ini`.

## Notes / limitations

- Firefox & Zen open one profile at a time — opening a link in a profile while a *different*
  profile of the same browser is running may defer to the running instance (a browser
  limitation, not this tool). Chromium-family handle concurrent profiles fine.
- *Rescan* only **adds** newly found profiles; it won't delete entries you've removed by
  hand (so custom entries like a bare `Brave` survive).

## License

MIT — see [LICENSE](LICENSE).
