# 3. Studying Omarchy's implementation

The idea came from [Omarchy](https://github.com/basecamp/omarchy), DHH's Arch + Hyprland setup, which has a speed test with two dials. Before writing any code we want to know **how it measures**. Blog posts and AI summaries are often vague or wrong about details like this. The source code is the only reliable answer.

This chapter has no code to write. You'll read someone else's code and decide what to keep, which is half of building anything.

## Step 1: get the source without the history

```sh
mkdir -p ~/src && cd ~/src
git clone --depth 1 --branch quattro https://github.com/basecamp/omarchy.git
cd omarchy
git log -1 --format='%h %cd'      # note which version you're reading
```

- `--depth 1` downloads only the latest snapshot. That's much smaller, and you don't need the history to read code.
- `quattro` was the active development branch for Omarchy 4.x when this was written. Check the repo's branch list if it has moved on.

> Treat downloaded code as something to **read**, not run. We only use `grep` and `cat` here.

## Step 2: search for the feature

```sh
grep -rIil speedtest . | grep -v '^./.git/'
```

`-r` recursive, `-I` skip binary files, `-i` ignore case, `-l` print only file names. Among the results:

```
bin/omarchy-network-speedtest               ← a script: the measuring logic
shell/plugins/panels/speedtest/Panel.qml    ← the panel that runs it
shell/plugins/panels/speedtest/manifest.json
shell/Ui/SpeedTestOverlay.qml               ← the dials
manual/35-networking.md                     ← user docs
```

That split is already a design lesson: **the measuring is a plain shell script, and the UI only runs it and draws numbers.** We'll copy that design.

## Step 3: read the backend

### Your turn: take notes on the script

Open `bin/omarchy-network-speedtest` (about 130 lines) and read it top to bottom. Write down, in your own words, the five things it does, in order. For each one, note **which command or file** it uses.

Done means you could explain to someone else, without the code in front of you, where the test servers come from, what generates the traffic, and where the Mbps number comes from.

<details>
<summary>Hint</summary>

Look for the boundaries: each `if`/`fi` block, each function and the main loop at the end usually does one job. Run the interesting one-liners yourself (`ip route get 1.1.1.1`, `cat /sys/class/net/*/statistics/rx_bytes`) to see what they print.

</details>

<details>
<summary>Compare with our notes</summary>

1. **Find the interface.** `ip route get 1.1.1.1` asks the kernel which network device would carry traffic to the internet, and awk pulls out the word after `dev` (for example `enp5s0`).
2. **Get test servers.** It calls `https://api.fast.com/netflix/speedtest/v2?…&token=…&urlCount=3`. That's the API the fast.com website itself uses, with its public token. It returns JSON with URLs on Netflix's Open Connect cache servers close to you. `jq -r '.targets[]?.url'` extracts them.
3. **Generate traffic.** It starts **8 background workers**. Each one loops forever: download a test file (`curl -o /dev/null`), or for upload, `POST` 64 MB of zeros from `dd`.
4. **Measure, separately.** Once per second it reads `/sys/class/net/<iface>/statistics/rx_bytes` (or `tx_bytes`), takes the difference from the previous second, and prints `(bytes × 8) / 1,000,000`, which is megabits per second.
5. **Clean up.** `trap cleanup EXIT` kills the workers when the script ends.

</details>

## Step 4: read the UI side

In `shell/plugins/panels/speedtest/Panel.qml`, search for the parts that matter:

```sh
grep -nE 'command|interval|phase' shell/plugins/panels/speedtest/Panel.qml
```

It runs `omarchy-network-speedtest down`, and a **5-second timer** kills it and starts `up`. So the script itself never stops; the UI decides when. From `shell/Ui/SpeedTestOverlay.qml`:

```qml
property var scaleStops: [100, 250, 500, 1000, 2500, 5000, 10000]
```

Both dials share a full-scale value that latches upward through these steps as the speed rises.

## Step 5: decide what to keep and what to change

### Your turn: keep or change?

Copy this table into your notes and fill in the last two columns. Think about what happens when things go wrong (a crash, a slow first second), not only the happy path.

| Omarchy does | Keep? | Why |
|---|---|---|
| Fast.com servers, 8 parallel workers | | |
| Count bytes at the network card | | |
| Script runs until the UI kills it | | |
| `omarchy-cmd-present curl` | | |
| Shows the last 1-second reading as the result | | |
| Scale steps 100 → 10000 | | |

<details>
<summary>Hint</summary>

Two of the rows are about robustness: ask "what if the shell crashes mid-test?" and "is one second of TCP a fair sample?". One row only exists because of Omarchy's own helpers.

</details>

<details>
<summary>Compare with our table</summary>

| Omarchy does | Keep? | Why |
|---|---|---|
| Fast.com servers, 8 parallel workers | ✅ | Parallel streams fill fast links. A single connection (like `speedtest-cli`) often under-reports above ~300 Mbps |
| Count bytes at the network card | ✅ | Counts all 8 workers together, plus protocol overhead, so it's what the line really carried |
| Script runs until killed | ❌ | If the shell crashes mid-test, 8 uploads keep running forever. **Our script stops itself after N seconds** |
| `omarchy-cmd-present curl` | ❌ | An Omarchy helper we don't have. Use `command -v` |
| Shows the last 1-second reading as the result | ❌ | Noisy. **We average the steady seconds**, dropping the first (TCP ramp-up) |
| Scale steps | ✅ | Good UX, copied as-is |

</details>

## Step 6: check the license

```sh
head -3 LICENSE        # MIT, (c) David Heinemeier Hansson
```

MIT lets you copy and modify the code as long as you keep the copyright notice. That's why `src/assets/speedtest.sh` names its origin and [`NOTICE.md`](../NOTICE.md) has the full license. Caelestia is GPL-3.0, and since our files patch and build on it, this repo is GPL-3.0 too. MIT code can be included in GPL projects, but not the other way round.

## Alternatives we considered

| Backend | Pros | Cons |
|---|---|---|
| **Fast.com via curl** (chosen) | No packages, live per-second numbers, multi-stream | Relies on an unofficial web token that could change; no ping or jitter |
| Ookla `speedtest` (AUR `ookla-speedtest-bin`) | Official, JSON output with ping, jitter, ISP and server | AUR package and a license prompt; you only get the final number after ~25 s |
| `speedtest-cli` (extra repo) | Official repos | Single connection, often too low on fast links |

## Check yourself

**Why does reading `rx_bytes` give a better number than adding up curl's own speed reports?**

<details>
<summary>Answer</summary>

`rx_bytes` is one kernel counter for everything the network card received. It covers all 8 workers at once, with no adding up and no timing mismatch between them, and it includes protocol overhead, so it reflects what the line actually carried. curl's reports are per process, and each one averages over its own transfer time.

</details>

**What would happen to your upload if the shell crashed while Omarchy's script was running?**

<details>
<summary>Answer</summary>

It would keep going. Omarchy's script only stops when the UI kills it. With the UI gone, the 8 workers keep posting 64 MB blocks forever, using your upload bandwidth until you kill them by hand. That's why our script stops itself after N seconds.

</details>

Next: [4. The backend script →](04-backend-script.md)
