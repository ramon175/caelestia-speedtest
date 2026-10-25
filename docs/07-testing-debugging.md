# 7. Testing and debugging

Quickshell gives no popup when your QML is broken. It logs and carries on (or shows an empty space). This chapter is the toolbox for seeing what's going on.

## Test from the bottom up

Test each layer on its own before the layer above it uses it:

1. **Script:** run it in a terminal (chapter 4, "Test it"). Numbers, exit codes, no leftover `curl`.
2. **Service:** save it and check the log for parse errors.
3. **Tab:** open it, look at it, click it.

When something breaks in the tab, step 1 tells you straight away whether the problem is in the script or in QML.

## Reading the shell's log

You've been using the log since [chapter 2's development loop](02-override-fork.md#your-development-loop): `qs list --all` for the PID, `qs log --pid <PID> -f` to follow it, and `Configuration Loaded` after each save. Here's how to read what appears after it. Anything mentioning **your** files (`SpeedTest.qml`, `SpeedTestTab.qml`) is yours to fix. Typical messages:

| Message | Usual cause |
|---|---|
| `X is not a type` | Misspelled component, or a missing `import qs.components…` |
| `Cannot assign to non-existent property "foo"` | Typo, or the property only exists in a newer shell version |
| `ReferenceError: SpeedTest is not defined` | Missing `import qs.services`, or the file isn't named `SpeedTest.qml` |
| `Unable to assign [undefined] to …` right after a reload, in files you didn't touch | Old objects being torn down during hot reload. Harmless |
| `Binding loop detected` | A property depends on itself, often a size bound to its own content |

Some warnings exist in a stock shell too (a missing `~/.face` avatar, for example). Note what's in the log **before** you change anything, so you only chase new messages.

**Important:** tab content is created by a `Loader` only when you open the tab. Errors inside `SpeedTestTab.qml` won't appear until you actually open the Speed test tab. A clean reload proves the file *parses*, not that it *works*.

## Driving the shell from the terminal (IPC)

Caelestia exposes functions over Quickshell IPC:

```sh
qs ipc --pid <PID> show                          # list every target and function
qs ipc --pid <PID> call drawers toggle dashboard # open or close the dashboard
```

That's handy for screenshots and for scripting your own tests.

## Screenshots

```sh
qs ipc --pid <PID> call drawers toggle dashboard
sleep 1; grim /tmp/dash.png
qs ipc --pid <PID> call drawers toggle dashboard
```

On multi-monitor setups, `grim` captures every output. Find the focused one and crop to it:

```sh
hyprctl monitors -j | jq -r '.[] | "\(.name) \(.x),\(.y) \(.width)x\(.height) scale=\(.scale) focused=\(.focused)"'
grim -o DP-1 /tmp/dash.png                       # or capture just that output
```

## Lint and format like upstream

Upstream's CI (`.github/workflows/check-format.yml`) runs two checks on every QML file. Run them yourself so your code matches the shell's style:

```sh
cd ~/.config/quickshell/caelestia

# 1. qmlformat: no output means the file is already formatted
/usr/lib/qt6/bin/qmlformat services/SpeedTest.qml | diff -u services/SpeedTest.qml -
/usr/lib/qt6/bin/qmlformat -i services/SpeedTest.qml          # or fix it in place

# 2. Upstream's naming and structure conventions
python3 scripts/qml-lint-conventions.py --file services/SpeedTest.qml
python3 scripts/qml-lint-conventions.py --file modules/dashboard/SpeedTestTab.qml
```

`qmlformat` comes with `qt6-declarative`, so you already have it. While developing this tab, it reformatted the `history` array's closing bracket. That's the kind of detail a reviewer would notice if you ever sent a pull request upstream.

## Editor support

`/usr/lib/qt6/bin/qmlls` is the QML language server (completion, go-to-definition, errors as you type). Most editors (VS Code/VSCodium with the Qt extension, Zed, Neovim's LSP) can use it. The fork already has a `.vscode/` folder from upstream.

## A debugging checklist

1. Is the right instance running? `qs list --all`: one instance, Config path inside `~/.config`.
2. Did the config reload? Look for `Configuration Loaded` after your save.
3. Does the script work alone? `assets/speedtest.sh down 3`
4. Is the script executable? `ls -l assets/speedtest.sh` should show `x`. The service runs it directly, not through `bash`, so without the executable bit it can't start at all. (`install.sh` sets it, and git keeps it once committed.)
5. Add a temporary `console.log("phase", phase)` in the service, and read it in `qs log`.
6. Undo everything with `git stash` and see if the problem goes away.

Next: [8. Maintaining your fork →](08-maintaining.md)
