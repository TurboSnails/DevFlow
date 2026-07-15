#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"

fail() { echo "FAIL: $1"; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Build a fixture source tree mimicking a GitHub tarball layout.
FIXTURE_ROOT="$WORKDIR/fixture-src/codeflow-fixture-main"
mkdir -p "$FIXTURE_ROOT/skills/dev-flow/references"
mkdir -p "$FIXTURE_ROOT/commands/dev-flow" "$FIXTURE_ROOT/commands/gs"
mkdir -p "$FIXTURE_ROOT/hooks" "$FIXTURE_ROOT/lib"

echo "FIXTURE_SKILL_MARKER" > "$FIXTURE_ROOT/skills/dev-flow/SKILL.md"
for c in start stop status update; do
  echo "FIXTURE_COMMAND_MARKER: $c" > "$FIXTURE_ROOT/commands/dev-flow/${c}.md"
done
for c in ship freeze office-hours retro cso; do
  echo "FIXTURE_GS_MARKER: $c" > "$FIXTURE_ROOT/commands/gs/${c}.md"
done
printf '#!/usr/bin/env bash\necho FIXTURE_HOOK\n' > "$FIXTURE_ROOT/hooks/dev-flow-gate.sh"
printf '#!/usr/bin/env bash\necho FIXTURE_HOOK\n' > "$FIXTURE_ROOT/hooks/freeze-gate.sh"
printf 'state_init() { :; } # FIXTURE_LIB_MARKER\n' > "$FIXTURE_ROOT/lib/state.sh"

tar -C "$WORKDIR/fixture-src" -czf "$WORKDIR/fixture.tar.gz" codeflow-fixture-main

# Case 1: piped execution has no local source siblings and fetches the fixture.
project="$WORKDIR/project-happy"
mkdir -p "$project"
(cd "$project" && CODEFLOW_SOURCE_URL="file://$WORKDIR/fixture.tar.gz" bash -s -- claude) < "$INSTALLER" >/dev/null

grep -q "FIXTURE_SKILL_MARKER" "$project/.claude/skills/dev-flow/SKILL.md" || fail "expected skill installed from fetched fixture"
grep -q "FIXTURE_COMMAND_MARKER: start" "$project/.claude/commands/dev-flow/start.md" || fail "expected dev-flow command installed from fetched fixture"
grep -q "FIXTURE_GS_MARKER: ship" "$project/.claude/commands/gs/ship.md" || fail "expected gs command installed from fetched fixture"
grep -q "FIXTURE_LIB_MARKER" "$project/lib/state.sh" || fail "expected lib/state.sh installed from fetched fixture"
[ -f "$project/hooks/dev-flow-gate.sh" ] || fail "expected dev-flow-gate.sh installed from fetched fixture"

# Case 2: missing curl produces a clear error.
BINDIR_NO_CURL="$WORKDIR/bin-no-curl"
mkdir -p "$BINDIR_NO_CURL"
for bin in bash mkdir cp sed mv jq tar mktemp find head cat rm; do
  ln -sf "$(command -v "$bin")" "$BINDIR_NO_CURL/$bin"
done
project2="$WORKDIR/project-no-curl"
mkdir -p "$project2"
if (cd "$project2" && PATH="$BINDIR_NO_CURL" CODEFLOW_SOURCE_URL="file://$WORKDIR/fixture.tar.gz" bash -s -- claude) < "$INSTALLER" >"$WORKDIR/no-curl.out" 2>&1; then
  fail "expected failure when curl is unavailable"
fi
grep -q "curl is required" "$WORKDIR/no-curl.out" || fail "expected a clear 'curl is required' message"

# Case 3: missing tar produces a clear error.
BINDIR_NO_TAR="$WORKDIR/bin-no-tar"
mkdir -p "$BINDIR_NO_TAR"
for bin in bash mkdir cp sed mv jq curl mktemp find head cat rm; do
  ln -sf "$(command -v "$bin")" "$BINDIR_NO_TAR/$bin"
done
project3="$WORKDIR/project-no-tar"
mkdir -p "$project3"
if (cd "$project3" && PATH="$BINDIR_NO_TAR" CODEFLOW_SOURCE_URL="file://$WORKDIR/fixture.tar.gz" bash -s -- claude) < "$INSTALLER" >"$WORKDIR/no-tar.out" 2>&1; then
  fail "expected failure when tar is unavailable"
fi
grep -q "tar is required" "$WORKDIR/no-tar.out" || fail "expected a clear 'tar is required' message"

# Case 4: failed download produces a clear error and leaves no temp directory.
project4="$WORKDIR/project-bad-url"
mkdir -p "$project4"
: > "$WORKDIR/bad-url.out"
tmp_before="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -newer "$WORKDIR/fixture.tar.gz" 2>/dev/null | wc -l | tr -d ' ')"
if (cd "$project4" && CODEFLOW_SOURCE_URL="file://$WORKDIR/does-not-exist.tar.gz" bash -s -- claude) < "$INSTALLER" >"$WORKDIR/bad-url.out" 2>&1; then
  fail "expected failure when the source URL is unreachable"
fi
grep -q "failed to download" "$WORKDIR/bad-url.out" || fail "expected a clear download-failure message"
tmp_after="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -newer "$WORKDIR/fixture.tar.gz" 2>/dev/null | wc -l | tr -d ' ')"
[ "$tmp_before" = "$tmp_after" ] || fail "expected no leftover temp directory after a failed download"

echo "PASS: installer remote-fetch source resolution"
