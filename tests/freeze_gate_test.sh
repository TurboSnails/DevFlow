#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/freeze-gate.sh"

fail() { echo "FAIL: $1"; exit 1; }

TMPDIR_TEST="$(mktemp -d)"
export FROZEN_PATHS_FILE="$TMPDIR_TEST/frozen-paths.txt"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

payload() {
  local path="$1"
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$path"
}

# 1. No frozen-paths file at all -> allow
rm -f "$FROZEN_PATHS_FILE"
output="$(payload "lib/core/payment/api.ts" | "$HOOK")"
[ -z "$output" ] || fail "expected allow (no output) when no frozen-paths file exists"

# 2. Frozen directory entry with /** suffix
cat > "$FROZEN_PATHS_FILE" <<'EOF'
lib/core/payment/**
lib/core/auth/keys.json
EOF

output="$(payload "lib/core/payment/api.ts" | "$HOOK")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block for path under frozen directory lib/core/payment/**"

# 3. Similarly-named sibling directory must NOT match (no partial segment matching)
output="$(payload "lib/core/paylater/x.ts" | "$HOOK")"
[ -z "$output" ] || fail "expected allow for lib/core/paylater/x.ts (must not partially match lib/core/payment)"

# 4. Exact frozen file entry (no wildcard)
output="$(payload "lib/core/auth/keys.json" | "$HOOK")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block for exact frozen file lib/core/auth/keys.json"

# 5. Similarly-named sibling file must NOT match
output="$(payload "lib/core/auth/keys.json.bak" | "$HOOK")"
[ -z "$output" ] || fail "expected allow for lib/core/auth/keys.json.bak (must not partially match keys.json)"

# 6. Unrelated path -> allow
output="$(payload "src/index.ts" | "$HOOK")"
[ -z "$output" ] || fail "expected allow for unrelated path"

# 7. Comment lines and blank lines must not cause errors or false blocks
cat >> "$FROZEN_PATHS_FILE" <<'EOF'

# this is a comment
EOF
output="$(payload "src/index.ts" | "$HOOK")"
[ -z "$output" ] || fail "expected allow still, comments/blank lines must not cause errors or false blocks"

# 8. Absolute file_path under a frozen relative directory entry -> block
PROJECT_ROOT="$(mktemp -d)"
FROZEN_ABS="$PROJECT_ROOT/.claude/frozen-paths.txt"
mkdir -p "$(dirname "$FROZEN_ABS")"
cat > "$FROZEN_ABS" <<'EOF'
lib/core/payment/**
EOF
output="$(payload "$PROJECT_ROOT/lib/core/payment/api.ts" | (cd "$PROJECT_ROOT" && FROZEN_PATHS_FILE="$FROZEN_ABS" "$HOOK"))"
echo "$output" | grep -q '"decision":"block"' || fail "expected block for absolute path under frozen directory lib/core/payment/**"

# 9. Absolute file_path NOT under any frozen entry -> allow
output="$(payload "$PROJECT_ROOT/src/index.ts" | (cd "$PROJECT_ROOT" && FROZEN_PATHS_FILE="$FROZEN_ABS" "$HOOK"))"
[ -z "$output" ] || fail "expected allow for absolute path not under any frozen entry"

rm -rf "$PROJECT_ROOT"

echo "PASS: hooks/freeze-gate.sh"
