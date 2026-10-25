# 6. The dashboard tab

**Goal:** a new **Speed test** tab after Performance, with two dials, a status card with a Run/Stop button, and a short history. It has to look like it shipped with Caelestia.

## The target

This is what you're building (left to right, top to bottom):

```
┌───────────────────────────┐ ┌───────────────────────────┐
│ ⬇ Download                │ │ ⬆ Upload                  │   two dial cards
│         ╭───────╮         │ │         ╭───────╮         │   · 270° ring, gap at the bottom
│        │   74    │        │ │        │   19    │        │   · big number + "Mbps"
│         ╰ Mbps ╯          │ │         ╰ Mbps ╯          │   · "max 100" in the gap
│          max 100          │ │          max 100          │
└───────────────────────────┘ └───────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ ⓘ  Last run at 14:30                   [ ⟳ Run again ]  │   status card
│    Fast.com via enp5s0                                  │
└─────────────────────────────────────────────────────────┘
   14:21                             ⬇ 71   ⬆ 18 Mbps         history rows
```

Everything uses the wallpaper's Material colours: download in the primary colour, upload in the secondary colour.

## How this chapter works

The file stays **valid after every step**. Step 3 gives you a skeleton with every brace closed and placeholder comments (`// ⋯ step 4: …`). Each later step replaces one placeholder, and ends with a **checkpoint**: what you should see when you open the Speed test tab. If the checkpoint doesn't match, fix it before moving on. The log (chapter 2's development loop) tells you why.

Tasks follow the usual pattern: try, open hints one at a time, then compare with the solution. The complete reference file is in a panel at the end.

## Step 1: register the tab

**Create `modules/dashboard/SpeedTestTab.qml`** as a stub, so the type exists before anything refers to it:

```qml
import QtQuick

Item {
    implicitWidth: 400
    implicitHeight: 200
}
```

### Your turn: register it like Performance

Open `modules/dashboard/Content.qml` and find how the **Performance** tab is registered. Register `SpeedTestTab` the same way, right after Performance, with the label "Speed test" and the Material Symbols icon `network_check`. It has no `shell.json` setting (chapter 1 explains why), so it should always be enabled.

**Checkpoint:** a **Speed test** tab appears after Performance, and clicking it shows an empty area.

<details>
<summary>Hint 1</summary>

Search the file for `performance`. It appears in **two** places: once in a list of tab descriptions, and once where the actual component is declared.

</details>

<details>
<summary>Hint 2</summary>

Each entry in `dashboardTabs` points at a `Component` by id (`performanceComponent`). You need a new entry *and* a new `Component { id: …; SpeedTestTab {} }` next to the others.

</details>

<details>
<summary>Solution</summary>

**a) Add an entry to `dashboardTabs`**, after Performance:

```qml
{
    component: performanceComponent,
    iconName: "speed",
    text: Tr.tr("Performance"),
    enabled: Config.dashboard.showPerformance
},
{
    component: speedTestComponent,
    iconName: "network_check",
    text: Tr.tr("Speed test"),
    enabled: true // No config key: the C++ config plugin would need a rebuild
},
```

**b) Add the matching `Component`**, next to the others inside the `Flickable`:

```qml
Component {
    id: speedTestComponent

    SpeedTestTab {}
}
```

