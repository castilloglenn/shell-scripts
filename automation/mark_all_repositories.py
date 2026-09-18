"""Bookmark every git repository under a root directory as a zsh named directory.

Scans ~/Documents (override with --root or REPO_ROOT) down to a fixed depth,
and stops descending as soon as a directory is itself a git repository, so
vendored or nested repos (venv/src/..., backups, submodule-ish copies) are
never picked up.

Appends to ~/.zsh_bookmarks. Existing lines are never modified or removed
unless --prune is passed explicitly.

Dry run by default; pass --apply to actually write.
"""

import argparse
import os
import re
import sys

BOOKMARK_FILE = os.path.expanduser("~/.zsh_bookmarks")
BACKUP_FILE = BOOKMARK_FILE + ".bak"
DEFAULT_ROOT = os.path.expanduser("~/Documents")
DEFAULT_DEPTH = 2

# Never descend into these, regardless of depth.
SKIP_DIRS = {
    ".git", "node_modules", "venv", ".venv", "env", "vendor",
    "__pycache__", ".tox", "Library", ".terraform", "target", "build",
}

BOOKMARK_RE = re.compile(r'^\s*hash -d ([^=\s]+)=\"?([^\"]*)\"?\s*$')


# os.path.normcase is a no-op on macOS, so fold case ourselves where the
# filesystem is case-insensitive. Otherwise ~/documents and ~/Documents
# compare as two different directories.
CASE_INSENSITIVE_FS = sys.platform in ("darwin", "win32")


def canonical(path):
    """Comparable form of a path."""
    resolved = os.path.realpath(path)
    return resolved.lower() if CASE_INSENSITIVE_FS else resolved


def read_bookmarks():
    """Return {name: canonical_path} for everything already registered."""
    existing = {}
    if not os.path.exists(BOOKMARK_FILE):
        return existing
    with open(BOOKMARK_FILE) as f:
        for line in f:
            match = BOOKMARK_RE.match(line)
            if match:
                name, path = match.groups()
                existing[name] = canonical(os.path.expanduser(path))
    return existing


def is_git_repo(directory):
    # A worktree or submodule has .git as a file, not a directory.
    return os.path.exists(os.path.join(directory, ".git"))


def find_repos(root, max_depth):
    """Yield repo paths, pruning at the first repo found on each branch."""
    repos = []

    def walk(directory, depth):
        if depth > max_depth:
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
            if is_git_repo(entry.path):
                # Found a repo: record it and do NOT descend any further.
                repos.append(entry.path)
                continue
            walk(entry.path, depth + 1)

    walk(root, 1)
    return repos


def plan(repos, existing, quiet=False):
    """Decide a bookmark name for each repo. Returns (to_add, skipped)."""
    to_add = []
    skipped = []
    taken = dict(existing)

    for path in repos:
        name = os.path.basename(path)
        target = canonical(path)

        if taken.get(name) == target:
            skipped.append((name, path, "already bookmarked"))
            continue

        if name in taken:
            # Name is taken by a different path: fall back to <parent>-<name>.
            parent = os.path.basename(os.path.dirname(path))
            alt = f"{parent}-{name}"
            if taken.get(alt) == target:
                skipped.append((alt, path, "already bookmarked"))
                continue
            if alt in taken:
                skipped.append((name, path, f"name collision, {alt} also taken"))
                continue
            if not quiet:
                print(f"   name collision on ~{name}, using ~{alt} instead")
            name = alt

        taken[name] = target
        to_add.append((name, path))

    return to_add, skipped


def find_stale():
    """Return (lines, stale) where stale is [(index, name, path, reason)].

    A bookmark is stale if its directory is gone, or if it still exists but is
    no longer a git repository.
    """
    if not os.path.exists(BOOKMARK_FILE):
        return [], []

    with open(BOOKMARK_FILE) as f:
        lines = f.readlines()

    stale = []
    for index, line in enumerate(lines):
        match = BOOKMARK_RE.match(line)
        if not match:
            # Comments, blank lines and anything hand-written: always keep.
            continue
        name, raw = match.groups()
        path = os.path.expanduser(raw)
        if not os.path.isdir(path):
            stale.append((index, name, path, "directory is gone"))
        elif not is_git_repo(path):
            stale.append((index, name, path, "no longer a git repo"))

    return lines, stale


