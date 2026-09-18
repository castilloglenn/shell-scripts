"""Bookmark target: git repositories.

Matches any directory containing a .git entry (a file for worktrees and
submodules, a directory for normal clones). Discovery stops descending as soon
as a directory matches, so vendored or nested repos are never picked up.
"""

import os

NAME = "repos"
ROOT = os.path.expanduser("~/Documents")
DEPTH = 2
PREFIX = ""
MARKER = ".git"


def matches(path):
    return os.path.exists(os.path.join(path, MARKER))
