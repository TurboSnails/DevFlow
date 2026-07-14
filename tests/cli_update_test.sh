#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/dev-flow/update.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "update.md does not exist"

SNIPPET="$(sed -n '/^```bash$/,/^```$/p' "$FILE" | sed '1d;$d')"
[ -n "$SNIPPET" ] || fail "no fenced bash snippet found in update.md"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Case 1: install.sh present ---
cat > "$TMPDIR_TEST/install.sh" <<'INSTALLER'
#!/usr/bin/env bash
echo "install.sh ran"
INSTALLER
chmod +x "$TMPDIR_TEST/install.sh"

output="$(cd "$TMPDIR_TEST" && eval "$SNIPPET")"
echo "$output" | grep -q "install.sh ran" || fail "expected install.sh to actually run when present"

# --- Case 2: install.sh absent ---
rm -f "$TMPDIR_TEST/install.sh"
output="$(cd "$TMPDIR_TEST" && eval "$SNIPPET")"
echo "$output" | grep -qi "not available" || fail "expected a plain 'installer not available' message when install.sh is missing"

echo "PASS: commands/dev-flow/update.md behavior"
