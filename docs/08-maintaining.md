# 8. Maintaining and packaging

Your override is a snapshot of one shell version. When `pacman -Syu` brings a new `caelestia-shell`, the compiled plugin changes but your QML doesn't. This chapter keeps the two in sync.

## Commit your work

Commit early, with messages in upstream's style (`type(scope): summary`):

```sh
cd ~/.config/quickshell/caelestia
git add assets/speedtest.sh services/SpeedTest.qml modules/dashboard/SpeedTestTab.qml modules/dashboard/Content.qml
git commit -m "feat(dashboard): add speed test tab"
git log --oneline v2.5.0..mine      # your commits on top of the tag
```

Uncommitted changes make rebasing painful, and you lose the record of what you changed.

## After a package update

```sh
pacman -Q caelestia-shell           # say it's now 2.6.0
cd ~/.config/quickshell/caelestia
git fetch upstream --tags
git rebase v2.6.0                   # replay your commits on the new tag
```

`git rebase v2.6.0` takes the commits that are on `mine` but not upstream, moves the branch to `v2.6.0`, and re-applies those commits one by one.

- **No conflicts:** restart the shell (`qs kill --pid …`, `caelestia shell -d`) and test.
- **Conflict in `Content.qml`:** upstream changed the tab list. Open the file, keep upstream's new version, re-add your tab entry and `Component` by hand (chapter 6, step 1), then:

  ```sh
  git add modules/dashboard/Content.qml
  git rebase --continue
  ```

- **Something's badly broken:** `git rebase --abort` puts everything back as it was.

Our new files (`SpeedTest.qml`, `SpeedTestTab.qml`, the script) almost never conflict, because upstream doesn't have them. That's another reason to put features in **new files** and keep edits to upstream files as small as possible: our only edit to an upstream file is 12 lines in `Content.qml`.

## When the new version changes APIs

If the tab breaks after an update without a conflict, the components it uses may have changed. Check what changed in the files we depend on:

```sh
git diff v2.5.0 v2.6.0 -- components/controls/CircularProgress.qml components/controls/IconTextButton.qml \
    plugin/src/Caelestia/Config/tokens.hpp modules/dashboard/Content.qml
```

A renamed token (`Tokens.padding.large` → something else) shows up there, and also as an error in `qs log` when you open the tab.

## Packaging your widget as a repo

Your fork works for you. To share the widget, package just your change as its own small repo, separate from the fork. That's what this repository is. Here's how it was put together, so you can do the same for your own widgets.

### 1. Lay out `src/` like the shell

```
caelestia-speedtest/
├── src/
│   ├── assets/speedtest.sh                 → <override>/assets/speedtest.sh
│   ├── services/SpeedTest.qml              → <override>/services/SpeedTest.qml
│   └── modules/dashboard/SpeedTestTab.qml  → <override>/modules/dashboard/SpeedTestTab.qml
├── patches/dashboard-content.patch         edits to files upstream already has
├── install.sh
└── uninstall.sh
```

- `src/` **mirrors the shell's folders**, so every file's destination is just `<override>/<same path>`. No mapping table is needed in the installer.
- **New files** go in `src/`. **Edits to upstream files** go in `patches/`. You never ship a whole copy of an upstream file (like `Content.qml`), because it would overwrite whatever else the user changed in it.

### 2. Copy your files out of the override

```sh
mkdir -p ~/Projects/my-widget && cd ~/Projects/my-widget && git init -b main
F=~/.config/quickshell/caelestia
mkdir -p src/assets src/services src/modules/dashboard patches
cp "$F/assets/speedtest.sh" src/assets/
cp "$F/services/SpeedTest.qml" src/services/
cp "$F/modules/dashboard/SpeedTestTab.qml" src/modules/dashboard/
cp "$F/LICENSE" .          # Caelestia is GPL-3.0, so your add-on is too (chapter 3, step 6)
```

### 3. Generate the patch against the upstream tag

```sh
git -C ~/.config/quickshell/caelestia diff v2.5.0 -- modules/dashboard/Content.qml \
    > ~/Projects/my-widget/patches/dashboard-content.patch
```

- Diff against the **tag** (`v2.5.0`), not against your branch or `HEAD`. Your fork may contain other personal commits. A diff against the tag holds only the changes to that file relative to stock Caelestia, which is what other people have.
- List only the files you edited (`-- modules/dashboard/Content.qml`). Otherwise unrelated changes end up in the patch.
- Check it with `git apply --check` on a clean clone of the tag before publishing.

### 4. Write the installer

`install.sh` is about 140 lines, but only five ideas matter. Excerpts:

**Detect the installed version** so a new override matches the compiled plugin (chapter 2):

