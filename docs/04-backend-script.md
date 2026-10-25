# 4. The backend script

**Goal:** `assets/speedtest.sh down|up [seconds]` prints the network interface once, then one Mbps reading per second, then exits by itself and leaves no processes behind.

```
$ assets/speedtest.sh down 3
iface enp5s0
70.5
73.8
73.8
```

Why a separate script instead of doing it all in QML? A script can be **tested on its own in a terminal**, it's easy to swap later (Ookla, iperf…), and the shell only has to read lines of text.

**Create `assets/speedtest.sh`** in your fork and build it part by part. Each part is a small task: try it yourself, open the hints one at a time if you're stuck, then open the solution to compare. The whole reference file is in a panel at the end of the chapter.

## The protocol

The QML side (chapter 5) reads the script's output line by line, so agree on the format first:

- **stdout** carries data only: one line `iface <name>`, then one number per line (Mbps, one decimal).
- **stderr** carries error messages. The tab shows them to the user.
- The **exit code** is 0 on success, non-zero on failure.

## Part 1: arguments and safety

### Your turn: parse the arguments

Spec:

- Usage: `speedtest.sh down|up [seconds]`.
- Any first argument other than `down` or `up` prints `Usage: speedtest.sh down|up [seconds]` **to stderr** and exits with code **2**.
- `seconds` defaults to **5**.
- Stop at the first failing command.
- Also define the settings later parts use: probe address `1.1.1.1`, 8 parallel workers, 3 server URLs.
- Start the file with a comment saying what it is, how to use it, and that it's adapted from Omarchy (MIT asks you to keep the credit).

Done when:

```sh
assets/speedtest.sh sideways; echo "exit=$?"   # Usage: … then exit=2
assets/speedtest.sh down; echo "exit=$?"       # nothing yet, exit=0
```

(Run `chmod +x assets/speedtest.sh` once first.)

<details>
<summary>Hint 1</summary>

Bash has a construct that matches a value against patterns, with `|` meaning "or" and `*` meaning "anything else".

</details>

<details>
<summary>Hint 2</summary>

`case "$direction" in down | up) ;; *) … ;; esac`. For the default, `${2:-5}` means "argument 2, or 5 if it's missing". `>&2` sends an `echo` to stderr.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/assets/speedtest.sh -->
**In `assets/speedtest.sh`:**

```bash
#!/bin/bash

# Live internet speed test for one direction against Fast.com (Netflix OCA) nodes.
# Adapted from Omarchy's omarchy-network-speedtest (MIT, (c) David Heinemeier Hansson).
#
# Usage: speedtest.sh down|up [seconds]
# Output: "iface <name>" once, then one Mbps reading per second until done.

set -e

direction="${1:-}"
duration="${2:-5}"
probe=1.1.1.1
parallel=8
url_count=3

case "$direction" in
  down | up) ;;
  *)
    echo "Usage: speedtest.sh down|up [seconds]" >&2
    exit 2
    ;;
esac
```

- The header comment says where the code came from. Omarchy's MIT license asks you to keep that credit.
- `set -e` exits as soon as any command fails, so it won't carry on with half-broken state.
- `${1:-}` makes a missing argument an empty string, which falls through to `*)`.
- Errors go to **stderr** (`>&2`), so stdout stays pure data for the QML side.

</details>

## Part 2: dependencies and interface

First, an experiment. Ask the kernel how it would reach the internet, and how it would reach your router (find its address with `ip route | grep default`):

```sh
ip route get 1.1.1.1
# 1.1.1.1 via 192.168.1.254 dev enp5s0 src 192.168.1.155 uid 1000
ip route get 192.168.1.254
# 192.168.1.254 dev enp5s0 src 192.168.1.155 uid 1000
```

The device name you want sits after the word `dev`.

### Your turn: find the interface

Spec:

- Exit with an error (stderr, code 1) if `curl`, `jq` or `ip` is missing: `<command> is required`.
- Find which network device carries internet traffic (use the probe address from part 1).
- If there's none, or it has no byte counters in `/sys/class/net/<iface>/statistics/rx_bytes`, print `No active network interface` to stderr and exit 1.
- Otherwise print `iface <name>` to stdout.

Done when `assets/speedtest.sh down` prints `iface enp5s0` (or your device).

<details>
<summary>Hint 1</summary>

Compare the two `ip route get` outputs above. In which field position is the device name each time? What does that tell you about `cut -d' ' -f5`?

