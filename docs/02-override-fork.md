# 2. Setting up an override fork

We want a copy of the shell in `~/.config/quickshell/caelestia` that:

1. **matches the installed package version** exactly, because the QML has to fit the compiled plugin,
2. is a **git repository**, so every change is tracked and can be undone, and
3. **hot-reloads**, so saving a file updates the running shell immediately.

> In a hurry? `./install.sh` from this repo does steps 1–3 for you when no override exists (chapter 9). Doing it by hand once is worth it, though: you'll understand what to do when an update breaks something.

## Step 1: find your shell version

```sh
pacman -Q caelestia-shell
# caelestia-shell 2.5.0-1
```

The part before `-1` (here `2.5.0`) matches a git tag upstream: `v2.5.0`.

Why it matters: the package's C++ plugin was built from that exact tag. If your QML comes from a newer commit, it may use plugin features your binary doesn't have, and the shell fails to load with errors like `Type X unavailable` or `Cannot assign to non-existent property`.

If you run `caelestia-shell-git`, there's no tag, so use the default branch and update your fork whenever you update the package.

## Step 2: clone upstream at that tag

```sh
git clone https://github.com/caelestia-dots/shell ~/.config/quickshell/caelestia
cd ~/.config/quickshell/caelestia
git checkout v2.5.0                 # your version from step 1
git switch -c mine                  # your own branch, starting at that tag
git remote rename origin upstream   # "origin" stays free for your own GitHub fork later
```

You may see `warning: refs/tags/v2.5.0 … is not a commit!`. Upstream's tag points at another tag object rather than straight at a commit. Git sorts it out and the warning is harmless.

Why a branch called `mine`? You'll make commits on top of upstream's tag. When the package updates to `v2.6.0`, you **rebase** `mine` onto the new tag and git re-applies your commits (chapter 8).

## Step 3: bring over anything you added to the system shell

If you ever dropped your own files into `/etc/xdg/quickshell/caelestia` (custom GIFs referenced as `root:/assets/...` in `shell.json`, for example), copy them into the override. Otherwise those paths break:

```sh
# Lists files that exist in the system shell but not in your fork
diff -rq /etc/xdg/quickshell/caelestia ~/.config/quickshell/caelestia | grep "Only in /etc"
```

Commit them as your first change:

```sh
git add assets/
git commit -m "assets: add personal GIFs"
```

## Step 4: hot reload

Look at the top of `shell.qml` in your fork:

```qml
ShellRoot {
    settings.watchFiles: true
```

Upstream's source has `true`. The **package** sets it to `false` (check `/etc/xdg/quickshell/caelestia/shell.qml`). With `true`, Quickshell watches every file, and saving a `.qml` file reloads the shell in about a second. That's your development loop.

## Step 5: restart onto the override

The running shell was loaded from `/etc/xdg`, and it won't move to the new folder by itself.

```sh
qs list --all
# Instance noj1807hnt:
#   Process ID: 72167
#   Config path: /etc/xdg/quickshell/caelestia/shell.qml      ← still the system one
qs kill --pid 72167
caelestia shell -d
qs list --all            # Config path should now be ~/.config/quickshell/caelestia/shell.qml
```

**Gotcha:** `qs -c caelestia kill` only kills the instance for the *currently resolved* config path. Once the override exists, that's the new path, so an instance started from the old path survives and you end up with two bars. Always use `qs list --all` and `--pid`.

## Going back

Your fork never changes the system shell. To return to stock:

```sh
mv ~/.config/quickshell/caelestia ~/.config/quickshell/caelestia.off
# then restart as in step 5
```

## Your development loop

Every later chapter relies on this loop, so set it up now: keep a terminal open on the shell's log while you edit.

1. **Find the running instance:**

   ```sh
   qs list --all
   # Instance noj1807hnt:
   #   Process ID: 72167
   #   Config path: /home/you/.config/quickshell/caelestia/shell.qml
   ```

   Check the **Config path** is your override. If it still says `/etc/xdg`, do step 5 again.

2. **Follow its log:**

   ```sh
   qs log --pid 72167 -f        # keep printing new lines as they arrive
   qs log --pid 72167 -t 40     # or: just the last 40 lines
   ```

3. **Save a file and read the result.** With hot reload, every save prints:

   ```
   INFO: Reloading configuration...
   INFO: Configuration Loaded
   ```

   "Configuration Loaded" means every file parsed and the shell rebuilt itself from them. Errors mentioning **your** files are yours to fix. Anything else may have been there before your change, so glance at the log *before* editing too.

4. **Know its blind spot.** Things created by a `Loader` (like dashboard tabs) are only built when shown. An error inside one appears in the log when you open it, not on save.

5. **Print your own messages.** `console.log("phase", phase)` anywhere in QML shows up as a `DEBUG qml: phase …` line. It's the quickest way to see what your code is doing.

## Check yourself

**`qs list --all` shows which config path?**

<details>
<summary>Answer</summary>

`~/.config/quickshell/caelestia/shell.qml`, your override. If it shows `/etc/xdg/quickshell/caelestia/shell.qml`, the old instance is still running: kill it by `--pid` and start `caelestia shell -d` again.

</details>

**Change a string somewhere visible (try a tab label in `modules/dashboard/Content.qml`) and save. What happens, and how do you undo it?**

<details>
<summary>Answer</summary>

The log prints `Reloading configuration...` and `Configuration Loaded`, and the label changes on screen in about a second, with no restart. `git checkout -- .` throws away the change (it restores every tracked file to your last commit).

</details>

**What does `git log --oneline -3` show?**

<details>
<summary>Answer</summary>

Your own commits (if you made any, like the assets commit from step 3) on top of the commit the upstream tag points to (`ci: update workflows (#2041)` for `v2.5.0`). That's the shape chapter 8's rebase relies on: upstream's tag, then your work.

</details>

Next: [3. Studying Omarchy's implementation →](03-studying-omarchy.md)