- `iconName` is a [Material Symbols](https://fonts.google.com/icons) name. Caelestia renders icons with that font, so any name from the site works. Performance already uses `speed`.
- `SpeedTestTab` needs no import. QML automatically sees every file in the same folder as a type.
- That's why the stub came first: without the file, saving `Content.qml` fails with `SpeedTestTab is not a type` in the log.

Turning this `Content.qml` edit into a reusable patch file is part of packaging, in [chapter 8](08-maintaining.md#packaging-your-widget-as-a-repo).

</details>

## Step 2: learn the house style before drawing anything

Don't invent your own look. Open the files closest to what you're building and borrow from them:

| File | Borrowed |
|---|---|
| `modules/utilities/cards/IdleInhibit.qml` | Card layout: rounded surface, icon, title and subtitle, control on the right |
| `modules/dashboard/performance/HeroCard.qml` | `CircularProgress` used as a gauge, the big-number font |
| `components/controls/CircularProgress.qml` | Its properties: `startAngle`, `sweepAngle`, `wavy`, `clampedVal` |
| `components/controls/IconTextButton.qml` + `modules/nexus/pages/network/AddVpnPage.qml` | Pill buttons with custom colours |

### Where the names come from

The tab uses names you didn't define. Each comes from one of the imports at the top of the file:

| Name | Import | Defined in |
|---|---|---|
| `Colours` | `qs.services` | `services/Colours.qml` |
| `SpeedTest` | `qs.services` | `services/SpeedTest.qml` (chapter 5) |
| `StyledText`, `StyledRect`, `MaterialIcon`, `Anim` | `qs.components` | `components/*.qml` |
| `CircularProgress`, `IconTextButton` | `qs.components.controls` | `components/controls/*.qml` |
| `Tokens`, `Config` | `Caelestia.Config` | The C++ plugin (`plugin/src/Caelestia/Config/`) |
| `Tr`, `Units` | `Caelestia.I18n` | The plugin's `Tr.qml` and `Units.qml` (`plugin/src/Caelestia/I18n/`) |
| `ColumnLayout`, `RowLayout`, `Layout.*` | `QtQuick.Layouts` | Qt |

`Tokens` and `Config` are *attached* types (see `configattached.hpp` and `tokensattached.hpp`), so they attach to whatever object uses them and can follow per-screen settings. That's why you can use them anywhere without an id.

### Design tokens

Use the **design tokens** instead of hard-coded numbers. Tokens are defined in `plugin/src/Caelestia/Config/tokens.hpp`:

```sh
grep -n "CONFIG_PROPERTY" plugin/src/Caelestia/Config/tokens.hpp | head -40
grep -rhoE "Tokens\.font\.[a-z]+\.[a-zA-Z]+" modules | sort | uniq -c | sort -rn   # what's actually used
```

| Use | Instead of |
|---|---|
| `Tokens.spacing.medium` (12), `Tokens.padding.large` (16) | `12`, `16` |
| `Tokens.rounding.large`, `.extraLarge`, `.full` | `radius: 20` |
| `Tokens.font.body.small`, `.title.medium`, `.icon.large` | `font.pixelSize: 14` |
| `Colours.palette.m3primary`, `.m3onSurfaceVariant`, `.m3error` | `"#88c0d0"` |
| `Colours.tPalette.m3surfaceContainer` | Card backgrounds (respects the transparency setting) |

`Colours.palette` is a **Material 3** palette generated from your wallpaper. Use the role names (`primary`, `onPrimary`, `secondaryContainer`, `error`…) and the tab will restyle itself on every wallpaper change, in light and dark mode, for free.

### Gotcha: `MaterialIcon` takes `fontStyle:`, not `font:`

`MaterialIcon` draws one Material Symbols glyph by name (`text: "download"`). It looks like a `StyledText`, but its size is set differently:

```qml
StyledText { font: Tokens.font.body.small }            // text: font:
MaterialIcon { fontStyle: Tokens.font.icon.large }     // icons: fontStyle:
```

`MaterialIcon` builds its real `font` itself from `fontStyle`, its `fill` and its `grade` (see `components/MaterialIcon.qml`). If you set `font:` directly, you replace that computed font and the icon loses its icon-font settings. Always use `fontStyle:` with a `Tokens.font.icon.*` value.

## Step 3: the skeleton

Boilerplate, just type it. **Replace the stub's contents** in `modules/dashboard/SpeedTestTab.qml` with:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    function formatTime(time: date): string {
        return Qt.formatTime(time, Units.twelveHourClock ? "h:mm a" : "hh:mm");
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        // ⋯ step 4: the dial row goes here
        // ⋯ step 5: the status card goes here
        // ⋯ step 6: the history rows go here
    }

    // ⋯ step 7 replaces this stub with the real Dial
    component Dial: StyledRect {
        required property string icon
        required property string label
        required property real value
        required property bool measuring
        required property color accent

        implicitWidth: 260
        implicitHeight: 260

        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer
    }
}
```

- `pragma ComponentBehavior: Bound` is used at the top of upstream files. It makes delegates declare their model data explicitly (`required property var modelData`), which catches mistakes early.
- **`implicitWidth`/`implicitHeight` are required.** `Content.qml` sizes the whole dashboard from the current tab's implicit size (`implicitWidth: currentItem?.implicitWidth`). Ours takes its size from the `ColumnLayout`, which grows as you fill it.
- `Units.twelveHourClock` follows your `services.clockFormat` setting (`Auto`, `TwelveHour` or `TwentyFourHour`).
- The `ColumnLayout` stacks its children in this order: **dial row → status card → history**.
- **`component Dial`** is an *inline component*: a small reusable type declared inside this file, after the `ColumnLayout`, at the bottom of the root `Item`. For now it's a stub, just an empty card with the five properties a dial will need, so `Dial` exists from the start. Step 7 replaces it.

**Checkpoint:** the Speed test tab opens with no errors in the log. It looks empty and small, because the layout has no children yet.

## Step 4: the dial row

### Your turn: two dials side by side

Replace the `// ⋯ step 4` placeholder with a row of two `Dial`s:

