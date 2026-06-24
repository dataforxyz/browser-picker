#!/usr/bin/env bash
# Run the full local test suite: lint + syntax + unit tests.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."

if command -v shellcheck >/dev/null 2>&1; then
  echo "== shellcheck =="
  shellcheck -S warning "$ROOT/bin/browser-picker" "$ROOT/install.sh" "$HERE"/*.sh
else
  echo "== shellcheck (skipped: not installed) =="
fi

echo "== bash syntax =="
bash -n "$ROOT/bin/browser-picker"

echo "== python compile =="
python3 -m py_compile "$ROOT/bin/browser-picker-rules" "$ROOT/bin/browser-picker-recommend"

echo "== bash unit tests =="
bash "$HERE/test_matching.sh"

echo "== python unit tests =="
python3 "$HERE/test_rules.py"
python3 "$HERE/test_recommend.py"

echo "ALL TESTS PASSED"
