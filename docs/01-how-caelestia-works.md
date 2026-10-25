# 1. How Caelestia is built

Before changing a program, you need a map of it. This chapter covers what Caelestia is made of, where each part lives on disk, and which parts you can change without a compiler.

## The layers

```
┌──────────────────────────────────────────────────────────────┐
│ Hyprland            the compositor: windows, workspaces, input│
├──────────────────────────────────────────────────────────────┤
│ Quickshell (qs)     a toolkit for building desktop shells in  │
│                     QML: bars, panels, popups as Wayland layers│
├──────────────────────────────────────────────────────────────┤
│ Caelestia shell     a Quickshell *config*: hundreds of .qml   │
│                     files + a compiled C++ plugin              │
├──────────────────────────────────────────────────────────────┤
│ ~/.config/caelestia/shell.json   your settings for it         │
└──────────────────────────────────────────────────────────────┘
```

- **Hyprland** has no bar, launcher or notifications of its own. It only manages windows.
- **Quickshell** (`qs`) is a program that runs QML files and gives them Wayland superpowers: layer-shell windows (things that sit above or below other windows, like a bar), access to Hyprland, PipeWire, MPRIS, system tray, notifications and more.
- **Caelestia** is one big Quickshell config. When you log in, `qs -c caelestia` runs. You can see it with `ps -o args= -C qs`.

## QML in 60 seconds

QML is a declarative language for user interfaces. You describe a tree of objects and their properties, and the UI updates itself when properties change.

```qml
Item {
    id: root
    property int count: 0

    Text {
        text: "Clicked " + root.count + " times"   // a *binding*: re-evaluated when count changes
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.count++                     // a *signal handler*: runs JavaScript
    }
}
```

Three ideas carry you a long way:

1. **Objects and properties.** `Item { width: 100 }`.
2. **Bindings.** `text: "…" + root.count` isn't assigned once. It stays live. Change `count` and the text updates. This is why our dial needs no code to redraw: its `value` is bound to the service's reading.
3. **Signal handlers.** `onClicked`, `onExited`, `onRead` are JavaScript that runs when something happens.

`id:` names an object so other objects in the same file can refer to it (`root.count`).

## Where Caelestia lives on disk

| Path | What it is | Edit it? |
|---|---|---|
| `/etc/xdg/quickshell/caelestia/` | The QML shipped by the `caelestia-shell` package | No, the package manager overwrites it |
| `/usr/lib/qt6/qml/Caelestia/` | The **compiled C++ plugin** (`libcaelestia-coreplugin.so`) | No, it's a binary |
| `~/.config/quickshell/caelestia/` | **Your override**, if it exists (chapter 2) | Yes, this is where we work |
| `~/.config/caelestia/shell.json` | Your settings | Yes |

When Quickshell starts `-c caelestia`, it looks for the config in `$XDG_CONFIG_HOME/quickshell/caelestia` (that is, `~/.config/…`) **first**, and only then in `/etc/xdg/…`. So a folder in your home directory fully replaces the system shell. Chapter 2 relies on this.

## The folders inside the shell

```
shell.qml          entry point: creates the bar, drawers, lock screen, …
modules/           UI pieces: bar/, dashboard/, launcher/, utilities/, …
services/          singletons with no UI: Audio, Nmcli, Recorder, Weather, …
components/        reusable widgets: StyledText, StyledRect, controls/IconButton, …
assets/            images, fonts, helper scripts
plugin/src/        source of the C++ plugin (only built when packaging)
```

Inside QML these folders are imported through Quickshell's `qs` root. `import qs.services` gives you every singleton in `services/`, and `import qs.components.controls` gives you the buttons and sliders. There's no registration file: dropping `services/SpeedTest.qml` into the folder makes `SpeedTest` available everywhere.

## What the C++ plugin provides

The plugin exposes QML modules you'll see imported at the top of nearly every file:

| Import | Gives you |
|---|---|
| `Caelestia.Config` | `Config` (your `shell.json` values) and `Tokens` (spacing, padding, rounding, fonts, sizes) |
| `Caelestia.I18n` | `Tr.tr("…")` for translatable strings |
| `Caelestia.Services`, `Caelestia.Components`, … | Fast native helpers such as CPU/GPU stats and the wavy line used in progress rings |

**The key limitation:** every `shell.json` key is declared in C++. For example, `plugin/src/Caelestia/Config/dashboardconfig.hpp` contains:

```cpp
CONFIG_PROPERTY(bool, showPerformance, true)
CONFIG_PROPERTY(bool, showWeather, true)
```

So you **can't add a new `shell.json` setting** like `dashboard.showSpeedTest` from QML. You'd have to rebuild the plugin, and from then on your QML and your plugin would have to stay in sync by hand. That's why our tab is always on (`enabled: true`) instead of being a setting. Keep this in mind when designing your own widgets: **QML-only changes are cheap, C++ changes are expensive.**

## Settings vs. code

| You want to… | Use |
|---|---|
| Hide a bar item, change clock format, toggle a dashboard tab that already exists | `shell.json` (no fork needed, hot-reloads) |
| Add a new widget, change how something looks or behaves | A QML override (chapter 2) |
| Add a new setting key or a new native feature | Rebuild the C++ plugin (out of scope) |

One `shell.json` gotcha: **arrays replace the defaults instead of merging into them.** Setting `"bar": { "entries": [ { "id": "logo", "enabled": false } ] }` leaves a bar with *only* that entry. Always write out the full list (the defaults are in the shell's README).

## Check yourself

**Why do edits to `/etc/xdg/quickshell/caelestia` get lost?**

<details>
<summary>Answer</summary>

That folder belongs to the `caelestia-shell` package. Every update or reinstall overwrites it with the packaged files.

</details>

**If you put a file at `~/.config/quickshell/caelestia/shell.qml`, which shell runs at your next login?**

<details>
<summary>Answer</summary>

Yours. Quickshell looks in `~/.config/quickshell/caelestia` first and only falls back to `/etc/xdg/…` if it's missing, so the folder in your home directory replaces the system shell completely.

</details>

**Why can't the speed test tab have its own on/off key in `shell.json`?**

<details>
<summary>Answer</summary>

Every `shell.json` key is declared in C++ (`CONFIG_PROPERTY(…)` in the plugin's `*config.hpp` files). Adding one means rebuilding the plugin and keeping your own build in sync with your QML from then on. A QML-only change can't add settings.

</details>

Next: [2. Setting up an override fork →](02-override-fork.md)
