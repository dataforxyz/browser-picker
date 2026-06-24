#!/usr/bin/env python3
"""Unit tests for the pure logic in browser-picker-rules (no GUI)."""
import importlib.machinery
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "bin", "browser-picker-rules")

# The script has no .py extension, so give the loader an explicit source loader.
loader = importlib.machinery.SourceFileLoader("bpr", SRC)
spec = importlib.util.spec_from_loader("bpr", loader)
bpr = importlib.util.module_from_spec(spec)
loader.exec_module(bpr)  # safe: GUI launch is under `if __name__ == "__main__"`

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


# default_pattern: repo-level default, www stripped, host-only
check(bpr.default_pattern("https://github.com/torvalds/linux/tree/master") == "github.com/torvalds/linux",
      "default_pattern repo-level")
check(bpr.default_pattern("https://www.linkedin.com/feed/") == "linkedin.com/feed", "default_pattern strips www")
check(bpr.default_pattern("https://example.com") == "example.com", "default_pattern host only")

# parse_args: positional URL stays backward-compatible; flags pre-fill the suggestion row
check(bpr.parse_args(["https://x/y"]) == ("https://x/y", None, None, False), "parse_args url only")
check(bpr.parse_args([]) == (None, None, None, False), "parse_args empty")
check(bpr.parse_args(["--no-open", "--pattern", "github.com/org", "--label", "Work", "https://x/y"])
      == ("https://x/y", "github.com/org", "Work", True), "parse_args full")
check(bpr.parse_args(["--label", "A — B"]) == (None, None, "A — B", False), "parse_args label with spaces")

# normcmd: quote-insensitive normalisation (used for rescan dedup)
check(bpr.normcmd('chromium --profile-directory="Profile 3"') == bpr.normcmd('chromium --profile-directory=Profile 3'),
      "normcmd quote-insensitive")

# model_items: preserve an unknown label so rules aren't silently lost
items, missing = bpr.model_items(["A", "B"], "Z")
check(missing and items[0] == "Z", "model_items preserves missing label")
items, missing = bpr.model_items(["A", "B"], "A")
check((not missing) and "A" in items, "model_items known label")
items, missing = bpr.model_items([], None)
check(items == [bpr.NONE_FOUND] and not missing, "model_items empty -> sentinel")

# load_rules: parse enabled/pattern/label incl. catch-all, ignore comments/blanks
tmp = tempfile.mkdtemp()
rf = os.path.join(tmp, "rules.conf")
with open(rf, "w") as f:
    f.write("# comment\n\n1|||github.com/org|||A\n0|||intranet|||B\n1|||*|||A\n")
bpr.RULES = rf  # monkeypatch module global read by load_rules()
check(bpr.load_rules() == [(True, "github.com/org", "A"), (False, "intranet", "B"), (True, "*", "A")],
      "load_rules parses rules")

if fails:
    print("FAILED:")
    for m in fails:
        print("  -", m)
    sys.exit(1)
print("test_rules.py: all passed")
