"""Keep ~/.zsh_bookmarks in sync with directories on disk.

Each bookmark kind lives in its own target_*.py module, which declares a root,
a search depth, a name prefix and a matches() predicate. The same predicate
drives both adding and pruning, so a target can never add a bookmark that
pruning would then consider stale.

  sync_bookmarks.py                   preview everything
  sync_bookmarks.py --apply           add new bookmarks
  sync_bookmarks.py --prune --apply   also remove stale ones
  sync_bookmarks.py --target mcp      limit to one target

Adding is append-only and safe to automate. Pruning rewrites the file, so it
stays manual and takes a backup first.
"""

import argparse
import os
import re
import sys

import target_mcp_projects
import target_repositories

TARGETS = [target_repositories, target_mcp_projects]

BOOKMARK_FILE = os.path.expanduser("~/.zsh_bookmarks")
BACKUP_FILE = BOOKMARK_FILE + ".bak"

BOOKMARK_RE = re.compile(r'^\s*hash -d ([^=\s]+)=\"?([^\"]*)\"?\s*$')

# Never descend into these, whatever the depth allows.
SKIP_DIRS = {
    "node_modules", "venv", ".venv", "env", "vendor",
    "__pycache__", ".tox", "Library", ".terraform", "target", "build",
}

# os.path.normcase is a no-op on macOS, so fold case ourselves where the
# filesystem is case-insensitive. Otherwise ~/documents and ~/Documents
# compare as two different directories.
CASE_INSENSITIVE_FS = sys.platform in ("darwin", "win32")


def canonical(path):
    """Comparable form of a path."""
    resolved = os.path.realpath(path)
    return resolved.lower() if CASE_INSENSITIVE_FS else resolved


def read_bookmarks():
    """Return (lines, entries) where entries is [(index, name, path)]."""
    if not os.path.exists(BOOKMARK_FILE):
        return [], []
    with open(BOOKMARK_FILE) as f:
        lines = f.readlines()

    entries = []
    for index, line in enumerate(lines):
        match = BOOKMARK_RE.match(line)
        if match:
            name, raw = match.groups()
            entries.append((index, name, os.path.expanduser(raw)))
    return lines, entries


def discover(target):
    """Directories under target.ROOT that match, pruning at each match."""
    found = []

    def walk(directory, depth):
        if depth > target.DEPTH:
            return
        try:
            entries = sorted(os.scandir(directory), key=lambda e: e.name)
        except (PermissionError, FileNotFoundError):
            return
        for entry in entries:
            if not entry.is_dir(follow_symlinks=False):
                continue
            if entry.name in SKIP_DIRS or entry.name.startswith("."):
                continue
            if target.matches(entry.path):
                # Matched: record it and do NOT descend any further.
                found.append(entry.path)
                continue
            walk(entry.path, depth + 1)

    if os.path.isdir(target.ROOT):
        walk(target.ROOT, 1)
    return found


def owner(path, targets):
    """The target responsible for a path, or None.

    Roots can nest (~/Documents/aws sits inside ~/Documents), so the most
    specific root wins. A path under no root belongs to no target, which is how
    hand-made bookmarks stay safe from pruning.
    """
    best = None
    for target in targets:
        root = canonical(target.ROOT)
        candidate = canonical(path)
        if candidate == root or candidate.startswith(root + os.sep):
            if best is None or len(root) > len(canonical(best.ROOT)):
                best = target
    return best


def plan_adds(targets, entries):
    """Decide a bookmark name per discovered directory. Returns [(name, path, target)]."""
    taken = {name: canonical(path) for _, name, path in entries}
    to_add = []

    for target in targets:
        for path in discover(target):
            name = target.PREFIX + os.path.basename(path)
            resolved = canonical(path)

            if taken.get(name) == resolved:
                continue  # already bookmarked, same place
            if name in taken:
                # Name taken by a different path: fall back to <parent>-<name>.
                parent = os.path.basename(os.path.dirname(path))
                alt = f"{target.PREFIX}{parent}-{os.path.basename(path)}"
                if taken.get(alt) == resolved:
                    continue  # already bookmarked under the fallback name
                if alt in taken:
                    print(f"   ! skipped {path}: ~{name} and ~{alt} both taken")
                    continue
                print(f"   ! collision on ~{name}, using ~{alt}")
                name = alt

            taken[name] = resolved
            to_add.append((name, path, target))

    return to_add