```bash
if command -v pacman >/dev/null; then
  pkg=$(pacman -Qq 2>/dev/null | grep -m1 '^caelestia-shell' || true)
  [[ -n $pkg ]] && version=$(pacman -Q "$pkg" | awk '{ print $2 }' | sed 's/-[0-9.]*$//')
fi
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  tag="v$version"
```

- `grep -m1 '^caelestia-shell'` also catches `caelestia-shell-git`.
- `sed 's/-[0-9.]*$//'` strips the package release (`2.5.0-1` → `2.5.0`). It allows dots because some repos (CachyOS) use releases like `-1.1`.
- A git build's version doesn't match `X.Y.Z`, so `tag` stays empty and the clone below uses the default branch.

**Clone an override only if none exists**, the same steps as chapter 2:

```bash
if [[ ! -e $target ]]; then
  info "No QML override at $target, creating one from upstream ${tag:-default branch}"
  git -c advice.detachedHead=false clone --quiet ${tag:+--branch "$tag"} "$upstream" "$target"
  git -C "$target" remote rename origin upstream
  git -C "$target" switch --quiet -c mine
  created=true
elif [[ ! -f $target/shell.qml ]]; then
  die "$target exists but doesn't look like a Caelestia shell (no shell.qml)"
fi
```

- `${tag:+--branch "$tag"}` expands to `--branch v2.5.0` only when `tag` is set, and to nothing otherwise.
- `advice.detachedHead=false` hides git's long "detached HEAD" message, since we create a branch straight after.
- An existing folder is never replaced. If it isn't a shell, the script stops instead of guessing.

**Copy files with the right permissions:**

```bash
for f in "${files[@]}"; do
  mode=644
  [[ $f == *.sh ]] && mode=755
  install -Dm "$mode" "$here/src/$f" "$target/$f"
done
```

- `install -D` creates missing parent folders, and `-m` sets the mode in the same step. Scripts must be executable, or the service can't run them (chapter 7).
- `$here` is the repo's own folder, so the installer works from any current directory.

**Apply the patch once**, the right way for each kind of override:

```bash
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
```

- **Idempotency:** `grep -q speedTestComponent` checks for an id that only exists once the patch is in. Running the installer twice then refreshes the files but never adds the tab twice. Pick a marker unique to your change.
- **`git apply --3way`** in a git override: if the user's `Content.qml` differs a little from the tag, git uses the file history to merge, like a mini rebase.
- **`patch -p1`** for a plain copy with no git. `-p1` strips the `a/` and `b/` prefixes from the paths in a git-style diff. `--forward` refuses to apply a patch that already looks applied.
- If either fails, the error says how to make the edit by hand. Always give users a way forward.

**Make commits opt-in.** `--commit` stages exactly the files the installer touched. Never commit someone's fork without being asked.

`uninstall.sh` does the reverse: it stops a running test (`pkill -f "$target/assets/speedtest.sh"`), runs `git apply --reverse` (or `patch --reverse`), and deletes the three files.

### 5. Test the installer like a user would

Never test on your own fork only. Use throwaway targets:

```sh
T=$(mktemp -d)
./install.sh --commit --target "$T/fresh"        # no override yet: clones, patches, commits
./install.sh --commit --target "$T/fresh"        # second run: "already registered", "Nothing new to commit"
./uninstall.sh --target "$T/fresh"
cp -r /etc/xdg/quickshell/caelestia "$T/plain"   # an override with no git
./install.sh --target "$T/plain" && ./uninstall.sh --target "$T/plain"
diff -r /etc/xdg/quickshell/caelestia "$T/plain" && echo "plain copy restored exactly"
```

Don't pipe the installer into `head` while testing. `head` closes the pipe early, which kills the script halfway, and you'll chase bugs that don't exist.

### Keeping the package current

After a shell update, once the tab works on the new version (say `v2.6.0`):

```sh
F=~/.config/quickshell/caelestia
git -C "$F" diff v2.6.0 -- modules/dashboard/Content.qml > ~/Projects/caelestia-speedtest/patches/dashboard-content.patch
cp "$F/assets/speedtest.sh"              ~/Projects/caelestia-speedtest/src/assets/
cp "$F/services/SpeedTest.qml"           ~/Projects/caelestia-speedtest/src/services/
cp "$F/modules/dashboard/SpeedTestTab.qml" ~/Projects/caelestia-speedtest/src/modules/dashboard/
```

Then bump `tested_version` in `install.sh` and the version in the README.

## Using caelestia-shell-git

If you follow the git package, there are no tags to rebase onto. Run `git fetch upstream && git rebase upstream/main` (`main` is upstream's default branch) after each package update. Because the package and your fork can drift apart by a few commits, update them together.

Next: [9. Installing on a fresh Caelestia →](09-installing.md)
