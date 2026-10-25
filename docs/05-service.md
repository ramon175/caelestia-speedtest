# 5. The service singleton

**Goal:** a QML object that runs the script for download then upload, turns its output into properties (`downloadMbps`, `phase`, `error`…), and **keeps running even when nothing is on screen**.

You'll write `services/SpeedTest.qml` piece by piece. Each task gives you a spec; hints and solutions are in collapsed panels. The pieces aren't written in file order (you'll come back to `stop()` at the end), so the complete reference file is in a panel at the end of the chapter.

## Why a singleton, not code inside the tab?

Open `modules/dashboard/Content.qml` and look at how tabs are created (shortened):

```qml
delegate: Loader {
    sourceComponent: modelData.component
    Component.onCompleted: active = Qt.binding(() => {
        if (index === view.currentIndex)
            return true;
        ...                       // otherwise only while it's scrolling into view
    })
}
```

A `Loader` with `active: false` **destroys** its content. The dashboard unloads tabs you're not looking at, and the whole dashboard is destroyed when it closes. If the `Process` lived inside the tab, switching to the Media tab mid-test would kill it.

The fix is a pattern Caelestia already uses for `Recorder`, `Weather` and `Audio`: put state and logic in a **singleton service** in `services/`. There's exactly one instance for the whole shell, it lives as long as the shell does, and any file can use it via `import qs.services`. The tab becomes a thin view that reads properties.

**Rule of thumb:** if it has to survive UI coming and going, it belongs in `services/`.

One catch: singletons are created **lazily**, the first time something uses them. `modules/ServiceLoader.qml` exists for that reason. Its comment reads "Force certain singletons to load on shell init instead of lazily", and it does so just by naming them.

## The skeleton

Boilerplate, just type it. **Create `services/SpeedTest.qml`:**

<!-- file: src/services/SpeedTest.qml -->
**In `services/SpeedTest.qml`:**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

// Runs assets/speedtest.sh (Fast.com) for download then upload and exposes live readings.
// Lives in a singleton so a run survives the dashboard tab being unloaded.
Singleton {
    id: root

    // ⋯ everything in this chapter goes here, inside Singleton
}
```

- `pragma Singleton` plus a `Singleton { }` root makes it a singleton. Quickshell discovers it by file name, so `services/SpeedTest.qml` becomes `SpeedTest`.
- `Quickshell.Io` provides `Process`, `SplitParser` and `StdioCollector`. `Caelestia.I18n` provides `Tr`.
- The `// ⋯` line is a placeholder note, not code. Add each later piece above the closing `}`.

## Your test bench

There's no tab yet, so build a way to watch the service work with nothing on screen. This is temporary scaffolding.

1. Make the shell load the singleton at startup. In `modules/ServiceLoader.qml`, add one line to the list:

   ```qml
   Component.onCompleted: {
       // Force certain singletons to load on shell init instead of lazily

       SpeedTest; // TEST BENCH: remove when done
       IdleInhibitor;
       ...
   ```

2. Inside your `Singleton`, right after `id: root`, add:

   ```qml
   // TEST BENCH: remove when done
   Component.onCompleted: console.log("SpeedTest loaded")
   ```

3. Save and watch the log (the development loop from [chapter 2](02-override-fork.md#your-development-loop)):

   ```sh
   qs log --pid <PID> -f
   ```

   Expect a `DEBUG qml: SpeedTest loaded` line near `Configuration Loaded` (it can come just before it). You'll extend this bench as you go.

## The state

### Your turn: design the properties

Before writing logic, decide what the service exposes. The tab (chapter 6) will need to show:

- two live numbers: download and upload Mbps, updated every second
- which phase is running (download, upload or none), and whether anything is running
- an error message, if a run failed
- the network interface the script reported
- the dial's full scale (100, 250, 500 … Mbps), shared by both dials
- when the last run finished, and the last 5 runs (time, down, up)

Also needed: the length of each phase (6 s), the scale steps from chapter 3 (`100, 250, 500, 1000, 2500, 5000, 10000`), and internal storage for the current phase's readings and the script's stderr.

Write the `property` declarations. Decide carefully how to represent **"no value yet"** for a speed: what should the dial show before the first run?

<details>
<summary>Hint 1</summary>

Avoid two properties that can disagree. If you have `phase`, can "is it running?" be *computed* from it instead of stored?

</details>

<details>
<summary>Hint 2</summary>

`0` is a real speed, so it can't mean "nothing measured". JavaScript has a number value that means "not a number" and is easy to test with `isNaN()`. Typed lists exist: `list<int>`, `list<real>`, `list<var>`.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/services/SpeedTest.qml -->
**In `services/SpeedTest.qml`:**

```qml
    readonly property int phaseSeconds: 6
    // Full-scale latch points for the dials, as in Omarchy's overlay
    readonly property list<int> scaleStops: [100, 250, 500, 1000, 2500, 5000, 10000]

    property string phase: "" // "down" | "up" | ""
    readonly property bool running: phase !== ""
    property string iface
    property string error

    property real downloadMbps: NaN // Live reading while running, average once done
    property real uploadMbps: NaN
    property real fullScale: scaleStops[0]
    property date lastRun
    property list<var> history: [] // Newest first: { time, down, up }

    property list<real> samples: []
    property string stderrText
```

- **One source of truth.** `phase` says what's happening. `running` is *derived* from it with a binding, so the two can never disagree.
- **`NaN` means "no value yet".** The UI shows `--` instead of a misleading `0`.
- `readonly` on constants, so the UI can't change them by accident.
- **The last two are internal working state, not for the UI.** `samples` collects every reading of the current phase so `average()` can work on them. `stderrText` holds the script's error output until the process exits. The blank line separates them from the public properties above.
- `samples` is a `list<real>`, not `list<var>`: it only ever holds numbers (Mbps readings). A typed list says so to the next reader and to tools like `qmllint`, and matches how `average()` uses it. `history` needs `list<var>` because each entry is an object.

</details>

## Starting a run

### Your turn: write `start()` and `runPhase()`

**Toolbox.** `Quickshell.Io`'s `Process` has a `command` (a list of strings: the program, then its arguments) and a `running` property: set it to `true` to start, `false` to stop (which sends SIGTERM). `Quickshell.shellPath("assets/x")` gives the absolute path of a file inside your shell folder. You'll declare the `Process` (with `id: proc`) later in this chapter. Ids work anywhere in a file, regardless of order.

Spec:

- `start()`: does nothing if a run is already going. Otherwise it clears the error and both speeds (back to "no value"), resets the dial scale to the first step, and starts the download phase.
- `runPhase(next)`: sets `phase` to `next`, empties the readings and stderr from any earlier phase, and runs `assets/speedtest.sh <next> <phaseSeconds>`.

Also type this `stop()` for now. **Starting point, has a bug** you'll find at the end of the chapter:

```qml
    function stop(): void {
        proc.running = false;
    }
```

<details>
<summary>Hint 1</summary>

`start()` is mostly resetting properties you designed in the last task, then one call to `runPhase("down")`.

</details>

<details>
<summary>Hint 2</summary>

Build the command as a list, not one string: `[Quickshell.shellPath("assets/speedtest.sh"), next, String(phaseSeconds)]`. No shell is involved, so there's nothing to quote.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/services/SpeedTest.qml -->
**In `services/SpeedTest.qml`:**

```qml
    function start(): void {
        if (running)
            return;
        error = "";
        downloadMbps = NaN;
        uploadMbps = NaN;
        fullScale = scaleStops[0];
        runPhase("down");
    }
```

<!-- file: src/services/SpeedTest.qml -->
**In `services/SpeedTest.qml`:**

```qml
    function runPhase(next: string): void {
        phase = next;
        samples = [];
        stderrText = "";
        proc.command = [Quickshell.shellPath("assets/speedtest.sh"), next, String(phaseSeconds)];
        proc.running = true;
    }
```

- In the reference file `runPhase()` comes after `stop()`. Order doesn't matter to QML. Keeping `start`, `stop` and `runPhase` together makes them easy to read as one unit.
- `Quickshell.shellPath()` resolves relative to the shell folder, so it works wherever the override lives.
- Typed functions (`next: string): void`) aren't required, but upstream uses them and they let the QML compiler catch mistakes.

</details>

## The helpers

### Your turn: `setReading()`, `average()` and `formatMbps()`

Three small pure-ish functions. Write them, then test them with the bench.

**`setReading(value)`** stores a live reading in `downloadMbps` or `uploadMbps` depending on `phase`, and updates `fullScale`. The scale picks the first step the value fits under **with 8 % headroom** (`value <= step × 0.92`), and it **never shrinks** during a run. Above every step, use the last one.

| Start `fullScale` | Reading(s), in order | `fullScale` after |
|---|---|---|
| 100 | 50 | 100 |
| 100 | 92 | 100 |
| 100 | 93 | 250 |
| 100 | 50, 95 | 250 |
| 100 | 50, 95, 240 | 500 (240 > 250 × 0.92 = 230) |
| 100 | 50, 95, 240, 80 | 500 (never shrinks) |
| 500 | 460 | 500 |
| 500 | 461 | 1000 |
| 100 | 9500 | 10000 |

**`average()`** averages `samples`, **leaving out the first second** (TCP ramp-up). With only one sample, use it. With none, return "no value".

| `samples` | `average()` |
|---|---|
| `[20, 80, 82, 78]` | `80` |
| `[10, 30]` | `30` |
| `[50]` | `50` |
| `[]` | `NaN` |

**`formatMbps(value)`** turns a number into dial text: `--` for "no value", one decimal below 10, a whole number from 10 up.

| Input | Output |
|---|---|
| `NaN` | `"--"` |
| `0` | `"0.0"` |
| `7.25` | `"7.3"` |
| `10` | `"10"` |
| `812.4` | `"812"` |
| `812.6` | `"813"` |

Every expected value above was produced by running the reference functions in Quickshell.

To test, temporarily extend the bench's `Component.onCompleted`:

```qml
Component.onCompleted: {
    console.log("SpeedTest loaded");
    console.log(formatMbps(NaN), formatMbps(7.25), formatMbps(812.6)); // -- 7.3 813
    samples = [20, 80, 82, 78];
    console.log(average());                                           // 80
    phase = "down"; fullScale = 100;
    for (const v of [50, 95, 240, 80]) setReading(v);
    console.log(fullScale);                                           // 500
    phase = "";
}
```

<details>
<summary>Hint 1</summary>

For the scale, loop over `scaleStops` and return at the first step that fits. Use `Math.max` with the current `fullScale` so it can only grow. If the loop finishes without returning, the value is above every step.

</details>

<details>
<summary>Hint 2</summary>

- `average()`: `samples.slice(1)` drops the first element, and `reduce((a, b) => a + b, 0)` sums.
- `formatMbps()`: `toFixed(1)` gives one decimal as a string, and `Math.round(…).toString()` gives a whole number.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/services/SpeedTest.qml -->
**In `services/SpeedTest.qml`:**

```qml
    function setReading(value: real): void {
        if (phase === "down")
            downloadMbps = value;
        else if (phase === "up")
            uploadMbps = value;

        for (const scaleStop of scaleStops) {
            if (value <= scaleStop * 0.92) {
                fullScale = Math.max(fullScale, scaleStop);
                return;
            }
        }
        fullScale = scaleStops[scaleStops.length - 1];
    }

    function formatMbps(value: real): string {
        if (isNaN(value))
            return "--";
        return value < 10 ? value.toFixed(1) : Math.round(value).toString();
    }

    // The first second is TCP ramp-up, so leave it out of the result
    function average(): real {
        const steady = samples.length > 1 ? samples.slice(1) : samples;
        return steady.length ? steady.reduce((a, b) => a + b, 0) / steady.length : NaN;
    }
```

- **Scale latching** stops the dial from jumping between scales mid-test. Because both dials share one `fullScale`, download and upload stay visually comparable.
- **Why drop the first sample?** TCP starts slowly and speeds up over the first second ("slow start"). Including that second would drag the average down.
- `formatMbps` lives here, not in the tab, because both the dials and the history rows use it.
- A quirk you can find with one more test: `formatMbps(9.96)` gives `"10.0"`, because the `< 10` check runs before rounding. It's harmless (it shows for one second at most), so the reference keeps it simple. Fixing it is a good extra exercise.

</details>

Remove the helper tests from the bench when they pass. Keep the `SpeedTest loaded` line.

## Reading the script's output

Two `Quickshell.Io` helpers read a process's output:

- **`SplitParser`** fires `onRead` once per line, **as each line arrives**. That's what makes the dial move every second.
- **`StdioCollector`** gathers everything and gives you `text` once the stream ends (`onStreamFinished`). That suits stderr, where we only need the message once.

Remember chapter 4's protocol: `iface …` is metadata, and every other stdout line is a number.

### Your turn: declare the Process

Spec:

- A `Process` with `id: proc`.
- stdout, line by line: an `iface …` line sets `iface`. Any other line is a number: ignore it if it isn't one, or if no run is going. Otherwise append it to `samples` and pass it to `setReading()`.
- stderr: collect it all and store it, trimmed, in `stderrText`.
- Leave room for an `onExited` handler (next task).

<details>
<summary>Hint 1</summary>

`stdout: SplitParser { onRead: line => { … } }` and `stderr: StdioCollector { onStreamFinished: … }`. Inside the handlers, refer to the service's properties through `root.` to be explicit.

</details>

<details>
<summary>Hint 2</summary>

`line.startsWith("iface ")` and `line.slice(6)`. `parseFloat(line)` gives `NaN` for non-numbers. To append to a list property, build a new array and assign it: `root.samples = [...root.samples, value]`. Don't use `push()`.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/services/SpeedTest.qml -->
**In `services/SpeedTest.qml`:**

```qml
    Process {
        id: proc

        stdout: SplitParser {
            onRead: line => { // qmllint disable signal-handler-parameters
                if (line.startsWith("iface ")) {
                    root.iface = line.slice(6);
                    return;
                }
                const value = parseFloat(line);
                if (isNaN(value) || !root.running)
                    return;
                root.samples = [...root.samples, value];
                root.setReading(value);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.stderrText = text.trim()
        }

        // ⋯ onExited (next task) goes here: still inside Process { id: proc }, after stderr:
    }
```

- `root.samples = [...root.samples, value]` **reassigns** the list instead of calling `push()`. Changing a QML list property in place doesn't reliably notify bindings, and assigning a new array always does. Use this habit for every list property.
- The `// qmllint disable …` comment matches how upstream writes these handlers and keeps their linter quiet.
- The `// ⋯` line marks where the next task's code goes, inside `Process` and after `stderr:`.

</details>

## Handling the end of each phase

`onExited: code => { … }` runs whenever the script ends, with its exit code. This handler decides what happens next. That makes it a small **state machine**.

### Your turn: draw it first

On paper, draw the states (`""`, `"down"`, `"up"`) and every arrow between them. Label each arrow with what causes it and what the handler must do. Don't forget the two ways a phase can end badly.

<details>
<summary>Our state machine</summary>

```
            start()
   ""  ─────────────────►  "down"
   ▲ ▲                        │ exit 0:   downloadMbps = average(), runPhase("up")
   │ │                        ▼
   │ │   exit 0:            "up"
   │ └────────────────────────┘  uploadMbps = average(), lastRun, history, phase = ""
   │
   └── from "down" or "up":
         · exit ≠ 0  → error = stderr text (or "Speed test failed"), phase = ""
         · stop()    → phase = "", kill the script; onExited must do nothing
```

The last line is the tricky one: when *you* stop the script, `onExited` still runs. It needs a way to tell "the user stopped it" apart from "it finished" and "it failed".

</details>

### Your turn: write `onExited`

Spec: implement your diagram. On success after upload, record `lastRun` and put `{ time, down, up }` at the **front** of `history`, keeping at most 5 entries. If the script failed, show its stderr, or `Speed test failed` (translatable) if stderr was empty.

<details>
<summary>Hint 1</summary>

Handle the cases in order of priority, with early `return`s: first "nothing is running any more" (stopped by the user), then failure, then success.

</details>

<details>
<summary>Hint 2</summary>

`[{ time: …, down: …, up: … }, ...root.history].slice(0, 5)` puts the new entry first and trims the list. `Tr.tr("…")` makes a string translatable.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/services/SpeedTest.qml -->
**In `services/SpeedTest.qml`:**

```qml
        onExited: code => { // qmllint disable signal-handler-parameters
            if (!root.running)
                return; // Stopped by the user

            if (code !== 0) {
                root.error = root.stderrText || Tr.tr("Speed test failed");
                root.phase = "";
                return;
            }

            if (root.phase === "down") {
                root.downloadMbps = root.average();
                root.runPhase("up");
            } else {
                root.uploadMbps = root.average();
                root.phase = "";
                root.lastRun = new Date();
                root.history = [
                    {
                        time: root.lastRun,
                        down: root.downloadMbps,
                        up: root.uploadMbps
                    },
                    ...root.history].slice(0, 5);
            }
        }
```

- `if (!root.running) return;` is the "stopped by the user" check. It only works if `stop()` clears `phase`. Keep that in mind for the last task.
- `...root.history].slice(0, 5)`: the odd bracket placement is how `qmlformat` (chapter 7) formats it.

</details>

## Run it with nothing on screen

Extend the bench so the service runs a real test as soon as the shell loads, and logs what it sees. **Replace** the bench's `Component.onCompleted` line (an object can only set a handler once, so adding a second one is a "Property value set multiple times" error), and add two change loggers below it:

```qml
// TEST BENCH: remove when done
Component.onCompleted: {
    console.log("SpeedTest loaded");
    start();
}
onPhaseChanged: console.log("phase:", JSON.stringify(phase))
onErrorChanged: console.log("error:", error)
```

and, temporarily, as the first line inside `onRead`:

```qml
console.log("read:", line);
```

Save, and in `qs log --pid <PID> -f` you should see (your numbers will differ):

```
DEBUG qml: phase: "down"
DEBUG qml: read: iface enp5s0
DEBUG qml: read: 70.6
...
DEBUG qml: phase: "up"
...
DEBUG qml: phase: ""
```

Each save reloads the shell, which can start another 12-second test, so save sparingly while the bench is in.

## Debugging `stop()`

Now test Stop. Add a timer to the bench that presses it 3 seconds into a run:

```qml
Timer {
    interval: 3000
    running: true
    onTriggered: root.stop()
}
```

Save and watch the log. With the starting-point `stop()` you typed earlier, you'll see:

```
DEBUG qml: phase: "down"
DEBUG qml: read: iface enp5s0
DEBUG qml: read: 71.1
DEBUG qml: read: 73.6
DEBUG qml: error: Speed test failed
DEBUG qml: phase: ""
```

The user pressed Stop, and the tab would say the test **failed**.

### Your turn: why does Stop report a failure? Fix it.

Done when the same bench logs `phase: "down"`, a couple of readings, then `phase: ""`, with **no** `error:` line.

<details>
<summary>Hint 1</summary>

`onExited` runs for *every* exit, including the one you caused. Walk through your handler with the values it sees at that moment: what is `code`, and what is `root.running`?

</details>

<details>
<summary>Hint 2</summary>

The script exits with 143 when stopped (chapter 4), which isn't 0. And `phase` is still `"down"`, so `running` is still true and the handler takes the error path. What could `stop()` change *before* killing the script, so that the first check in `onExited` catches it?

</details>

<details>
<summary>Solution</summary>

<!-- file: src/services/SpeedTest.qml -->
**In `services/SpeedTest.qml`:**

```qml
    function stop(): void {
        // Clear the phase before killing: onExited would otherwise advance to upload
        phase = "";
        proc.running = false;
    }
```

- Clearing `phase` makes `running` false, so `onExited` returns at its first check: "stopped by the user".
- **Why clear it first?** In Quickshell, `onExited` is delivered later from the event loop, so in our tests `proc.running = false; phase = "";` also worked. Clearing `phase` first doesn't rely on that timing: whenever `onExited` runs, the state already says "stopped".
- The comment in the reference code says the handler "would otherwise advance to upload". That's the risk if the script ever exits 0 at the same moment (a race at the very end of a phase). The failure you saw, exit 143 going down the error branch, is the common case. The fix covers both.

</details>

## Clean up the bench

Remove every `TEST BENCH` line: the `SpeedTest;` line in `modules/ServiceLoader.qml`, `Component.onCompleted`, the two `on…Changed` loggers, the `Timer`, and the `console.log` in `onRead`. Then compare with the reference:

```sh
git diff modules/ServiceLoader.qml          # should show nothing
diff services/SpeedTest.qml ~/Projects/caelestia-speedtest/src/services/SpeedTest.qml
```

The `diff` will only show ordering differences (`runPhase()` before or after `stop()`), if any.

<details>
<summary>Complete file</summary>

<!-- file: src/services/SpeedTest.qml complete -->
**In `services/SpeedTest.qml`:**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

// Runs assets/speedtest.sh (Fast.com) for download then upload and exposes live readings.
// Lives in a singleton so a run survives the dashboard tab being unloaded.
Singleton {
    id: root

    readonly property int phaseSeconds: 6
    // Full-scale latch points for the dials, as in Omarchy's overlay
    readonly property list<int> scaleStops: [100, 250, 500, 1000, 2500, 5000, 10000]

    property string phase: "" // "down" | "up" | ""
    readonly property bool running: phase !== ""
    property string iface
    property string error

    property real downloadMbps: NaN // Live reading while running, average once done
    property real uploadMbps: NaN
    property real fullScale: scaleStops[0]
    property date lastRun
    property list<var> history: [] // Newest first: { time, down, up }

    property list<real> samples: []
    property string stderrText

    function start(): void {
        if (running)
            return;
        error = "";
        downloadMbps = NaN;
        uploadMbps = NaN;
        fullScale = scaleStops[0];
        runPhase("down");
    }

    function stop(): void {
        // Clear the phase before killing: onExited would otherwise advance to upload
        phase = "";
        proc.running = false;
    }

    function runPhase(next: string): void {
        phase = next;
        samples = [];
        stderrText = "";
        proc.command = [Quickshell.shellPath("assets/speedtest.sh"), next, String(phaseSeconds)];
        proc.running = true;
    }

    function setReading(value: real): void {
        if (phase === "down")
            downloadMbps = value;
        else if (phase === "up")
            uploadMbps = value;

        for (const scaleStop of scaleStops) {
            if (value <= scaleStop * 0.92) {
                fullScale = Math.max(fullScale, scaleStop);
                return;
            }
        }
        fullScale = scaleStops[scaleStops.length - 1];
    }

    function formatMbps(value: real): string {
        if (isNaN(value))
            return "--";
        return value < 10 ? value.toFixed(1) : Math.round(value).toString();
    }

    // The first second is TCP ramp-up, so leave it out of the result
    function average(): real {
        const steady = samples.length > 1 ? samples.slice(1) : samples;
        return steady.length ? steady.reduce((a, b) => a + b, 0) / steady.length : NaN;
    }

    Process {
        id: proc

        stdout: SplitParser {
            onRead: line => { // qmllint disable signal-handler-parameters
                if (line.startsWith("iface ")) {
                    root.iface = line.slice(6);
                    return;
                }
                const value = parseFloat(line);
                if (isNaN(value) || !root.running)
                    return;
                root.samples = [...root.samples, value];
                root.setReading(value);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.stderrText = text.trim()
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (!root.running)
                return; // Stopped by the user

            if (code !== 0) {
                root.error = root.stderrText || Tr.tr("Speed test failed");
                root.phase = "";
                return;
            }

            if (root.phase === "down") {
                root.downloadMbps = root.average();
                root.runPhase("up");
            } else {
                root.uploadMbps = root.average();
                root.phase = "";
                root.lastRun = new Date();
                root.history = [
                    {
                        time: root.lastRun,
                        down: root.downloadMbps,
                        up: root.uploadMbps
                    },
                    ...root.history].slice(0, 5);
            }
        }
    }
}
```

</details>

## Translation

Visible strings go through `Tr.tr("…")` from `Caelestia.I18n`, like everywhere else in the shell. Untranslated strings simply show as English.

## Check yourself

**Why can't the `Process` live inside the dashboard tab?**

<details>
<summary>Answer</summary>

The dashboard creates tabs with a `Loader` that's only active while the tab is visible, and it destroys the whole dashboard when it closes. Destroying the tab would destroy the `Process`, killing the test mid-run. A singleton lives as long as the shell.

</details>

**What happens if `stop()` only sets `proc.running = false`?**

<details>
<summary>Answer</summary>

`onExited` runs with exit code 143 while `phase` still says a run is going, so the handler treats it as a failure and shows "Speed test failed". Clearing `phase` in `stop()` lets the handler's first check recognise a user stop.

</details>

**Why would `root.samples.push(value)` be a bug waiting to happen?**

<details>
<summary>Answer</summary>

Changing a QML list property in place doesn't reliably emit its change signal, so bindings that depend on it may not update. Assigning a new array (`root.samples = [...root.samples, value]`) always notifies.

</details>

**Why does a new singleton need a line in `ServiceLoader.qml` for the test bench, but not once the tab exists?**

<details>
<summary>Answer</summary>

Singletons are created lazily, the first time something refers to them. Until the tab exists, nothing refers to `SpeedTest`, so it would never be created and its `Component.onCompleted` would never run. Naming it in `ServiceLoader.qml` forces creation at startup. Later, the tab refers to it when you open the Speed test tab.

</details>

Next: [6. The dashboard tab →](06-dashboard-tab.md)