| | Download | Upload |
|---|---|---|
| `icon` | `download` | `upload` |
| `label` | "Download" (translatable) | "Upload" (translatable) |
| `value` | the service's download speed | the service's upload speed |
| `measuring` | true while the download phase runs | true while the upload phase runs |
| `accent` | the palette's primary colour | the palette's secondary colour |

Every value must be a **binding** to `SpeedTest`, so the tab never needs update code. Use the medium spacing token between the dials.

**Checkpoint:** two empty rounded cards side by side.

<details>
<summary>Hint</summary>

`RowLayout { spacing: Tokens.spacing.medium; Dial { … } Dial { … } }`. The phase check is a comparison: `SpeedTest.phase === "down"`.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
        RowLayout {
            spacing: Tokens.spacing.medium

            Dial {
                icon: "download"
                label: Tr.tr("Download")
                value: SpeedTest.downloadMbps
                measuring: SpeedTest.phase === "down"
                accent: Colours.palette.m3primary
            }

            Dial {
                icon: "upload"
                label: Tr.tr("Upload")
                value: SpeedTest.uploadMbps
                measuring: SpeedTest.phase === "up"
                accent: Colours.palette.m3secondary
            }
        }
```

- `required property` in the stub makes forgetting one of the five values an error instead of a silent blank.
- The same two accent colours come back in the history rows (step 6), so the user learns "primary = download" once.

</details>

## Step 5: the status card

### Your turn: copy the card recipe

Open `modules/utilities/cards/IdleInhibit.qml` ("Keep awake" in the utilities panel). Copy its card recipe for a status card under the dials:

- as wide as the dial row
- large rounding and the surface-container background (transparency-aware)
- height from its content plus large padding on both sides
- inside: a row with large margins and medium spacing, starting with a large status icon: `error` in the error colour when `SpeedTest.error` is set, otherwise `network_check` in the primary colour
- leave two placeholders in the row: `// ⋯ step 5b: the two text lines go here` and `// ⋯ step 5c: the button goes here`

**Checkpoint:** a full-width card under the dials with a `network_check` icon on the left.

<details>
<summary>Hint 1</summary>

The card's height depends on the row inside it, so give the row an id and use its `implicitHeight`. Then the row can fill the card with margins.

</details>

<details>
<summary>Hint 2</summary>

The size flows in two directions. The card's height is the row's `implicitHeight` plus the padding twice (top and bottom). The row, in turn, fills the card and keeps the same padding as margins. In `IdleInhibit.qml`, look for which property of the outer rectangle refers to its inner layout's id. And remember the gotcha: icons take `fontStyle:`.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: statusRow.implicitHeight + Tokens.padding.large * 2

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: statusRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: SpeedTest.error ? "error" : "network_check"
                    color: SpeedTest.error ? Colours.palette.m3error : Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                // ⋯ step 5b: the two text lines go here
                // ⋯ step 5c: the button goes here
            }
        }
