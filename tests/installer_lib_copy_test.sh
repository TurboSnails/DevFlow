#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"

fail() { echo "FAIL: $1"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

(cd "$tmp" && "$INSTALLER" all >/dev/null)
[ -f "$tmp/lib/state.sh" ] || fail "lib/state.sh was not installed"
grep -q "state_init" "$tmp/lib/state.sh" || fail "installed lib/state.sh does not look like the real file"

# Re-running the installer must not fail on the self-copy guard.
(cd "$tmp" && "$INSTALLER" all >/dev/null) || fail "reinstall failed"

echo "PASS: installer copies lib/state.sh"
