# 9. Installing on a fresh Caelestia

This chapter is for anyone who just wants the tab, and for you on a new machine.

## Requirements

- Caelestia shell installed and running (tested with **2.5.0**). Check with `pacman -Q caelestia-shell`.
- `git`, `curl`, `jq`, `iproute2` (provides `ip`). On Arch-based systems, `curl` and `iproute2` are almost always there already:

  ```sh
  sudo pacman -S --needed git curl jq iproute2
  ```

## Quick install

```sh
git clone https://github.com/<you>/caelestia-speedtest
cd caelestia-speedtest
./install.sh --commit
```

If the installer created a new override, it prints restart instructions. Follow them:

```sh
qs list --all              # note the Process ID
qs kill --pid <PID>
caelestia shell -d
```

Open the dashboard and you'll find **Speed test** after Performance.

### Installer options

| Option | Effect |
|---|---|
| `--commit` | Commit the change on the override's branch (`feat(dashboard): add speed test tab`) |
| `--target DIR` or `CAELESTIA_SHELL_DIR=DIR` | Install into a different folder |

Running it twice is safe: files are refreshed, and the tab isn't registered a second time.

## What install.sh does

The script is short and worth reading before you run it. Step by step:

1. **Checks the tools** it needs: `git curl jq ip`.
2. **Finds your shell version** with `pacman -Q`, and warns if it isn't the tested `2.5.0`.
3. **Makes sure you have an override** at `~/.config/quickshell/caelestia`:
   - **Doesn't exist:** clones `caelestia-dots/shell` at the tag matching your package (`v2.5.0`), creates branch `mine`, and names the remote `upstream`. These are the same steps as [chapter 2](02-override-fork.md).
   - **Exists:** uses it as-is. It can be a git fork (recommended) or a plain copy.
4. **Copies the three files** from `src/` (the script with mode 755).
5. **Registers the tab** by applying `patches/dashboard-content.patch`: with `git apply --3way` in a git fork, so small upstream differences merge, or with `patch` in a plain copy. It skips this step if `speedTestComponent` is already there.
6. With `--commit`, **commits** the four paths.

It never writes to `/etc/xdg`, and never touches `~/.config/caelestia/shell.json`.

## Manual install

1. Set up an override ([chapter 2](02-override-fork.md)), or copy the system shell as a quick alternative:

   ```sh
   cp -r /etc/xdg/quickshell/caelestia ~/.config/quickshell/caelestia
   ```

   A plain copy works, but it has no git history to help with updates, and the package's `shell.qml` has `settings.watchFiles: false`, so you must restart the shell after each edit.

2. Copy the files. Run these **from the root of this repo** (the folder with `install.sh`), because the source paths are relative:

   ```sh
   S=~/.config/quickshell/caelestia
   install -Dm755 src/assets/speedtest.sh                 "$S/assets/speedtest.sh"
   install -Dm644 src/services/SpeedTest.qml              "$S/services/SpeedTest.qml"
   install -Dm644 src/modules/dashboard/SpeedTestTab.qml  "$S/modules/dashboard/SpeedTestTab.qml"
   ```

   (Fish users: `set S ~/.config/quickshell/caelestia`. The quoted `"$S/…"` lines work unchanged.)

3. Register the tab, again from the repo root:

   ```sh
   git -C "$S" apply "$PWD/patches/dashboard-content.patch"
   ```

   - `git -C "$S"` switches into the override *before* reading the patch path. A relative `patches/…` would then point inside the override, where no such folder exists. `$PWD/…` turns it into an absolute path to this repo.
   - If your override isn't a git repository, use `patch -d "$S" -p1 < patches/dashboard-content.patch` instead.
   - Or make the two `Content.qml` edits by hand: [chapter 6, step 1](06-dashboard-tab.md#step-1-register-the-tab), parts b and c.

4. Restart the shell as above.

## Uninstall

```sh
./uninstall.sh            # or --target DIR
```

It stops any running test, reverses the patch, and deletes the three files. It doesn't commit; check with `git -C ~/.config/quickshell/caelestia status` and commit or `git checkout` as you like.

To drop the override entirely and go back to the stock shell, see [chapter 2, "Going back"](02-override-fork.md#going-back).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `warning: refs/tags/v2.5.0 … is not a commit!` during install | Harmless. It's how upstream created that tag |
| Tab doesn't appear | The old instance from `/etc/xdg` is still running. `qs list --all` should show only your override's path |
| Two bars on screen | Two instances. Kill the extra one by `--pid` |
| `Patch didn't apply` | Your `Content.qml` differs too much (newer shell version or your own edits). Add the tab by hand ([chapter 6, step 1](06-dashboard-tab.md)) |
| "Failed to fetch speed test endpoints" | Fast.com is unreachable or has changed its API or token. Check with `curl -s "https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=3"` |
| "No active network interface" | No default route. Check `ip route get 1.1.1.1` |
| Results are lower than expected | Other traffic or a VPN is active (the tab shows the interface it used), or Wi-Fi. Compare with fast.com in a browser |
| Custom GIFs or assets disappeared after install | They lived only in `/etc/xdg`. Copy them into the override ([chapter 2, step 3](02-override-fork.md)) |
| Shell broke after a `pacman` update | Rebase your fork onto the new tag ([chapter 8](08-maintaining.md)) |

Next: [10. Exercises →](10-exercises.md)
