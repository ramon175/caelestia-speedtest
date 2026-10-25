#!/usr/bin/env bash

# Removes the Speed test dashboard tab from a Caelestia shell QML override.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target="${CAELESTIA_SHELL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia}"
patch="$here/patches/dashboard-content.patch"
files=(assets/speedtest.sh services/SpeedTest.qml modules/dashboard/SpeedTestTab.qml)

info() { printf '\e[1;34m::\e[0m %s\n' "$*"; }
die() {
  printf '\e[1;31mxx\e[0m %s\n' "$*" >&2
  exit 1
}

[[ ${1:-} == --target ]] && target="${2:?--target needs a directory}"
[[ -f $target/shell.qml ]] || die "No Caelestia shell override at $target"

# Stop a running test so no curl workers are left behind
pkill -f "$target/assets/speedtest.sh" 2>/dev/null || true

content="$target/modules/dashboard/Content.qml"
if grep -q speedTestComponent "$content"; then
  info "Unregistering the tab from modules/dashboard/Content.qml"
  if git -C "$target" rev-parse --is-inside-work-tree &>/dev/null; then
    git -C "$target" apply --reverse "$patch" || die "Couldn't reverse the patch. Remove the speedTestComponent entry and Component by hand."
  else
    patch --quiet --reverse -d "$target" -p1 <"$patch" || die "Couldn't reverse the patch. Remove the speedTestComponent entry and Component by hand."
  fi
fi

for f in "${files[@]}"; do
  rm -f -- "${target:?}/$f"
done

info "Removed. Changes aren't committed. Review them with: git -C $target status"
