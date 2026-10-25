# Building a Caelestia widget: the speed test tutorial

This tutorial rebuilds the Speed test dashboard tab from nothing. It follows the path the original took: a feature spotted in another desktop (Omarchy), studied in that project's source, ported to a shell script, connected to Caelestia through a QML service, drawn as a dashboard tab, then packaged so anyone can install it.

You don't need prior QML experience. Some comfort with a terminal and basic programming (variables, functions, if/else) helps.

## Learning path

| # | Chapter | You'll learn |
|---|---|---|
| 1 | [How Caelestia is built](01-how-caelestia-works.md) | Quickshell, QML, the C++ plugin, where files live, what `shell.json` can and can't change |
| 2 | [Setting up an override fork](02-override-fork.md) | A git-tracked copy of the shell you can edit safely, with hot reload |
| 3 | [Studying Omarchy's implementation](03-studying-omarchy.md) | Reading someone else's source to find out how a feature really works |
| 4 | [The backend script](04-backend-script.md) | Measuring bandwidth with `curl` and kernel counters, plus clean shutdown |
| 5 | [The service singleton](05-service.md) | Running processes from QML, parsing output, keeping state alive |
| 6 | [The dashboard tab](06-dashboard-tab.md) | Registering a tab, layouts, design tokens, Material colours, dials |
| 7 | [Testing and debugging](07-testing-debugging.md) | Logs, IPC, screenshots, upstream's lint and format checks |
| 8 | [Maintaining and packaging](08-maintaining.md) | Rebasing on shell updates, packaging a widget as its own repo with a patch, an installer and an uninstaller |
| 9 | [Installing on a fresh Caelestia](09-installing.md) | Using the installer, installing by hand, troubleshooting |
| 10 | [Exercises](10-exercises.md) | Ideas to extend it: ping, saved history, a bar icon, a keybind |

Chapters 1–2 are setup you only do once. Chapters 3–6 build the feature. Chapters 7–9 cover testing, packaging and installing it. If you just want the tab, go to [chapter 9](09-installing.md).

## The finished files

Every chapter builds towards the files in [`../src`](../src):

```
src/
├── assets/speedtest.sh                 ← chapter 4
├── services/SpeedTest.qml              ← chapter 5
└── modules/dashboard/SpeedTestTab.qml  ← chapter 6
patches/dashboard-content.patch         ← the edit in chapter 6, step 1; the patch file in chapter 8
```

Chapters 4–6 are guided: you write the code yourself, and the answers stay hidden until you want them. Each chapter ends with a **Complete file** panel, and `src/` holds the same files, to `diff` against when you're done.

## How the guided chapters work

Most tasks look like this:

1. **"Your turn"** gives you a goal as a spec: what goes in, what comes out, the constraints, and how to check you're done (a command and its expected output, or what should appear on screen).
2. A **Toolbox**, when there is one, gives you facts you can't be expected to guess, like an API address, or which file to read for a component's properties.
3. **Try it first.** Getting stuck for a few minutes is part of learning it.
4. Then open the **hints one at a time**. Each one gets more specific.
5. Open the **solution** to compare, even if yours works. It explains *why* it's written that way.

Some tasks start from code that's deliberately broken ("Starting point, has a bug"). You run it, watch it fail, and work out why. Those are the debugging exercises.

**A solution panel always contains the exact reference code**, identical to `src/`. `scripts/check-snippets.py` checks that on every change. A line starting with `// ⋯` inside a solution is a placeholder or a note to you, not code.

## Conventions used here

- `~/.config/quickshell/caelestia` is called **the override** (or **your fork**).
- `/etc/xdg/quickshell/caelestia` is called **the system shell**. It's what the `caelestia-shell` package installs.
- Commands work in bash, zsh and fish unless marked otherwise.
- Versions: written against **caelestia-shell 2.5.0** and **Hyprland 0.56** in October 2026.
