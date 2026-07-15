#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [claude|codex|cursor|all] [--dry-run]

Install CodeFlow integrations for one project-local client. The default target is all.
EOF
}

fail() {
  echo "Error: $1" >&2
  usage >&2
  exit 1
}

target="all"
dry_run=false
target_supplied=false

for argument in "$@"; do
  case "$argument" in
    --dry-run)
      dry_run=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    claude|codex|cursor|all)
      "$target_supplied" && fail "only one installation target may be supplied"
      target="$argument"
      target_supplied=true
      ;;
    *)
      fail "unsupported target '$argument'; supported targets: claude, codex, cursor, all"
      ;;
  esac
done

if "$dry_run"; then
  echo "Dry run: no files will be written."
fi

echo "Selected target: $target"

if [ "$target" = "all" ]; then
  targets=(claude codex cursor)
else
  targets=("$target")
fi

for selected_target in "${targets[@]}"; do
  echo "Planned target: $selected_target"
done

for name in state config; do
  if [ "$name" = "config" ]; then
    legacy=".claude/dev-flow.config.json"
    canonical=".codeflow/dev-flow.config.json"
  else
    legacy=".claude/dev-flow-state.json"
    canonical=".codeflow/dev-flow-state.json"
  fi
  if [ -f "$legacy" ] && [ -f "$canonical" ]; then
    echo "dev-flow migration conflict: both $legacy and $canonical exist; resolve the ${name} files manually, then rerun install.sh." >&2
    exit 1
  fi
  if [ -f "$legacy" ]; then
    if "$dry_run"; then
      echo "Planned migration: $legacy -> $canonical"
      continue
    fi
    mkdir -p .codeflow
    mv "$legacy" "$canonical"
  fi
done

if "$dry_run"; then
  exit 0
fi

copy_skill() { mkdir -p "$1"; cp -R "$script_dir/skills/dev-flow/." "$1/"; }
copy_commands() {
  local dir="$1" prefix="$2" target="$3" command destination
  mkdir -p "$dir"
  for command in start stop status update; do
    destination="$dir/${prefix}${command}.md"
    cp "$script_dir/commands/dev-flow/${command}.md" "$destination"
    if [ "$command" = update ]; then
      sed -i.bak "s/bash install.sh/bash install.sh ${target}/" "$destination"
      rm -f "${destination}.bak"
    fi
  done
}
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for selected_target in "${targets[@]}"; do
  case "$selected_target" in
    claude)
      copy_skill .claude/skills/dev-flow; copy_commands .claude/commands/dev-flow "" claude
      mkdir -p hooks
      if [ "$script_dir/hooks/dev-flow-gate.sh" != "$(pwd)/hooks/dev-flow-gate.sh" ]; then
        cp "$script_dir/hooks/dev-flow-gate.sh" hooks/dev-flow-gate.sh
      fi
      settings=.claude/settings.json; mkdir -p .claude
      [ -f "$settings" ] || echo '{}' > "$settings"
      jq 'if any(.hooks.Stop[]?.hooks[]?; .command == "bash hooks/dev-flow-gate.sh") then . else .hooks.Stop = ((.hooks.Stop // []) + [{matcher:"",hooks:[{type:"command",command:"bash hooks/dev-flow-gate.sh"}]}]) end' "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"
      echo "claude.continuation_gate=enabled";;
    codex) copy_skill .codex/skills/dev-flow; echo "codex.continuation_gate=unavailable";;
    cursor) copy_skill .cursor/skills/dev-flow; copy_commands .cursor/commands "dev-flow-" cursor; echo "cursor.continuation_gate=unavailable";;
  esac
done
