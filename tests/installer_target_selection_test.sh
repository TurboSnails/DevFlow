#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/../install.sh"

fail() { echo "FAIL: $1"; exit 1; }

[ -x "$INSTALLER" ] || fail "install.sh must be executable"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir" /tmp/codeflow-installer-invalid.out' EXIT

for target in claude codex cursor all; do
  fixture="$tmpdir/$target"
  mkdir -p "$fixture"
  output="$(cd "$fixture" && "$INSTALLER" "$target")"
  echo "$output" | grep -q "Selected target: $target" || fail "expected $target to be selected"
done

mkdir -p "$tmpdir/default"
output="$(cd "$tmpdir/default" && "$INSTALLER")"
echo "$output" | grep -q "Selected target: all" || fail "expected all to be the default target"

if (cd "$tmpdir" && "$INSTALLER" unsupported) >/tmp/codeflow-installer-invalid.out 2>&1; then
  fail "unsupported target must fail"
fi
grep -q "claude, codex, cursor, all" /tmp/codeflow-installer-invalid.out || \
  fail "unsupported target must list supported targets"

dryrun="$tmpdir/dry-run"
mkdir -p "$dryrun"
before="$(find "$dryrun" -print | LC_ALL=C sort)"
output="$(cd "$dryrun" && "$INSTALLER" --dry-run all)"
after="$(find "$dryrun" -print | LC_ALL=C sort)"
[ "$before" = "$after" ] || fail "dry run must not create files in the working directory"
echo "$output" | grep -q "Dry run" || fail "dry run must be identified in output"
for target in claude codex cursor; do
  echo "$output" | grep -q "Planned target: $target" || fail "dry run must list $target"
done

echo "PASS: installer target selection"
