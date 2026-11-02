# WinDock for Omarchy

Two additions for [WinDock](https://github.com/aliihsaad/WinDock) on [Omarchy](https://omarchy.org):

- **A bar widget** that shows whether WinDock is running, its address and its PIN, and toggles it from the bar.
- **A patch** that keeps phone sessions across host restarts, so the phone stops asking for a PIN every time WinDock restarts.

Both were built against WinDock 0.2.6-preview.1 on Arch/Omarchy with Hyprland.

## Bar widget

### What it does

| WinDock state | Icon | Colour |
| --- | --- | --- |
| Running | `cellphone-link` | normal foreground |
| Stopped | `cellphone-link-off` | `bar.urgent` (red) |

- Left click starts or stops `windock.service`.
- Right click copies the current PIN to the clipboard.
- Hovering shows the address, the PIN and the current state.
- The state is polled every 15 seconds and refreshed right after a click.

### Install

```bash
mkdir -p ~/.config/omarchy/plugins/michael.windock
cp omarchy-widget/* ~/.config/omarchy/plugins/michael.windock/
omarchy restart shell
```

Then add it to the bar:

```bash
omarchy bar put michael.windock --after omarchy.indicators
```

The folder name, the manifest `id` and the QML `moduleName` must all match. If you rename one, rename all three.

### Requirements

- WinDock installed as a systemd user service named `windock.service`.
- The `windock` command on `PATH`, used to read the PIN (`windock status`).
- `wl-copy` for the right-click action.

### Editing it

Saving `BarWidget.qml` is not enough. Omarchy's plugin hot reload updates the registry but does **not** re-instantiate bar widgets, so the old component stays mounted and nothing visibly changes. Run `omarchy restart shell` after every edit.

That detail cost me an hour of chasing a widget that was never created. `omarchy-shell shell debugBarGeometry` reports the slot even when the component failed to load, so it is not proof that the widget exists.

## Persistent sessions patch

### Why

`createSessionStore()` in `src/auth.js` keeps tokens in a JavaScript `Map`. When the host restarts, the map is gone and every paired phone is signed out, so each device has to pair again with a fresh PIN. The upstream README states it plainly: "Sessions reset when the PC host restarts."

The phone's cookie is set with a 180-day lifetime, so the server side is the only thing throwing sessions away.

### What it changes

- `src/auth.js`: `createSessionStore` accepts an optional `file`. When set, it loads unexpired tokens on start and writes the map after `issue()` and `revokeAll()`. Writes go to a temporary file and are renamed into place, with mode `0600`.
- `server.js`: the default store points at `<configStore.path>.sessions`, which resolves to `~/.config/windock/config.json.sessions`.

Without a `file`, the store behaves exactly as before.

### Apply

```bash
sudo patch -d /usr/lib/windock -p1 < persistent-sessions.patch
systemctl --user restart windock.service
```

The PIN still changes on restart. That is fine: the phone no longer needs it, because its existing cookie keeps working until it expires.

### Reapply after updates

A package update replaces `/usr/lib/windock`, so the patch is lost. Reapply it after each `pacman -U`.

### Security

Tokens are stored in `~/.config/windock/config.json.sessions` with mode `0600`. Anyone who can read that file can act as a paired phone. Delete it to sign every device out. The upstream project targets a trusted home or office network and serves plain HTTP, so this patch does not change the threat model in any meaningful way, but it does make the token outlive the process.

### Verified

`tests/session-persistence.mjs` runs the store through: issue, file creation, file mode, survival across a new store, the no-file path, unknown tokens, `revokeAll` persistence, and expired-token cleanup.

```bash
node tests/session-persistence.mjs /usr/lib/windock/src/auth.js
```

An end-to-end run against the patched server confirmed the point of the patch: pair once, restart the process with a different PIN, and the old cookie still authorises `/api/state` while the old PIN is rejected.

## License

MIT. See [LICENSE](LICENSE).

WinDock itself is MIT, copyright © 2026 Ali Saad. Because the patch modifies its source, the full WinDock license is reproduced in [licenses/WinDock-LICENSE](licenses/WinDock-LICENSE). See [NOTICE](NOTICE) for what comes from where.