</details>

<details>
<summary>Hint 2</summary>

Don't count fields, search them: an awk loop over `$1 … $NF` that prints the field after the one equal to `dev`. `command -v name` tells you whether a command exists. `[[ -r file ]]` tests that a file is readable.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/assets/speedtest.sh -->
**In `assets/speedtest.sh`:**

```bash
for cmd in curl jq ip; do
  if ! command -v "$cmd" >/dev/null; then
    echo "$cmd is required" >&2
    exit 1
  fi
done

iface=$(ip route get "$probe" 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

if [[ -z $iface || ! -r /sys/class/net/$iface/statistics/rx_bytes ]]; then
  echo "No active network interface" >&2
  exit 1
fi

echo "iface $iface"
```

- `dev` is field 5 with a `via` gateway and field 3 without one, so a fixed `cut -f5` breaks. The awk loop finds `dev` wherever it is and prints the next field.
- **VPN note:** with a VPN up, the route goes through the tunnel device (`tun0`, `wg0`…), so you measure *through the VPN*. That's usually what you want, and it's why the tab shows which interface it used.
- `echo "iface $iface"` is the first half of the protocol: a line starting with `iface ` is metadata, and every other line is a number.

</details>

## Part 3: fetch test servers

### Your turn: get the server list

**Toolbox.** You can't guess these, so here they are. Fast.com's own web page uses this API and public token:

```
https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=3
```

First run it by hand and look at the JSON:

```sh
curl -s "https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=3" | jq .
```

Spec:

- Put the token in a variable and use `url_count` from part 1 in the URL.
- Extract **just the test URLs**, one per line, with no quotes, into a variable `fast_urls`.
- Don't let a dead network hang the script: give up after 10 seconds.
- If you got no URLs, print `Failed to fetch speed test endpoints` to stderr and exit 1.

Done when `echo "$fast_urls"` (add it temporarily) prints three `https://…` lines.

<details>
<summary>Hint 1</summary>

Find the URLs in the JSON you printed. They live in a list. What's the list called?

</details>

<details>
<summary>Hint 2</summary>

`jq -r '.targets[] | .url'` walks the list and prints each `url` raw (`-r` means no quotes). Then make it robust: `[]?` doesn't fail if `targets` is missing, and `// empty` prints nothing instead of `null`. For curl, look up `-f`, `-sS` and `--max-time`.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/assets/speedtest.sh -->
**In `assets/speedtest.sh`:**

```bash
fast_token="YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm"
fast_urls=$(curl -fsS --max-time 10 "https://api.fast.com/netflix/speedtest/v2?https=true&token=$fast_token&urlCount=$url_count" 2>/dev/null | jq -r '.targets[]?.url // empty')

if [[ -z $fast_urls ]]; then
  echo "Failed to fetch speed test endpoints" >&2
  exit 1
fi
```

- `curl -f` fails on HTTP errors, `-sS` is silent but still shows errors, and `--max-time 10` means a dead network can't hang us. (Omarchy's version has no timeout.)
- `.targets[]?.url // empty` is the short form of the hint's filter, and it degrades to "no output" (so the `-z` check fires) instead of printing `null`.

</details>

## Part 4: a first cleanup (starting point, has a bug)

The workers in part 5 run in the background. Something has to stop them when the script ends. Here's the obvious version. **Type it in as-is.** It has a bug you'll find in part 7.

> **Starting point, has a bug.** This is not the final code.

```bash
traffic_pids=()

trap 'kill "${traffic_pids[@]}"' EXIT
```

- `traffic_pids` will hold the PID of each worker.
- `trap … EXIT` runs a command whenever the script exits.
- Until you fix it in part 7, test runs can leave `curl` processes behind. Clear them with `pkill -x curl` whenever you see your bandwidth stay busy.

## Part 5: the workers

### Your turn: generate traffic

Spec:

- Start `parallel` (8) workers **in the background**, and save each one's PID in `traffic_pids`.
- Each worker loops until something fails:
  - `down`: download one of the URLs and throw the data away.
  - `up`: send **64 MB of zeros** to one of the URLs with HTTP POST. Don't write anything to disk.
- Spread the workers across the URLs instead of all hitting the first one.
- A worker that gets an error just stops (returns).

Done when, during a run, `pgrep -c -x curl` in another terminal shows 8. (Part 6 makes the run last. For now, add a temporary `sleep 5` at the end to try it.)