def plan_prunes(targets, entries):
    """Bookmarks inside a target's root that no longer match. Returns [(index, name, path, reason)]."""
    stale = []
    for index, name, path in entries:
        target = owner(path, targets)
        if target is None:
            continue  # not ours; never touch it
        if not os.path.isdir(path):
            stale.append((index, name, path, "directory is gone"))
        elif not target.matches(path):
            stale.append((index, name, path, f"no {target.MARKER}"))
    return stale


def describe(path, target):
    """Optional extra detail a target can supply for display."""
    if hasattr(target, "servers"):
        names = target.servers(path)
        if names:
            return "  [" + ", ".join(names) + "]"
    return ""


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--target", choices=[t.NAME for t in TARGETS] + ["all"],
                        default="all", help="which target to sync (default: all)")
    parser.add_argument("--apply", action="store_true",
                        help="actually write to ~/.zsh_bookmarks (default is a dry run)")
    parser.add_argument("--prune", action="store_true",
                        help="also remove bookmarks inside a target root that no longer "
                             "match. Manual only: never runs under --quiet, and backs the "
                             "file up before rewriting")
    parser.add_argument("--quiet", action="store_true",
                        help="say nothing unless bookmarks were added; for shell startup")
    args = parser.parse_args()
    quiet = args.quiet

    if args.prune and quiet:
        # A slow-mounting volume would make every bookmark under it look stale.
        # Pruning stays a deliberate, visible action.
        raise SystemExit("--prune cannot be combined with --quiet")

    targets = TARGETS if args.target == "all" else [t for t in TARGETS if t.NAME == args.target]
    lines, entries = read_bookmarks()

    if not quiet:
        for target in targets:
            print(f"{target.NAME}: {target.ROOT} depth {target.DEPTH} marker {target.MARKER}")
        print(f"{len(entries)} bookmarks already registered\n")

    to_add = plan_adds(targets, entries)
    changed = False

    if not to_add:
        if not quiet:
            print("Nothing to add.")
    elif not args.apply:
        if not quiet:
            for name, path, target in to_add:
                print(f"   + ~{name} -> {path}{describe(path, target)}")
            print(f"\nDry run. Re-run with --apply to append these {len(to_add)}.")
    else:
        with open(BOOKMARK_FILE, "a") as f:
            for name, path, _ in to_add:
                f.write(f'hash -d {name}="{path}"\n')
        changed = True
        if quiet:
            # Only speak up when something actually changed.
            names = ", ".join(f"~{name}" for name, _, _ in to_add)
            print(f"\033[1;32m[bookmarks]\033[0m added {len(to_add)}: {names}")
        else:
            for name, path, target in to_add:
                print(f"   + ~{name} -> {path}{describe(path, target)}")
            print(f"\nAdded {len(to_add)} bookmarks.")

    if args.prune:
        stale = plan_prunes(targets, entries)
        if not stale:
            print("\nPrune: nothing stale.")
        else:
            print(f"\nPrune: {len(stale)} stale bookmark(s)")
            for _, name, path, reason in stale:
                print(f"   - ~{name} -> {path}  ({reason})")
            if not args.apply:
                print(f"\nDry run. Re-run with --prune --apply to remove these {len(stale)}.")
            else:
                # Re-read: the add phase above may have appended lines.
                lines, _ = read_bookmarks()
                with open(BACKUP_FILE, "w") as f:
                    f.writelines(lines)
                drop = {path for _, _, path, _ in stale}
                kept = [
                    line for line in lines
                    if not (BOOKMARK_RE.match(line)
                            and os.path.expanduser(BOOKMARK_RE.match(line).group(2)) in drop)
                ]
                with open(BOOKMARK_FILE, "w") as f:
                    f.writelines(kept)
                changed = True
                print(f"\nRemoved {len(stale)} bookmarks. Backup: {BACKUP_FILE}")

    if changed and not quiet:
        print("\nRun 'restart_shell' or open a new terminal to pick up changes.")


if __name__ == "__main__":
    main()
