# Installer Remote-Fetch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `install.sh` be run via `curl -fsSL <url> | bash -s -- <target>` without a prior `git clone`, by auto-detecting when it has no real sibling source files and downloading a tarball instead — while fixing an independent, already-discovered bug where `lib/state.sh` is never installed into the target project at all.

**Architecture:** Two new functions in `install.sh` (`resolve_source_dir`, `fetch_remote_source`) replace the single unconditional `script_dir=...` line. `resolve_source_dir` checks whether `${BASH_SOURCE[0]}` is a real file with `skills/`/`commands/`/`hooks/`/`lib/` siblings (today's `git clone` case); if not, `fetch_remote_source` downloads and extracts a tarball into a temp directory and returns that as the source. A new `copy_lib()` function (called once per install, not per target) fixes the bundled bugfix. All existing copy/hook-registration logic is unchanged and unaware of which mode supplied `script_dir`.

**Tech Stack:** bash, `curl`, `tar` (both already implicitly available on any machine capable of running `install.sh`; no new hard dependency), `jq` (already a project dependency).

## Global Constraints

- No Node.js/npm dependency introduced — bash + `curl` + `tar` only.
- `git clone` + `./install.sh <target>` must continue to work exactly as before — verified by the existing three installer test files passing unmodified.
- The new remote-fetch path must be testable without a real network call — tests use a `CODEFLOW_SOURCE_URL` override pointed at a local `file://` tarball fixture.
- Default remote source URL: `https://github.com/TurboSnails/DevFlow/archive/refs/heads/main.tar.gz` (overridable via `CODEFLOW_SOURCE_URL`).
- Missing `curl` or `tar` must produce a clear one-line error message, not a raw "command not found."
- A failed download must not leave a temp directory behind; a successful remote-fetch install must clean up its temp directory once the whole install run finishes (not before — copy operations read from it throughout the run).
- `copy_lib()` must be called exactly once per install run (client-agnostic), not once per target in the `targets` loop.

---

### Task 1: Fix the `lib/state.sh` install gap

**Files:**
- Modify: `install.sh` (add `copy_lib()` function and one call site)
- Test: `tests/installer_lib_copy_test.sh`

**Interfaces:**
- Consumes: `$script_dir` (already computed by the existing unconditional line at this point in the file — this task runs before Task 2 changes how `script_dir` gets its value, so it can rely on the variable already being set by whatever code precedes it)
- Produces: `lib/state.sh` present at the project root after any install run, for any target — this is what `hooks/dev-flow-gate.sh`, `hooks/freeze-gate.sh`, and `skills/dev-flow/SKILL.md`'s `source lib/state.sh` instruction all depend on

- [ ] **Step 1: Write the failing test**

Create `tests/installer_lib_copy_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
fail() { echo "FAIL: $1"; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && "$INSTALLER" all >/dev/null)
[ -f "$tmp/lib/state.sh" ] || fail "lib/state.sh was not installed"
grep -q "state_init" "$tmp/lib/state.sh" || fail "installed lib/state.sh does not look like the real file"
# Re-running the installer must not fail on the self-copy guard
(cd "$tmp" && "$INSTALLER" all >/dev/null) || fail "reinstall failed"
echo "PASS: installer copies lib/state.sh"
```

Make it executable:

```bash
chmod +x tests/installer_lib_copy_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/installer_lib_copy_test.sh`
Expected: FAIL — `lib/state.sh was not installed`

- [ ] **Step 3: Add `copy_lib()` and call it once per install run**

In `install.sh`, immediately after the existing `copy_gs_commands()` function definition (right before the line `script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`), add:

```bash
copy_lib() {
  mkdir -p lib
  if [ "$script_dir/lib/state.sh" != "$(pwd)/lib/state.sh" ]; then
    cp "$script_dir/lib/state.sh" lib/state.sh
  fi
}
```

Then, immediately after the `script_dir=...` line (still before the `for selected_target in "${targets[@]}"` loop begins), add a single call:

```bash
copy_lib
```

So that section of `install.sh` reads (only the added lines are new; everything else is unchanged context):

```bash
copy_gs_commands() {
  local dir="$1" prefix="$2" command
  mkdir -p "$dir"
  for command in ship freeze office-hours retro cso; do
    cp "$script_dir/commands/gs/${command}.md" "$dir/${prefix}${command}.md"
  done
}
copy_lib() {
  mkdir -p lib
  if [ "$script_dir/lib/state.sh" != "$(pwd)/lib/state.sh" ]; then
    cp "$script_dir/lib/state.sh" lib/state.sh
  fi
}
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
copy_lib
for selected_target in "${targets[@]}"; do
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/installer_lib_copy_test.sh`
Expected: `PASS: installer copies lib/state.sh`

- [ ] **Step 5: Run the existing installer tests to confirm no regression**

Run: `bash tests/installer_integration_test.sh && bash tests/installer_target_selection_test.sh && bash tests/installer_migration_test.sh`
Expected: all three print their `PASS:` line

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/installer_lib_copy_test.sh
git commit -m "fix: install lib/state.sh into target projects (was never copied)"
```

---

### Task 2: Remote-fetch source resolution

**Files:**
- Modify: `install.sh` (replace the unconditional `script_dir=...` line with detection + fetch logic)
- Test: `tests/installer_remote_fetch_test.sh`

**Interfaces:**
- Consumes: `$CODEFLOW_SOURCE_URL` (optional env var override; defaults to the GitHub tarball URL), `curl`, `tar`, `mktemp`, `find`
- Produces: `$script_dir` — exactly as before, just resolved by one of two paths now. Every downstream function (`copy_skill`, `copy_commands`, `copy_gs_commands`, `copy_lib`, the hook-copy lines) is unmodified and unaware of which path supplied it.

- [ ] **Step 1: Write the failing test**

Create `tests/installer_remote_fetch_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"

fail() { echo "FAIL: $1"; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# --- Build a fixture source tree mimicking a GitHub tarball layout
#     (a single top-level directory wrapping the four sibling dirs) ---
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

# --- Case 1: happy path — piped execution (no real BASH_SOURCE file),
#     simulating `curl | bash -s -- claude` ---
project="$WORKDIR/project-happy"
mkdir -p "$project"
(cd "$project" && CODEFLOW_SOURCE_URL="file://$WORKDIR/fixture.tar.gz" bash -s -- claude) < "$INSTALLER" >/dev/null

grep -q "FIXTURE_SKILL_MARKER" "$project/.claude/skills/dev-flow/SKILL.md" || fail "expected skill installed from fetched fixture"
grep -q "FIXTURE_COMMAND_MARKER: start" "$project/.claude/commands/dev-flow/start.md" || fail "expected dev-flow command installed from fetched fixture"
grep -q "FIXTURE_GS_MARKER: ship" "$project/.claude/commands/gs/ship.md" || fail "expected gs command installed from fetched fixture"
grep -q "FIXTURE_LIB_MARKER" "$project/lib/state.sh" || fail "expected lib/state.sh installed from fetched fixture"
[ -f "$project/hooks/dev-flow-gate.sh" ] || fail "expected dev-flow-gate.sh installed from fetched fixture"

# --- Case 2: missing curl -> clear error, no partial state ---
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

# --- Case 3: missing tar -> clear error ---
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

# --- Case 4: download failure (bad URL) -> clear error, temp dir cleaned up ---
project4="$WORKDIR/project-bad-url"
mkdir -p "$project4"
tmp_before="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -newer "$WORKDIR/fixture.tar.gz" 2>/dev/null | wc -l | tr -d ' ')"
if (cd "$project4" && CODEFLOW_SOURCE_URL="file://$WORKDIR/does-not-exist.tar.gz" bash -s -- claude) < "$INSTALLER" >"$WORKDIR/bad-url.out" 2>&1; then
  fail "expected failure when the source URL is unreachable"
fi
grep -q "failed to download" "$WORKDIR/bad-url.out" || fail "expected a clear download-failure message"
tmp_after="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -newer "$WORKDIR/fixture.tar.gz" 2>/dev/null | wc -l | tr -d ' ')"
[ "$tmp_before" = "$tmp_after" ] || fail "expected no leftover temp directory after a failed download"

echo "PASS: installer remote-fetch source resolution"
```

Make it executable:

```bash
chmod +x tests/installer_remote_fetch_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/installer_remote_fetch_test.sh`
Expected: FAIL — the happy-path assertions fail because today's `install.sh` has no remote-fetch branch at all (it will try to resolve `script_dir` from its own real file location and install *this repo's* actual files, not the fixture's marker content — so the `grep -q "FIXTURE_..."` checks fail)

- [ ] **Step 3: Implement `resolve_source_dir` and `fetch_remote_source`, and wire them in**

In `install.sh`, replace this single line:

```bash
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

with:

```bash
resolve_source_dir() {
  local candidate
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$candidate/skills" ] && [ -d "$candidate/commands" ] && [ -d "$candidate/hooks" ] && [ -d "$candidate/lib" ]; then
      echo "$candidate"
      return 0
    fi
  fi
  return 1
}

fetch_remote_source() {
  command -v curl >/dev/null 2>&1 || { echo "Error: curl is required to install CodeFlow without a local checkout." >&2; exit 1; }
  command -v tar >/dev/null 2>&1 || { echo "Error: tar is required to install CodeFlow without a local checkout." >&2; exit 1; }
  local url="${CODEFLOW_SOURCE_URL:-https://github.com/TurboSnails/DevFlow/archive/refs/heads/main.tar.gz}"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if ! curl -fsSL "$url" | tar -xz -C "$tmp"; then
    echo "Error: failed to download CodeFlow source from $url" >&2
    exit 1
  fi
  local extracted
  extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  if [ -z "$extracted" ]; then
    echo "Error: downloaded archive from $url did not contain a source directory" >&2
    exit 1
  fi
  trap - EXIT
  echo "$extracted"
}

if source_dir="$(resolve_source_dir)"; then
  script_dir="$source_dir"
else
  script_dir="$(fetch_remote_source)"
  remote_tmp_root="$(dirname "$script_dir")"
  trap 'rm -rf "$remote_tmp_root"' EXIT
fi
```

Note the trap handling carefully: `fetch_remote_source` is invoked via command substitution (`script_dir="$(fetch_remote_source)"`), which runs the function body in a **subshell**. A `trap ... EXIT` set inside that subshell fires when the subshell itself exits — which happens on every early `exit 1` inside the function (correctly cleaning up on curl/tar-missing or download-failure paths), but would *also* fire immediately after a successful `echo "$extracted"`, deleting the directory before the parent script ever reads from it. The `trap - EXIT` line right before the successful `echo` clears the trap specifically for the success path, so the temp directory survives the subshell's exit. The parent script then derives the temp root from `dirname "$script_dir"` and registers its **own** trap (in the real top-level shell, not a subshell) so the directory is cleaned up once the entire install run finishes — by which point every `copy_*` function has already finished reading from it.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/installer_remote_fetch_test.sh`
Expected: `PASS: installer remote-fetch source resolution`

- [ ] **Step 5: Run the full existing installer test suite to confirm the local-checkout path is unaffected**

Run: `bash tests/installer_integration_test.sh && bash tests/installer_target_selection_test.sh && bash tests/installer_migration_test.sh && bash tests/installer_lib_copy_test.sh`
Expected: all four print their `PASS:` line, confirming `resolve_source_dir` correctly detects the real local checkout in every existing test (none of them are piped — they all invoke `"$INSTALLER"` as a real file path) and nothing changed for that path

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/installer_remote_fetch_test.sh
git commit -m "feat: add remote-fetch source resolution for curl-piped installs"
```

---

### Task 3: Document the curl one-liner

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Interfaces:**
- Consumes: nothing (documentation only)

- [ ] **Step 1: Add the curl one-liner to `README.md`'s Install section**

In `README.md`, find this block:

```markdown
## Install

```bash
git clone git@github.com:TurboSnails/DevFlow.git ~/.codeflow-src
cd /path/to/your-project
~/.codeflow-src/install.sh claude   # or: codex | cursor | all (default: all)
```
```

Replace it with (adding a curl one-liner alongside the existing clone-based flow, not removing the latter):

```markdown
## Install

No clone needed — run this from inside your project:

```bash
curl -fsSL https://raw.githubusercontent.com/TurboSnails/DevFlow/main/install.sh | bash -s -- claude
# or: codex | cursor | all (default: all)
```

Or, if you'd rather inspect the script first (or are contributing to CodeFlow itself):

```bash
git clone git@github.com:TurboSnails/DevFlow.git ~/.codeflow-src
cd /path/to/your-project
~/.codeflow-src/install.sh claude   # or: codex | cursor | all (default: all)
```
```

- [ ] **Step 2: Add the equivalent to `README.zh-CN.md`'s 安装 section**

In `README.zh-CN.md`, find this block:

```markdown
## 安装

```bash
git clone git@github.com:TurboSnails/DevFlow.git ~/.codeflow-src
cd /path/to/your-project
~/.codeflow-src/install.sh claude   # 或者: codex | cursor | all(默认 all)
```
```

Replace it with:

```markdown
## 安装

不用先 clone,在你的项目目录里直接跑:

```bash
curl -fsSL https://raw.githubusercontent.com/TurboSnails/DevFlow/main/install.sh | bash -s -- claude
# 或者: codex | cursor | all(默认 all)
```

如果你想先看一眼脚本内容,或者是在给 CodeFlow 本身贡献代码:

```bash
git clone git@github.com:TurboSnails/DevFlow.git ~/.codeflow-src
cd /path/to/your-project
~/.codeflow-src/install.sh claude   # 或者: codex | cursor | all(默认 all)
```
```

- [ ] **Step 3: Commit**

```bash
git add README.md README.zh-CN.md
git commit -m "docs: document the curl one-liner install path"
```

---

### Task 4: Full-suite regression check

**Files:**
- No new files — verification only

- [ ] **Step 1: Run every test file in the repo**

Run:
```bash
for t in tests/*.sh; do echo "=== $t ==="; bash "$t" || exit 1; done
```
Expected: every file prints a `PASS:` line, no `FAIL:` lines, exit code 0

- [ ] **Step 2: Manually verify the real remote-fetch path against the actual pushed repo (not just the fixture)**

Run, from a throwaway temp directory:
```bash
tmp="$(mktemp -d)"
(cd "$tmp" && curl -fsSL https://raw.githubusercontent.com/TurboSnails/DevFlow/main/install.sh | bash -s -- claude)
[ -f "$tmp/lib/state.sh" ] && [ -f "$tmp/.claude/skills/dev-flow/SKILL.md" ] && echo "Real remote-fetch install succeeded" || echo "Real remote-fetch install FAILED"
rm -rf "$tmp"
```
Expected: `Real remote-fetch install succeeded` — this exercises the actual GitHub tarball URL against the real, currently-pushed `main` branch, which the fixture-based test in Task 2 cannot cover (the fixture proves the *mechanism* works; this proves the *real* default URL and the *real* repo's file layout work together end-to-end)

If this step requires network access that isn't available in the execution environment, note that in the task report as a concern rather than silently skipping it.