```

- `Layout.fillWidth: true` makes the card as wide as the dial row above it.
- Height from content plus padding, with the row filling the card inside the same margins, is the pattern `IdleInhibit.qml` uses.

</details>

### Your turn: the status text

Replace `// ⋯ step 5b` with two lines of text stacked with no spacing, taking all the spare width in the row.

**Line 1** is a **single binding** that shows the most important message, in this priority order:

1. the error, if there is one (in the error colour)
2. "Measuring download…" during the download phase
3. "Measuring upload…" during the upload phase
4. "Last run at <time>" if there has been a run (use `root.formatTime(SpeedTest.lastRun)`)
5. "Ready to test"

Otherwise use the normal on-surface colour, with the medium body font.

**Line 2** shows the interface the test used: "Fast.com via enp5s0", or just "Fast.com" before the first run. Use the variant colour and small body font.

Both lines are translatable, and long text must be cut with `…`, not push the button off the card.

**Checkpoint:** "Ready to test" and "Fast.com" next to the icon.

<details>
<summary>Hint 1</summary>

A binding can be a whole block: `text: { if (…) return …; if (…) return …; return …; }`. The first `return` that runs wins, which gives you the priority order for free.

</details>

<details>
<summary>Hint 2</summary>

Put the placeholder inside the translatable string and fill it in afterwards: `Tr.tr("Last run at %1").arg(…)`. Cutting text is `elide: Text.ElideRight`, which only works when the text has a width limit (`Layout.fillWidth: true`).

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (SpeedTest.error)
                                return SpeedTest.error;
                            if (SpeedTest.phase === "down")
                                return Tr.tr("Measuring download…");
                            if (SpeedTest.phase === "up")
                                return Tr.tr("Measuring upload…");
                            if (SpeedTest.history.length > 0)
                                // TRANSLATORS: %1 = a clock time, e.g. 14:30
                                return Tr.tr("Last run at %1").arg(root.formatTime(SpeedTest.lastRun));
                            return Tr.tr("Ready to test");
                        }
                        color: SpeedTest.error ? Colours.palette.m3error : Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        // TRANSLATORS: %1 = a network interface name, e.g. enp5s0
                        text: SpeedTest.iface ? Tr.tr("Fast.com via %1").arg(SpeedTest.iface) : Tr.tr("Fast.com")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }
```

- "Has there been a run?" is `SpeedTest.history.length > 0`. `lastRun` alone can't tell you, because a `date` property always holds some value.
- Keeping `%1` inside the translatable string lets translators move it within the sentence. The `TRANSLATORS:` comments are how upstream gives translators context.
- The second line is the **interface line** promised in chapter 4: `Fast.com via enp5s0`, or `via tun0` with a VPN. It reads `SpeedTest.iface`, which the service fills from the script's `iface …` line.

</details>

### Your turn: the button

Replace `// ⋯ step 5c` with a round `IconTextButton` (open `components/controls/IconTextButton.qml` for its properties, and `modules/nexus/pages/network/AddVpnPage.qml` for one with custom colours). Large horizontal and small vertical padding. Everything else depends on the state:

| State | Icon | Label | Background / text colour | Click |
|---|---|---|---|---|
| Running | `stop` | Stop | error container / on error container | `SpeedTest.stop()` |
| Idle, never run | `play_arrow` | Run test | primary / on primary | `SpeedTest.start()` |
| Idle, has run before | `replay` | Run again | primary / on primary | `SpeedTest.start()` |

**Checkpoint:** click **Run test**. The status line shows "Measuring download…", then "Measuring upload…", then "Last run at …", and the button changes label each time. (The dials are still empty stubs.)

<details>
<summary>Hint 1</summary>

`IconTextButton` has `inactiveColour` and `inactiveOnColour` for its normal background and content colours, plus `icon`, `text`, `isRound` and `onClicked`.

</details>

<details>
<summary>Hint 2</summary>