def prune(apply_changes):
    """Remove stale bookmarks. Returns the number removed."""
    lines, stale = find_stale()
    if not stale:
        print("\nPrune: nothing stale.")
        return 0

    print(f"\nPrune: {len(stale)} stale bookmark(s)")
    for _, name, path, reason in stale:
        print(f"   - ~{name} -> {path}  ({reason})")

    if not apply_changes:
        print(f"\nDry run. Re-run with --prune --apply to remove these {len(stale)}.")
        return 0

    # Back up before the first rewrite this script ever performs.
    with open(BACKUP_FILE, "w") as f:
        f.writelines(lines)

    drop = {index for index, _, _, _ in stale}
    with open(BOOKMARK_FILE, "w") as f:
        f.writelines(line for i, line in enumerate(lines) if i not in drop)

    print(f"\nRemoved {len(stale)} bookmarks. Backup: {BACKUP_FILE}")
    return len(stale)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=os.environ.get("REPO_ROOT", DEFAULT_ROOT))
    parser.add_argument("--depth", type=int, default=DEFAULT_DEPTH,
                        help=f"how many levels below root to search (default {DEFAULT_DEPTH})")
    parser.add_argument("--apply", action="store_true",
                        help="actually write to ~/.zsh_bookmarks (default is a dry run)")
    parser.add_argument("--prune", action="store_true",
                        help="also remove bookmarks whose directory is gone or is "
                             "no longer a git repo. Manual only: never runs under "
                             "--quiet, and backs the file up before rewriting")
    parser.add_argument("--quiet", action="store_true",
                        help="say nothing unless bookmarks were actually added; "
                             "intended for running on shell startup")
    args = parser.parse_args()
    quiet = args.quiet

    if args.prune and quiet:
        # A slow-mounting volume would make every bookmark under it look stale.
        # Pruning stays a deliberate, visible action.
        raise SystemExit("--prune cannot be combined with --quiet")

    root = os.path.expanduser(args.root)
    if not os.path.isdir(root):
        # On startup the root may legitimately be missing (unmounted volume,
        # fresh machine). Stay silent rather than breaking the shell.
        if quiet:
            return
        raise SystemExit(f"Not a directory: {root}")

    existing = read_bookmarks()
    repos = find_repos(root, args.depth)
    if not quiet:
        print(f"Scanned {root} to depth {args.depth}: found {len(repos)} repositories")
        print(f"{len(existing)} bookmarks already registered\n")

    to_add, skipped = plan(repos, existing, quiet=quiet)

    if not quiet:
        for name, path in to_add:
            print(f"   + ~{name} -> {path}")
        if skipped:
            print(f"\n   {len(skipped)} skipped ({len(repos) - len(to_add)} of {len(repos)} repos)")

    changed = False
    if not to_add:
        if not quiet:
            print("\nNothing to add.")
    elif not args.apply:
        if not quiet:
            print(f"\nDry run. Re-run with --apply to append these {len(to_add)} bookmarks.")
    else:
        changed = True
        with open(BOOKMARK_FILE, "a") as f:
            for name, path in to_add:
                f.write(f'hash -d {name}="{path}"\n')

        if quiet:
            # Only speak up when something actually changed.
            names = ", ".join(f"~{name}" for name, _ in to_add)
            print(f"\033[1;32m[bookmarks]\033[0m added {len(to_add)}: {names}")
        else:
            print(f"\nAdded {len(to_add)} bookmarks to {BOOKMARK_FILE}")

    if args.prune and prune(args.apply):
        changed = True

    if changed and not quiet:
        print("\nRun 'restart_shell' or open a new terminal to pick up changes.")


if __name__ == "__main__":
    main()