<details>
<summary>Hint 1</summary>

Put the loop in a function and start it with `&`. Right after starting a background job, `$!` holds its PID. Pass the URL list to the function as arguments, so it gets them as an array.

</details>

<details>
<summary>Hint 2</summary>

- Download: `curl -fsS -o /dev/null "$url"`.
- Upload: `dd if=/dev/zero bs=1M count=64 | curl … -X POST --data-binary @- "$url"`, where `@-` means "read the body from stdin".
- Round-robin: keep a counter `idx`, start it at `$RANDOM`, and pick `${urls[$((idx % ${#urls[@]}))]}`.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/assets/speedtest.sh -->
**In `assets/speedtest.sh`:**

```bash
# Round-robin across the returned URLs to spread load across nodes
traffic_worker() {
  local urls=("$@")
  local idx=$RANDOM
  while true; do
    url=${urls[$((idx % ${#urls[@]}))]}
    if [[ $direction == "down" ]]; then
      curl -fsS -o /dev/null "$url" 2>/dev/null || return
    else
      dd if=/dev/zero bs=1M count=64 2>/dev/null | curl -fsS -o /dev/null -X POST --data-binary @- "$url" 2>/dev/null || return
    fi
    idx=$((idx + 1))
  done
}

for ((i = 0; i < parallel; i++)); do
  # shellcheck disable=SC2086 # word-split the URL list into args
  traffic_worker $fast_urls &
  traffic_pids+=("$!")
done
```

- Starting each worker at `$RANDOM` and going round-robin spreads the 8 workers across the 3 servers.
- `-o /dev/null` throws the data away. We only care that it moved.
- `$fast_urls` is deliberately **unquoted** so the newline-separated list splits into separate arguments. The `shellcheck disable` comment documents that this is on purpose.
- `|| return` ends the worker on the first error instead of spinning on a dead server.

</details>

## Part 6: measure

### Your turn: print Mbps once per second

**Toolbox.** The kernel keeps running byte counters per network device:

```sh
cat /sys/class/net/enp5s0/statistics/rx_bytes   # bytes received since boot
cat /sys/class/net/enp5s0/statistics/tx_bytes   # bytes sent since boot
```

Spec:

- Use `rx_bytes` for `down` and `tx_bytes` for `up`.
- Every second, for `duration` seconds, print the Mbps over the last second with one decimal (`73.8`).
- Megabits as ISPs count them: 1 Mbit = 1,000,000 bits.
- After `duration` seconds the script ends **by itself**.

Done when `assets/speedtest.sh down 3` prints the `iface` line and then 3 numbers.

<details>
<summary>Hint 1</summary>

Read the counter, sleep a second, read it again: the difference is bytes per second. Multiply by 8 for bits. But bash only does whole numbers. Which tool from part 2 can do decimal maths?

</details>

<details>
<summary>Hint 2</summary>

`awk -v b="$before" -v a="$after" 'BEGIN { printf "%.1f\n", … }'`. And think about the edge case: what if the interface restarts and the counter goes back to zero mid-test? The difference would be negative.

</details>

<details>
<summary>Solution</summary>

<!-- file: src/assets/speedtest.sh -->
**In `assets/speedtest.sh`:**

```bash
stat=rx_bytes
[[ $direction == "up" ]] && stat=tx_bytes
counter="/sys/class/net/$iface/statistics/$stat"

before=$(<"$counter")
for ((t = 0; t < duration; t++)); do
  sleep 1
  after=$(<"$counter")
  awk -v b="$before" -v a="$after" 'BEGIN { printf "%.1f\n", (a < b ? 0 : (a - b) * 8 / 1000000) }'
  before=$after
done
```

- `$(<file)` reads a file without spawning `cat`.
- `a < b ? 0` reports 0 instead of a negative speed when the counter resets.
- Dividing by **1,000,000** (not 1,048,576) gives megabits as ISPs and Fast.com count them.
- When the loop ends the script exits and the EXIT trap fires. **This is the change from Omarchy**: the script can't outlive its purpose even if nobody kills it. (Remove the temporary `sleep 5` from part 5.)

</details>

## Part 7: debug the cleanup

The Stop button in the tab will send the script **SIGTERM**. Simulate that, then count what's left (bash/zsh syntax; in fish, run `bash` first):