Pair each background with its matching "on" colour (`m3errorContainer` with `m3onErrorContainer`, `m3primary` with `m3onPrimary`). Material guarantees those pairs are readable on any wallpaper. Two-level choices fit in one line with nested `? :`.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
                IconTextButton {
                    isRound: true
                    horizontalPadding: Tokens.padding.large
                    verticalPadding: Tokens.padding.small
                    inactiveColour: SpeedTest.running ? Colours.palette.m3errorContainer : Colours.palette.m3primary
                    inactiveOnColour: SpeedTest.running ? Colours.palette.m3onErrorContainer : Colours.palette.m3onPrimary
                    icon: SpeedTest.running ? "stop" : (SpeedTest.history.length > 0 ? "replay" : "play_arrow")
                    text: SpeedTest.running ? Tr.tr("Stop") : (SpeedTest.history.length > 0 ? Tr.tr("Run again") : Tr.tr("Run test"))
                    onClicked: SpeedTest.running ? SpeedTest.stop() : SpeedTest.start()
                }
```

- One button, three states, all bindings. The table you were given is exactly what the bindings encode.

</details>

## Step 6: history rows

Before writing anything, think about this: the history row list will use `SpeedTest.history.slice(1)`, not `SpeedTest.history`. **Why skip the first entry?**

<details>
<summary>Answer</summary>

`history` is newest first, and the newest run is already on screen: in the dials and in the status line's "Last run at …". Listing it again below would show the same numbers twice. `slice(1)` shows only the *earlier* runs.

</details>

### Your turn: one row per earlier run

Replace `// ⋯ step 6` with a `Repeater` over `SpeedTest.history.slice(1)`. Each row, in small body text with small spacing and large left and right margins:

```
14:21                                  ⬇ 71   ⬆ 18 Mbps
```

- the time (variant colour) takes all the spare width, pushing the rest to the right
- a small `download` icon in the primary colour, then the download value
- a small `upload` icon in the secondary colour, with a little extra space before it, then the upload value
- "Mbps" in the variant colour

Format the times with `root.formatTime()` and the numbers with `SpeedTest.formatMbps()`.

**Checkpoint:** run the test twice. After the second run, one row shows the first run's numbers.

<details>
<summary>Hint 1</summary>

With `pragma ComponentBehavior: Bound`, a delegate must declare `required property var modelData` to receive its entry. Give the delegate an id so its children can use `entry.modelData.time`.

</details>

<details>
<summary>Hint 2</summary>

`Layout.fillWidth: true` on the time text pushes everything after it right. "A little extra space" before the upload icon is `Layout.leftMargin: Tokens.spacing.small` on that icon.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
        Repeater {
            model: SpeedTest.history.slice(1)

            delegate: RowLayout {
                id: entry

                required property var modelData

                Layout.leftMargin: Tokens.padding.large
                Layout.rightMargin: Tokens.padding.large
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.formatTime(entry.modelData.time)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                MaterialIcon {
                    text: "download"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: SpeedTest.formatMbps(entry.modelData.down)
                    font: Tokens.font.body.small
                }

                MaterialIcon {
                    Layout.leftMargin: Tokens.spacing.small
                    text: "upload"
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: SpeedTest.formatMbps(entry.modelData.up)
                    font: Tokens.font.body.small
                }

                StyledText {
                    text: "Mbps"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }
```

- The large left and right margins line the rows up with the text inside the status card.
- "Mbps" never translates, so it isn't wrapped in `Tr.tr`.

</details>

## Step 7: the Dial component

### Your turn: replace the stub

Replace the stub `component Dial` (and its `// ⋯` comment) with the real one. Keep the five required properties and the card look (extra-large rounding, surface container), but:

- **width 260**, and **height from content** plus large padding, like the status card
- inside, a column with large margins and small spacing
- first in the column, a header row (small spacing): a medium icon (`dial.icon`) and the label (`dial.label`) in the medium title font, both in `dial.accent`
- leave a placeholder after the header: `// ⋯ step 8: the gauge goes here`

**Checkpoint:** the two cards are now short, with "⬇ Download" and "⬆ Upload" headers in their accent colours.

<details>
<summary>Hint 1</summary>

To refer to the dial's own properties from inside, give the root of the component an id: `component Dial: StyledRect { id: dial … }`, then use `dial.accent`.

</details>

<details>
<summary>Hint 2</summary>

Use the same height trick as the status card in step 5: the card measures the layout inside it, and the layout fills the card with matching margins. Only the width stays fixed.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
    component Dial: StyledRect {
        id: dial

        required property string icon
        required property string label
        required property real value
        required property bool measuring
        required property color accent

        implicitWidth: 260
        implicitHeight: dialLayout.implicitHeight + Tokens.padding.large * 2

        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: dialLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            RowLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: dial.icon
                    color: dial.accent
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    text: dial.label
                    color: dial.accent
                    font: Tokens.font.title.medium
                }
            }

            // ⋯ step 8: the gauge goes here
        }
    }
