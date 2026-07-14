#!/usr/bin/env bash
# hooks/dev-flow-gate.sh - Stop hook that forces dev-flow to continue
# until the cycle reaches done/paused/await-approval, or the 40-block
# safety cap is hit.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/state.sh"

BLOCK_CAP=40

if ! state_exists; then
  exit 0
fi

phase="$(state_get phase)" || exit 0
case "$phase" in
  done|paused|await-approval)
    exit 0
    ;;
esac

blocks="$(state_get blocks)" || exit 0
if [ "$blocks" -ge "$BLOCK_CAP" ]; then
  exit 0
fi

state_increment_blocks

cat <<EOF
{"decision":"block","reason":"dev-flow 进行中(当前阶段: $phase)。请继续执行下一阶段并更新状态文件。若用户已明确要求停止,请先执行 /dev-flow:stop。"}
EOF