```sh
assets/speedtest.sh down 30 >/dev/null & P=$!
sleep 3.5; kill -TERM $P; wait $P
pgrep -c -x curl
```

With the cleanup from part 4, this prints a number above 0, up to **8**: curls are still downloading after the script is gone. Let a run end normally (`assets/speedtest.sh down 2; pgrep -c -x curl`) and count again. Same problem. Kill them with `pkill -x curl` before going on.

> **Fast connection?** Each leftover curl only lives until its current file finishes, which can take under a second on a fast line. That's why `pgrep` runs straight after `wait`. Any count above 0 is the bug. If you still see 0, try `up` instead of `down` (uploads are usually slower).

### Your turn: why are curls still running? Fix it.

Done when a stopped run and one that ends normally both leave **0** curls, even after waiting a second for the cleanup to finish (`sleep 1; pgrep -c -x curl`).

<details>
<summary>Hint 1</summary>

Look at the process tree while a run is going:

```sh
assets/speedtest.sh down 30 >/dev/null & P=$!; sleep 3; pstree -p $P
```

Which PIDs are in `traffic_pids`? Whose child is each curl?

</details>

<details>
<summary>Hint 2</summary>

`traffic_pids` holds the worker **subshells**. Each curl is a child of a subshell. Killing a parent doesn't kill its children: they're re-parented (`ps -o pid,ppid,comm -C curl` shows a new parent) and keep downloading. `pkill -P <pid>` signals the children of a process.

</details>

<details>
<summary>Hint 3</summary>

Make `cleanup` a function: for each worker, kill its children first, then the worker. Make every kill tolerate "already gone" (remember `set -e`). Then `wait` for them all.

</details>

<details>
<summary>Solution</summary>

Replace the part 4 starting point with:

<!-- file: src/assets/speedtest.sh -->
**In `assets/speedtest.sh`:**

```bash
traffic_pids=()

cleanup() {
  local pid
  for pid in "${traffic_pids[@]}"; do
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT
# The shell stops us early with SIGTERM (Process.running = false). Bash runs EXIT traps on
# SIGTERM anyway; trapping it explicitly documents that and guarantees exit code 143
trap 'exit 143' TERM INT
```

- `pkill -TERM -P "$pid"` kills the worker's children (curl, dd) first, then `kill "$pid"` kills the worker subshell itself.
- `|| true` keeps `set -e` from aborting the cleanup if a process has already gone.
- `wait` makes the script exit only once the workers are really gone.
- `trap 'exit 143' TERM INT` is explained in the experiment below.

</details>

### Predict, then run: does EXIT fire on SIGTERM?

The final cleanup also has `trap 'exit 143' TERM INT`. Is it needed? Before running anything, **predict**: when bash is killed with SIGTERM and has *only* an EXIT trap, does the trap run?

Save this as `exit-trap-test.sh` and run it:

```bash
# exit-trap-test.sh: does the EXIT trap fire on SIGTERM without a TERM trap?
trap 'echo EXIT-trap-ran' EXIT
while true; do sleep 1; done
```
```sh
bash exit-trap-test.sh & P=$!; sleep 1.5; kill -TERM $P; wait $P; echo "exit=$?"
```

<details>
<summary>What happens, and why we keep the TERM trap anyway</summary>

Bash (tested with 5.3) prints `EXIT-trap-ran`: it runs the EXIT trap when killed by SIGTERM. POSIX doesn't require that of every shell, though. `trap 'exit 143' TERM INT` turns the signal into an explicit `exit`, so the cleanup path is spelled out and the exit code is always the same. The comment in the code says exactly that.

Lesson: don't take shell behaviour on trust, test it. Your prediction was a hypothesis, and the run was the experiment.

</details>

## Test it

That's the whole script. Before running the final tests, predict: **what exit code will a stopped run have, and why?**

<details>
<summary>Answer</summary>

**143.** Our `trap 'exit 143' TERM INT` exits with 143 on SIGTERM. That's also the usual code for "terminated by SIGTERM": 128 + 15, where 15 is SIGTERM's signal number. The QML side gets this code in `onExited` (chapter 5).

</details>

```sh
cd ~/.config/quickshell/caelestia
assets/speedtest.sh down 3; echo "exit=$?"     # expect: iface line, 3 numbers, exit=0
assets/speedtest.sh up 2                       # upload is usually lower on home lines

# Stop it early and check nothing leaks:
assets/speedtest.sh down 30 & P=$!
sleep 3.5; kill -TERM $P; wait $P; echo "exit=$?"   # were you right?
sleep 1; pgrep -c -x curl                           # expect 0
```

