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
