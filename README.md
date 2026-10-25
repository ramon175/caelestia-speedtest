# caelestia-speedtest

A **Speed test** tab for the [Caelestia](https://github.com/caelestia-dots/shell) Hyprland shell's dashboard. Press a button to get live download and upload readings on two dials. It uses the same Fast.com method as [Omarchy](https://github.com/basecamp/omarchy)'s speed test panel.

<!-- TODO: add screenshots/speedtest-tab.png, see screenshots/README.md -->
![Speed test tab](screenshots/speedtest-tab.png)

The repo also has a **step-by-step tutorial** in [`docs/`](docs/README.md). It covers how the tab was built, from reading Omarchy's source to shipping an installer, so you can build your own Caelestia widgets.

## Features

- Live Mbps readings every second, 6 s download then 6 s upload
- Material 3 dials that follow your wallpaper colours, wobble while measuring, and rescale automatically (100 → 250 → 500 … 10000 Mbps)
- The final result is a steady-state average that leaves out TCP ramp-up
- Keeps running if you switch tabs or close the dashboard; **Stop** ends it right away
- History of your last 5 runs (in memory)
- No new packages. It only needs `curl`, `jq` and `ip`

## Requirements

- Caelestia shell **2.5.0** (tested). Other versions probably work, see [maintaining](docs/08-maintaining.md)
- `git`, `curl`, `jq`, `iproute2`

## Install

```sh
git clone https://github.com/<you>/caelestia-speedtest
cd caelestia-speedtest
./install.sh            # add --commit to commit it on your override's branch
```

The installer adds the tab to your **QML override** at `~/.config/quickshell/caelestia`. If you don't have an override yet, it creates one by cloning upstream Caelestia at the version you have installed. It never touches the system files in `/etc/xdg`. Read [docs/09-installing.md](docs/09-installing.md) for what it does step by step, how to install by hand, and troubleshooting.

Uninstall with `./uninstall.sh`.

## How it works

```
Dashboard tab (SpeedTestTab.qml)        just draws, can be unloaded at any time
        │ reads properties / calls start(), stop()
        ▼
SpeedTest service (SpeedTest.qml)       singleton: state, phases, averaging, history
        │ runs, reads stdout line by line
        ▼
assets/speedtest.sh down|up 6           8 parallel curl workers ⇄ Fast.com (Netflix) servers
                                        prints Mbps/s from /sys/class/net/<iface>/statistics
```

## Repository layout

| Path | What |
|---|---|
| `src/` | Files copied into the shell, mirroring its folder layout |
| `patches/dashboard-content.patch` | Registers the tab in `modules/dashboard/Content.qml` |
| `install.sh`, `uninstall.sh` | Installer and uninstaller |
| `scripts/check-snippets.py` | Checks that every solution in the tutorial is exact reference code (`python3 scripts/check-snippets.py`) |
| `docs/` | The tutorial |

## Credits & license

- The measuring method and `src/assets/speedtest.sh` are adapted from Omarchy's `omarchy-network-speedtest` (MIT, © David Heinemeier Hansson). See [NOTICE.md](NOTICE.md).
- It builds on, and patches, the Caelestia shell (GPL-3.0).
- This project is licensed under **GPL-3.0**, see [LICENSE](LICENSE).