Then compare your file with the reference:

```sh
diff assets/speedtest.sh ~/Projects/caelestia-speedtest/src/assets/speedtest.sh
```

<details>
<summary>Complete file</summary>

<!-- file: src/assets/speedtest.sh complete -->
**In `assets/speedtest.sh`:**

```bash
#!/bin/bash

# Live internet speed test for one direction against Fast.com (Netflix OCA) nodes.
# Adapted from Omarchy's omarchy-network-speedtest (MIT, (c) David Heinemeier Hansson).
#
# Usage: speedtest.sh down|up [seconds]
# Output: "iface <name>" once, then one Mbps reading per second until done.

set -e

direction="${1:-}"
duration="${2:-5}"
probe=1.1.1.1
parallel=8
url_count=3

case "$direction" in
  down | up) ;;
  *)
    echo "Usage: speedtest.sh down|up [seconds]" >&2
    exit 2
    ;;
esac

for cmd in curl jq ip; do
  if ! command -v "$cmd" >/dev/null; then
    echo "$cmd is required" >&2
    exit 1
  fi
done

iface=$(ip route get "$probe" 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

if [[ -z $iface || ! -r /sys/class/net/$iface/statistics/rx_bytes ]]; then
  echo "No active network interface" >&2
  exit 1
fi

echo "iface $iface"

fast_token="YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm"
fast_urls=$(curl -fsS --max-time 10 "https://api.fast.com/netflix/speedtest/v2?https=true&token=$fast_token&urlCount=$url_count" 2>/dev/null | jq -r '.targets[]?.url // empty')

if [[ -z $fast_urls ]]; then
  echo "Failed to fetch speed test endpoints" >&2
  exit 1
fi

traffic_pids=()

cleanup() {
  local pid
  for pid in "${traffic_pids[@]}"; do
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT
# The shell stops us early with SIGTERM (Process.running = false). Bash runs EXIT traps on
# SIGTERM anyway; trapping it explicitly documents that and guarantees exit code 143
trap 'exit 143' TERM INT

# Round-robin across the returned URLs to spread load across nodes
traffic_worker() {
  local urls=("$@")
  local idx=$RANDOM
  while true; do
    url=${urls[$((idx % ${#urls[@]}))]}
    if [[ $direction == "down" ]]; then
      curl -fsS -o /dev/null "$url" 2>/dev/null || return
    else
      dd if=/dev/zero bs=1M count=64 2>/dev/null | curl -fsS -o /dev/null -X POST --data-binary @- "$url" 2>/dev/null || return
    fi
    idx=$((idx + 1))
  done
}

for ((i = 0; i < parallel; i++)); do
  # shellcheck disable=SC2086 # word-split the URL list into args
  traffic_worker $fast_urls &
  traffic_pids+=("$!")
done

stat=rx_bytes
[[ $direction == "up" ]] && stat=tx_bytes
counter="/sys/class/net/$iface/statistics/$stat"

before=$(<"$counter")
for ((t = 0; t < duration; t++)); do
  sleep 1
  after=$(<"$counter")
  awk -v b="$before" -v a="$after" 'BEGIN { printf "%.1f\n", (a < b ? 0 : (a - b) * 8 / 1000000) }'
  before=$after
done
```

</details>

## Check yourself

**Why kill the worker's *children* before the worker?**

<details>
<summary>Answer</summary>

The worker subshell is just a loop. The traffic is in its children, curl and dd. Killing the subshell first leaves them orphaned: they get a new parent and keep transferring, and you've lost the PID that would let `pkill -P` find them.

</details>

**What does the exit code 143 tell the QML side?**

<details>
<summary>Answer</summary>

That the script was terminated (SIGTERM, 128 + 15) instead of finishing. It's non-zero, so on its own it looks like a failure. Chapter 5 has to tell "the user pressed Stop" apart from "it really failed".

</details>

**Why does `stdout` carry only the `iface` line and numbers?**

<details>
<summary>Answer</summary>

Because the QML side parses stdout line by line: `iface …` is metadata, and everything else is read as a number. Anything else on stdout would be misread as data. Human-readable errors go to stderr, where the service collects them as the error message.

</details>

Next: [5. The service singleton →](05-service.md)
