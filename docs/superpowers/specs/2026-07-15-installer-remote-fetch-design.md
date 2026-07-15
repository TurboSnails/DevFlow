# Installer Remote-Fetch Design

## Context

`install.sh` currently requires the user to `git clone` the CodeFlow repo first, because it locates its own source files via `script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` and copies `skills/`, `commands/`, `hooks/` from beside itself. That resolution breaks when the script is piped into `bash` (e.g. `curl -fsSL <url> | bash -s -- claude`), since `BASH_SOURCE[0]` has no real file path in that mode. Researching a related open-source project (`spec-superflow`, which fuses OpenSpec + Superpowers into a single portable workflow plugin across 17 client platforms) surfaced that its Cursor installer already supports a zero-clone `curl | node -` flow; the equivalent bash-only pattern for CodeFlow is a `curl | bash` one-liner backed by a tarball download, with no new hard dependency (still just `bash`, `curl`, `tar`, `jq` — no Node/npm).

## Goals / Non-Goals

**Goals:**
- `install.sh` remains the single entry point (no separate bootstrap script, no new file for users to discover).
- Existing `git clone` + `./install.sh <target>` usage is unaffected — same code path, same behavior, verified by the existing test suite without modification.
- A new zero-clone path: `curl -fsSL <raw-install.sh-url> | bash -s -- <target>` works by auto-detecting that it has no real script file to resolve siblings from, then downloading a tarball of the repo and using that as the source directory instead.
- The remote-fetch path is testable without hitting the real network (a `CODEFLOW_SOURCE_URL` override pointed at a local `file://` tarball fixture).
- Clear, actionable error messages if `curl`/`tar` are missing or the download/extraction fails — no half-cleaned-up temp state left behind.

**Non-Goals:**
- Not publishing to npm or introducing any Node.js runtime dependency — this is a bash-only feature, matching the project's existing zero-framework philosophy.
- Not adding a Claude Code plugin-marketplace listing (a separate, larger distribution question, deliberately out of scope for this change).
- Not adding version/ref pinning (`--ref v1.2.3`) in this pass — always fetches the `main` branch tarball. A pinned-version fetch is a natural future extension once the project has tags/releases, not needed now.
- Not adding caching of the downloaded tarball across runs — each remote-fetch invocation downloads fresh into a temp directory and cleans up after itself. Acceptable for now; revisit if repeated re-installs become a real pain point.

## Decisions

**1. Detection is "does a real, sibling-having script file exist," not "was I piped."**
Rather than trying to detect pipe-vs-file execution directly (fragile across shells/platforms), the check is: is `${BASH_SOURCE[0]}` a real file on disk, AND do `skills/`, `commands/`, `hooks/`, `lib/` all exist next to it? If both hold, use that directory as the source (local-checkout mode, unchanged from today). Otherwise, fall through to remote-fetch. This correctly handles the piped case (no real `BASH_SOURCE[0]` file) and also degrades gracefully if someone runs a standalone copy of `install.sh` with the sibling directories missing for any other reason — rather than silently doing the wrong thing, it fetches a known-good full source tree.

**2. Remote-fetch downloads a GitHub tarball and reuses the exact same copy logic — no parallel implementation.**
`fetch_remote_source()` downloads `${CODEFLOW_SOURCE_URL:-https://github.com/TurboSnails/DevFlow/archive/refs/heads/main.tar.gz}` into a fresh `mktemp -d` directory, extracts it, and returns the path to the (single) extracted top-level directory (GitHub tarballs always extract to one `<repo>-<branch>/` directory). That path becomes `script_dir` for the rest of the script — `copy_skill`, `copy_commands`, and the hook-registration logic are completely unaware of which mode produced their `script_dir` value. This is the core design choice that keeps the change small: one new function plus one new call site, no duplication of install logic.

**3. `CODEFLOW_SOURCE_URL` is the test seam.**
Tests for the remote-fetch path build a real tarball fixture (e.g., tar up a small fixture tree with `skills/`, `commands/`, `hooks/`, `lib/`) and point `CODEFLOW_SOURCE_URL` at its `file://` path. `curl` fetches `file://` URLs the same way it fetches `https://` ones, so the exact same `fetch_remote_source()` code runs in tests as in production — no test-only branching in the implementation.

**4. Missing `curl`/`tar` is checked explicitly before use, with a clear message.**
Rather than letting a missing-binary shell error surface confusingly (`command not found` deep inside a pipeline), `fetch_remote_source()` checks `command -v curl` and `command -v tar` up front and fails with a one-line, actionable message if either is absent.

## Risks / Trade-offs

- [Risk] A `curl | bash` one-liner is an inherent trust-the-source pattern (the user is running arbitrary remote code). → Mitigation: this is an accepted, precedented pattern (the same one `spec-superflow`'s own Cursor installer and countless other CLI tools use) — not introducing a new class of risk, just matching existing convention, and it's opt-in (the `git clone` path remains fully supported for anyone who wants to inspect the script first).
- [Risk] Always fetching `main` means a user could get a moving target between two remote-fetch installs on the same day, with no way to reproduce an exact prior install. → Mitigation: explicitly deferred (see Non-Goals) — acceptable for a pre-release project with no version/tag process yet; revisit once tags exist.
- [Trade-off] No caching means every remote-fetch install re-downloads the full tarball, even for repeated installs into different projects on the same machine. Accepted — the tarball is small and this keeps the implementation simple; a cache would need invalidation logic that isn't justified yet.

## Migration Plan

Purely additive to `install.sh` — one new function (`fetch_remote_source`), one new call site replacing the unconditional `script_dir=...` line with the two-branch detection described in Decision 1, no changes to `copy_skill`/`copy_commands`/hook-registration logic. No existing behavior changes for the `git clone` + local-run path. Rollback is reverting the `install.sh` diff; nothing external depends on the new function existing.

## Open Questions

None outstanding.