```

- Same card recipe as the status card, with a slightly rounder corner (`extraLarge`) like `HeroCard`.
- The header uses `Tokens.font.icon.medium` via `fontStyle:` for the icon and `Tokens.font.title.medium` via `font:` for the label.

</details>

## Step 8: turn a progress ring into a gauge

### Your turn: the ring

Replace `// ⋯ step 8` with a `CircularProgress` (id `gauge`), centred horizontally, 190 pixels across, with a small-padding stroke in `dial.accent`. Open `components/controls/CircularProgress.qml`, find its angle properties, and answer:

> A speedometer is a **270° arc with the gap at the bottom**. In `CircularProgress`, 0° points **right** (3 o'clock) and angles increase **clockwise**. What are `startAngle` and `sweepAngle`?

Then:

- `value` is 0 to 1: the dial's speed divided by the service's shared `fullScale`, or 0 when there's no value yet
- wavy while this dial is measuring
- the needle should **glide** between the once-per-second readings, not jump (look at how `HeroCard.qml` animates its ring)
- leave two placeholders inside the ring: `// ⋯ step 8b: the number goes here` and `// ⋯ step 8c: the scale label goes here`

**Checkpoint:** an empty ring under each header with a gap at the bottom. During a run the download ring wobbles and fills, then the upload ring does.

<details>
<summary>Hint 1</summary>

Sketch a clock face. 0° is at 3 o'clock, 90° at 6, 180° at 9, 270° at 12. A 90° gap centred on 6 o'clock runs from 45° to 135°. The arc must start where the gap ends.

</details>

<details>
<summary>Hint 2</summary>

The animated property in `CircularProgress` is `clampedVal` (it's the one actually drawn). `HeroCard.qml` uses `Behavior on clampedVal { Anim {} }`. "No value yet" is `NaN`, so test with `isNaN(dial.value)`.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
            CircularProgress {
                id: gauge

                Layout.alignment: Qt.AlignHCenter
                implicitSize: 190

                // A 270° dial with the gap at the bottom
                startAngle: 135
                sweepAngle: 270
                strokeWidth: Tokens.padding.small
                fgColour: dial.accent
                value: isNaN(dial.value) ? 0 : dial.value / SpeedTest.fullScale
                wavy: dial.measuring

                Behavior on clampedVal {
                    Anim {}
                }

                // ⋯ step 8b: the number goes here
                // ⋯ step 8c: the scale label goes here
            }
```

- Starting at 135° (bottom-left, about 7:30) and sweeping 270° clockwise ends at 45° (bottom-right, about 4:30), leaving a 90° gap at the bottom.
- Dividing by the shared `fullScale` keeps both dials on the same scale.
- `wavy` uses the ring's built-in wavy animation (the same one the media player uses).
- `Anim` is Caelestia's animation with the shell's standard easing.

</details>

### Your turn: the number

Replace `// ⋯ step 8b` with the speed and its unit, **centred in the ring** and stacked with no spacing:

- the speed via `SpeedTest.formatMbps(dial.value)`, in a large headline font scaled up 1.5×, with its width narrowed to 80 so `1000` fits
- its colour: full on-surface while measuring **or** once there's a value, dimmed (variant) while it still shows `--`
- "Mbps" under it, in the small body font and the variant colour

**Checkpoint:** each ring shows a dimmed `--` and "Mbps". During a run the numbers brighten and count.

<details>
<summary>Hint 1</summary>

`anchors.centerIn: parent` on a `ColumnLayout`. Each text gets `Layout.alignment: Qt.AlignHCenter`.

</details>

<details>
<summary>Hint 2</summary>

Fonts like this are made with a **font builder**: `Tokens.font.headline.builders.large.scale(…).width(…).build()`. Search `modules/` for `headline.builders` to see it in use.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: SpeedTest.formatMbps(dial.value)
                        color: dial.measuring || !isNaN(dial.value) ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.headline.builders.large.scale(1.5).width(80).build()
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Mbps"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }
```

- The dimmed placeholder makes an idle dial read as "empty" instead of showing a fake value.
- The builder starts from the large headline token, `scale(1.5)` enlarges it, `width(80)` narrows the variable font's width axis, and `build()` makes the font. `HeroCard`'s usage label uses the same builder with different values.

</details>

### Your turn: the scale label

Replace `// ⋯ step 8c` with a translatable "max %1" label showing `SpeedTest.fullScale`, centred horizontally at the **bottom** of the ring (in the gap), in the small label font and the variant colour. Add a `TRANSLATORS:` comment saying what `%1` is.

**Checkpoint:** "max 100" sits in each ring's gap, and it changes (250, 500…) during a fast run.

<details>
<summary>Hint</summary>

`anchors.horizontalCenter: parent.horizontalCenter` and `anchors.bottom: parent.bottom`, where the parent is the gauge.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    // TRANSLATORS: %1 = the dial's full-scale speed, e.g. 500
                    text: Tr.tr("max %1").arg(SpeedTest.fullScale)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
```

- The gap at the bottom of the ring is free space by design, so it's the natural place for a caption.

</details>

That's the whole tab. Compare your file with the reference:

```sh
diff modules/dashboard/SpeedTestTab.qml ~/Projects/caelestia-speedtest/src/modules/dashboard/SpeedTestTab.qml
```

The only differences should be the `// ⋯` placeholder lines, if you left them in. Delete them.

<details>
<summary>Complete file</summary>

<!-- file: src/modules/dashboard/SpeedTestTab.qml complete -->
**In `modules/dashboard/SpeedTestTab.qml`:**

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    function formatTime(time: date): string {
        return Qt.formatTime(time, Units.twelveHourClock ? "h:mm a" : "hh:mm");
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.medium

            Dial {
                icon: "download"
                label: Tr.tr("Download")
                value: SpeedTest.downloadMbps
                measuring: SpeedTest.phase === "down"
                accent: Colours.palette.m3primary
            }

            Dial {
                icon: "upload"
                label: Tr.tr("Upload")
                value: SpeedTest.uploadMbps
                measuring: SpeedTest.phase === "up"
                accent: Colours.palette.m3secondary
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: statusRow.implicitHeight + Tokens.padding.large * 2

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: statusRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: SpeedTest.error ? "error" : "network_check"
                    color: SpeedTest.error ? Colours.palette.m3error : Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (SpeedTest.error)
                                return SpeedTest.error;
                            if (SpeedTest.phase === "down")
                                return Tr.tr("Measuring download…");
                            if (SpeedTest.phase === "up")
                                return Tr.tr("Measuring upload…");
                            if (SpeedTest.history.length > 0)
                                // TRANSLATORS: %1 = a clock time, e.g. 14:30
                                return Tr.tr("Last run at %1").arg(root.formatTime(SpeedTest.lastRun));
                            return Tr.tr("Ready to test");
                        }
                        color: SpeedTest.error ? Colours.palette.m3error : Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        // TRANSLATORS: %1 = a network interface name, e.g. enp5s0
                        text: SpeedTest.iface ? Tr.tr("Fast.com via %1").arg(SpeedTest.iface) : Tr.tr("Fast.com")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }

                IconTextButton {
                    isRound: true
                    horizontalPadding: Tokens.padding.large
                    verticalPadding: Tokens.padding.small
                    inactiveColour: SpeedTest.running ? Colours.palette.m3errorContainer : Colours.palette.m3primary
                    inactiveOnColour: SpeedTest.running ? Colours.palette.m3onErrorContainer : Colours.palette.m3onPrimary
                    icon: SpeedTest.running ? "stop" : (SpeedTest.history.length > 0 ? "replay" : "play_arrow")
                    text: SpeedTest.running ? Tr.tr("Stop") : (SpeedTest.history.length > 0 ? Tr.tr("Run again") : Tr.tr("Run test"))
                    onClicked: SpeedTest.running ? SpeedTest.stop() : SpeedTest.start()
                }
            }
        }

        Repeater {
            model: SpeedTest.history.slice(1)

            delegate: RowLayout {
                id: entry

                required property var modelData

                Layout.leftMargin: Tokens.padding.large
                Layout.rightMargin: Tokens.padding.large
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.formatTime(entry.modelData.time)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                MaterialIcon {
                    text: "download"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: SpeedTest.formatMbps(entry.modelData.down)
                    font: Tokens.font.body.small
                }

                MaterialIcon {
                    Layout.leftMargin: Tokens.spacing.small
                    text: "upload"
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: SpeedTest.formatMbps(entry.modelData.up)
                    font: Tokens.font.body.small
                }

                StyledText {
                    text: "Mbps"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }
    }

    component Dial: StyledRect {
        id: dial

        required property string icon
        required property string label
        required property real value
        required property bool measuring
        required property color accent

        implicitWidth: 260
        implicitHeight: dialLayout.implicitHeight + Tokens.padding.large * 2

        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: dialLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            RowLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: dial.icon
                    color: dial.accent
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    text: dial.label
                    color: dial.accent
                    font: Tokens.font.title.medium
                }
            }

            CircularProgress {
                id: gauge

                Layout.alignment: Qt.AlignHCenter
                implicitSize: 190

                // A 270° dial with the gap at the bottom
                startAngle: 135
                sweepAngle: 270
                strokeWidth: Tokens.padding.small
                fgColour: dial.accent
                value: isNaN(dial.value) ? 0 : dial.value / SpeedTest.fullScale
                wavy: dial.measuring

                Behavior on clampedVal {
                    Anim {}
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: SpeedTest.formatMbps(dial.value)
                        color: dial.measuring || !isNaN(dial.value) ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.headline.builders.large.scale(1.5).width(80).build()
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Mbps"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    // TRANSLATORS: %1 = the dial's full-scale speed, e.g. 500
                    text: Tr.tr("max %1").arg(SpeedTest.fullScale)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }
}
```

</details>

## Check yourself

**Why did the stub `SpeedTestTab.qml` have to exist before you edited `Content.qml`?**

<details>
<summary>Answer</summary>

`Content.qml` refers to the type `SpeedTestTab`. QML resolves type names when it loads the file, so with hot reload, saving `Content.qml` before the type existed would fail with `SpeedTestTab is not a type`.

</details>

**Why does the skeleton include a stub `component Dial`?**

<details>
<summary>Answer</summary>

So the file is valid at every step. The dial row in step 4 uses `Dial`, so without a stub it would fail with `Dial is not a type` until step 7. The stub has the same five required properties, so step 4's bindings are already checked.

</details>

**Why does the tab contain no code that updates the dials?**

<details>
<summary>Answer</summary>

Every visible value is a binding to a `SpeedTest` property. When the service changes `downloadMbps`, `phase` or `fullScale`, QML re-evaluates the bindings that depend on them. The tab only describes what to show.

</details>

**Open the dashboard, start a run and switch to the Media tab, then back. Why is the run still going?**

<details>
<summary>Answer</summary>

Switching tabs destroys the Speed test tab's content, but the run lives in the `SpeedTest` singleton (chapter 5), which outlives every tab. When the tab is recreated, its bindings pick up the current state.

</details>

**Change your wallpaper. What changes in the tab, and why didn't you have to write anything for it?**

<details>
<summary>Answer</summary>

The dials, icons, button and text colours all follow the new palette, because every colour is a `Colours.palette` role (`m3primary`, `m3onSurface`…), never a fixed colour. Caelestia regenerates the palette from the wallpaper, and the bindings follow.

</details>

Next: [7. Testing and debugging →](07-testing-debugging.md)
