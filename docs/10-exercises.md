# 10. Exercises

The best way to make this knowledge stick is to extend the widget. The exercises go roughly from easy to hard, and each comes with hints rather than solutions.

## 1. Change the test length (easy)

Make each phase 10 seconds instead of 6.

*Hint:* one property in `services/SpeedTest.qml`. Why does nothing in the script need to change?

<details>
<summary>One possible solution</summary>

Change `readonly property int phaseSeconds: 6` to `10`. `runPhase()` passes `String(phaseSeconds)` to the script as its second argument, and the script's measuring loop runs for exactly that many seconds. The script never had its own idea of the duration, so it needs no change. That's the payoff of passing settings in as arguments instead of hard-coding them in two places.

</details>

## 2. Show the peak speed (easy)

Under each dial's number, show "peak 812" (the highest second of that phase).

*Hint:* add `downloadPeak`/`uploadPeak` to the service and update them in `setReading()`. Reset them in `start()`. Add a `required property real peak` to `Dial`.

<details>
<summary>One possible solution</summary>

In the service, add `property real downloadPeak: NaN` and `property real uploadPeak: NaN`, and set both back to `NaN` in `start()` next to the speeds. In `setReading()`, inside the `phase === "down"` branch, set `downloadPeak = isNaN(downloadPeak) ? value : Math.max(downloadPeak, value)`, and do the same for upload. (`Math.max(NaN, x)` is `NaN`, which is why the first reading needs the `isNaN` check.)

In the tab, give `Dial` a fifth required property, `peak`, and pass `SpeedTest.downloadPeak` or `SpeedTest.uploadPeak` from the dial row. Inside the gauge's centre `ColumnLayout`, after "Mbps", add a small `StyledText` with `Tr.tr("peak %1").arg(SpeedTest.formatMbps(dial.peak))` and `visible: !isNaN(dial.peak)`, so it only appears once there's a reading.

</details>

## 3. Add latency (medium)

Fast.com's servers can also give a rough ping. Add a `ping` phase to the script that prints one number in milliseconds, then run it before `down`.

*Hints:*
- `curl -o /dev/null -s -w '%{time_connect}\n' "$url"` prints the TCP connect time in seconds. Take the median of 5 tries and multiply by 1000.
- In the service, the state machine becomes `"" → ping → down → up → ""`. Draw it first.
- Where should latency appear in the UI? A third dial is overkill. Try a chip in the status card, like the "Active since" chip in `modules/utilities/cards/IdleInhibit.qml`.

<details>
<summary>One possible solution</summary>

**Script:** accept `ping` in the `case` alongside `down | up`. After fetching the server URLs, if the direction is `ping`, run `curl -o /dev/null -s -w '%{time_connect}\n'` against the first URL five times, sort the results, take the middle one, print it × 1000 with awk (for example `12.4`), and `exit 0` before any workers start. Test it by hand: `assets/speedtest.sh ping` should print the `iface` line and one number.

**Service:** add `property real pingMs: NaN`, reset it in `start()`, and make `start()` call `runPhase("ping")` instead of `"down"`. In `onRead`, store a number in `pingMs` when `phase === "ping"` instead of passing it to `setReading()`. In `onExited`, add a branch first: on success after `ping`, `runPhase("down")`. Everything after that is unchanged. The state machine now reads `"" → ping → down → up → ""`, with the same two side exits.

**Tab:** add `"Measuring latency…"` to the status-line priorities, between the error and the download phase. Show the result as a small rounded chip (`StyledRect` with `radius: Tokens.rounding.full` and a `StyledText` inside) in the status card, with `visible: !isNaN(SpeedTest.pingMs)`, reading "12 ms".

</details>

## 4. Keep history across reloads (medium)

Hot reloads and shell restarts currently wipe the history.

*Hints:*
- **Survive hot reloads:** wrap the state in `PersistentProperties { reloadableId: "speedtest" }`, as `services/Recorder.qml` does.
- **Survive restarts:** save to a JSON file. Look at how `services/` files use `FileView` from `Quickshell.Io` to read and write files, and store it under `~/.local/state/caelestia/`. Remember that `Date` objects become strings in JSON.

## 5. A keybind to run a test (medium)

Run a test with a key without opening the dashboard, and get a notification with the result.

*Hints:*
- Quickshell's `IpcHandler { target: "speedtest"; function start(): void { … } }` exposes functions to `qs ipc call speedtest start`. Look at how upstream defines its `drawers` target: `grep -rn "IpcHandler" modules services`.
- Bind it in Hyprland: `hl.bind("SUPER + SHIFT + S", …)` in your user config, running `qs ipc call speedtest start`.
- Notify with `notify-send` from a `Process` when the `up` phase ends.

## 6. A bar indicator (medium)

While a test runs, show a small `network_check` icon in the bar that pulses.

*Hint:* bar entries live in `modules/bar/`. Look at how status icons are built and shown or hidden. This changes another upstream file, so keep the edit small (chapter 8).

## 7. Swap the backend (medium)

Add Ookla as an alternative. Ookla doesn't stream per-second numbers, but `speedtest --format=json` gives final download, upload, ping, jitter, ISP and server.

*Hints:* write `assets/speedtest-ookla.sh` that prints lines in **the same protocol** (`iface …`, numbers), plus new metadata lines like `ping 12.3`. If the protocol stays the same, how much QML needs to change?

## 8. A real config option (hard)

Add `dashboard.showSpeedTest` to `shell.json`.

*Hints:* that means adding `CONFIG_PROPERTY(bool, showSpeedTest, true)` in `plugin/src/Caelestia/Config/dashboardconfig.hpp` and building the plugin from your fork (see upstream's `CMakeLists.txt` and README). From then on you maintain a custom build instead of using the package's plugin. Decide whether a toggle is worth that.

## 9. Send it upstream (open-ended)

Read Caelestia's contributing guidelines and open an issue proposing the feature before writing a PR. Maintainers may prefer a different design (a config key, a utilities card, a different backend). Run the format and lint checks from chapter 7 before submitting anything.

---

Built something? Share it, and open a PR to this repo if it's generally useful.
