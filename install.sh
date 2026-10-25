#!/usr/bin/env bash

# Installs the Speed test dashboard tab into a Caelestia shell QML override.
# See docs/09-installing.md for what each step does.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target="${CAELESTIA_SHELL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia}"
upstream=https://github.com/caelestia-dots/shell
tested_version=2.5.0
patch="$here/patches/dashboard-content.patch"
files=(assets/speedtest.sh services/SpeedTest.qml modules/dashboard/SpeedTestTab.qml)
commit=false

usage() {
  cat <<EOF
Usage: ./install.sh [--commit] [--target DIR]

  --commit      Commit the change on the override's git branch
  --target DIR  Override directory (default: $target)
                Can also be set with CAELESTIA_SHELL_DIR.
EOF
}

info() { printf '\e[1;34m::\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m!!\e[0m %s\n' "$*" >&2; }
die() {
  printf '\e[1;31mxx\e[0m %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --commit) commit=true ;;
    --target)
      target="${2:?--target needs a directory}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# Runtime dependencies of assets/speedtest.sh, plus git for the override
for cmd in git curl jq ip; do
  command -v "$cmd" >/dev/null || die "$cmd is required (try: sudo pacman -S $cmd)"
done

# Match the override to the installed shell: the QML must fit the compiled Caelestia plugin
version=""
tag=""
if command -v pacman >/dev/null; then
  pkg=$(pacman -Qq 2>/dev/null | grep -m1 '^caelestia-shell' || true)
  [[ -n $pkg ]] && version=$(pacman -Q "$pkg" | awk '{ print $2 }' | sed 's/-[0-9.]*$//')
fi
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  tag="v$version"
  [[ $version != "$tested_version" ]] && warn "Tested with caelestia-shell $tested_version, you have $version. It will probably work; see docs/08-maintaining.md if it doesn't."
elif [[ -n $version ]]; then
  warn "caelestia-shell $version is a git build, so the override will track upstream's default branch."
else
  warn "Couldn't find the caelestia-shell package. Continuing anyway."
fi

created=false
if [[ ! -e $target ]]; then
  info "No QML override at $target, creating one from upstream ${tag:-default branch}"
  git -c advice.detachedHead=false clone --quiet ${tag:+--branch "$tag"} "$upstream" "$target"
  git -C "$target" remote rename origin upstream
  git -C "$target" switch --quiet -c mine
  created=true
elif [[ ! -f $target/shell.qml ]]; then
  die "$target exists but doesn't look like a Caelestia shell (no shell.qml)"
fi

is_git=false
git -C "$target" rev-parse --is-inside-work-tree &>/dev/null && is_git=true

info "Copying files into $target"
for f in "${files[@]}"; do
  mode=644
  [[ $f == *.sh ]] && mode=755
  install -Dm "$mode" "$here/src/$f" "$target/$f"
done

content="$target/modules/dashboard/Content.qml"
if grep -q speedTestComponent "$content"; then
  info "Tab already registered in modules/dashboard/Content.qml"
elif $is_git; then
  info "Registering the tab in modules/dashboard/Content.qml"
  git -C "$target" apply --3way "$patch" || die "Patch didn't apply. Add the tab by hand: docs/06-dashboard-tab.md, step 1."
else
  info "Registering the tab in modules/dashboard/Content.qml"
  patch --quiet --forward -d "$target" -p1 <"$patch" || die "Patch didn't apply. Add the tab by hand: docs/06-dashboard-tab.md, step 1."
fi

if $commit; then
  if $is_git; then
    git -C "$target" add -- "${files[@]}" modules/dashboard/Content.qml
    if git -C "$target" diff --cached --quiet; then
      info "Nothing new to commit"
    else
      git -C "$target" commit --quiet -m "feat(dashboard): add speed test tab"
      info "Committed on branch $(git -C "$target" branch --show-current)"
    fi
  else
    warn "--commit ignored: $target isn't a git repository"
  fi
fi

info "Done."
if $created; then
  cat <<EOF

The running shell was loaded from /etc/xdg, so restart it to switch to the new override:

  qs list --all            # note the Process ID of the caelestia instance
  qs kill --pid <PID>
  caelestia shell -d

Files you added only to /etc/xdg/quickshell/caelestia (custom GIFs, etc.) aren't in the
override. Copy them into $target if shell.json refers to them.
EOF
else
  echo "If your override hot-reloads (settings.watchFiles: true in shell.qml) the tab is live now,"
  echo "otherwise restart the shell: caelestia shell -d (after killing the old instance)."
fi
