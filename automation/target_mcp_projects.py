"""Bookmark target: per-project MCP server directories.

Matches any directory holding a .mcp.json that declares at least one server.
Deliberately server-agnostic: the server names inside the file are data, so a
GCP, GitHub or any other connector folder matches with no change here.
"""

import json
import os

NAME = "mcp"
ROOT = os.path.expanduser("~/Documents/mcp")
DEPTH = 1
PREFIX = "mcp-"
MARKER = ".mcp.json"


def matches(path):
    config = os.path.join(path, MARKER)
    if not os.path.isfile(config):
        return False
    try:
        with open(config) as f:
            servers = json.load(f).get("mcpServers")
    except (json.JSONDecodeError, OSError):
        # A malformed config is not a usable project, but it is also not our
        # business to fix. Leave any existing bookmark alone by not matching.
        return False
    return bool(servers)


def servers(path):
    """Server names this project configures, for display only."""
    try:
        with open(os.path.join(path, MARKER)) as f:
            return sorted(json.load(f).get("mcpServers", {}))
    except (json.JSONDecodeError, OSError):
        return []
