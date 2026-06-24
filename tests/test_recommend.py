#!/usr/bin/env python3
"""Unit tests for the pure logic in browser-picker-recommend (no GUI, no network)."""
import importlib.machinery
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "bin", "browser-picker-recommend")

# The script has no .py extension, so give the loader an explicit source loader.
loader = importlib.machinery.SourceFileLoader("bprec", SRC)
spec = importlib.util.spec_from_loader("bprec", loader)
bprec = importlib.util.module_from_spec(spec)
loader.exec_module(bprec)  # safe: CLI is under `if __name__ == "__main__"`

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


# --- url_parts: http(s) only, www/userinfo/port stripped ---
check(bprec.url_parts("https://github.com/orgA/repo1/issues/3") == ("github.com", ["orgA", "repo1", "issues", "3"]),
      "url_parts host+segs")
check(bprec.url_parts("https://www.linkedin.com/feed/") == ("linkedin.com", ["feed"]), "url_parts strips www")
check(bprec.url_parts("https://github.com:443/x") == ("github.com", ["x"]), "url_parts strips port")
check(bprec.url_parts("mailto:a@b.com") == (None, []), "url_parts ignores non-http")
check(bprec.url_parts("ftp://host/x") == (None, []), "url_parts ignores ftp")

# --- common_prefix ---
check(bprec.common_prefix([["a", "b", "c"], ["a", "b", "d"]]) == ["a", "b"], "common_prefix shared")
check(bprec.common_prefix([["a", "b"], ["x", "y"]]) == [], "common_prefix none")


def feed(urls_labels, n=3):
    """Replay (url, label) picks into a fresh store; return (store, last_recommendation)."""
    store = {"events": [], "state": {}}
    rec = None
    for ts, (url, label) in enumerate(urls_labels):
        rec = bprec.record_and_recommend(store, url, label, n, ts)
    return store, rec


W = "Chromium — Work"
P = "Chromium — Personal"

# Below threshold -> nothing yet.
_, rec = feed([("https://github.com/orgA/repo1", W), ("https://github.com/orgA/repo1", W)])
check(rec is None, "below threshold -> None")

# Same repo x3 -> repo-level pattern.
_, rec = feed([("https://github.com/orgA/repo1/a", W),
               ("https://github.com/orgA/repo1/b", W),
               ("https://github.com/orgA/repo1/c", W)])
check(rec == ("github.com/orgA/repo1", W), "same repo x3 -> repo pattern (got %r)" % (rec,))

# Three different repos, same org -> generalize to the org.
_, rec = feed([("https://github.com/orgA/repo1", W),
               ("https://github.com/orgA/repo2", W),
               ("https://github.com/orgA/repo3", W)])
check(rec == ("github.com/orgA", W), "org generalization (got %r)" % (rec,))

# Different orgs, one profile only -> generalize to the whole host.
_, rec = feed([("https://github.com/orgA/r", W),
               ("https://github.com/orgB/r", W),
               ("https://github.com/orgC/r", W)])
check(rec == ("github.com", W), "host generalization (got %r)" % (rec,))

# Contested host: org-level would hijack another profile's link -> no confident suggestion.
_, rec = feed([("https://github.com/orgA/repo1", W),
               ("https://github.com/orgA/repo2", W),
               ("https://github.com/orgA/repo9", P),  # Personal also uses orgA
               ("https://github.com/orgA/repo3", W)])
check(rec is None, "contested org -> None (got %r)" % (rec,))

# Purity holds at repo level: Personal on a *different* repo doesn't block Work's repo rule.
_, rec = feed([("https://github.com/orgA/repo1/x", W),
               ("https://github.com/orgA/repo9", P),
               ("https://github.com/orgA/repo1/y", W),
               ("https://github.com/orgA/repo1/z", W)])
check(rec == ("github.com/orgA/repo1", W), "repo-level stays pure (got %r)" % (rec,))

# mailto / non-http never recorded.
store, rec = feed([("mailto:me@example.com", W)])
check(rec is None and store["events"] == [], "non-http not recorded")

# --- snooze / never gating ---
seq = [("https://github.com/orgA/repo1", W)] * 3
store, rec = feed(seq)
check(rec == ("github.com/orgA/repo1", W), "fires at 3")
bprec.apply_dismiss(store, W, "github.com/orgA/repo1", "snooze")  # snooze -> count(3)+3 = 6
rec4 = bprec.record_and_recommend(store, "https://github.com/orgA/repo1", W, 3, 10)
rec5 = bprec.record_and_recommend(store, "https://github.com/orgA/repo1", W, 3, 11)
rec6 = bprec.record_and_recommend(store, "https://github.com/orgA/repo1", W, 3, 12)
check(rec4 is None and rec5 is None, "snooze suppresses until count reaches gate")
check(rec6 == ("github.com/orgA/repo1", W), "snooze re-asks after enough picks (got %r)" % (rec6,))
bprec.apply_dismiss(store, W, "github.com/orgA/repo1", "never")
rec7 = bprec.record_and_recommend(store, "https://github.com/orgA/repo1", W, 3, 13)
check(rec7 is None, "never mutes permanently")

if fails:
    print("FAILED:")
    for m in fails:
        print("  -", m)
    sys.exit(1)
print("test_recommend.py: all passed")
