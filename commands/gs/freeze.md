---
name: "GS: Freeze"
description: Mark a path as frozen — off-limits for AI-driven edits
category: Workflow
tags: [workflow, gstack-bridge, freeze]
---

Mark a path (file or directory) as frozen: off-limits for AI-driven
edits, enforced by `hooks/freeze-gate.sh`.

**Input**: The argument after `/gs:freeze` is the path to freeze,
relative to the project root, e.g. `/gs:freeze lib/core/payment`.

Run this exact shell command from the project root, then report its
output to the user verbatim:

```bash
path="$ARGUMENTS"
file=".claude/frozen-paths.txt"
mkdir -p "$(dirname "$file")"
touch "$file"
if grep -qxF "$path" "$file"; then
  echo "Already frozen: $path"
else
  echo "$path" >> "$file"
  echo "Frozen: $path"
fi
```

To unfreeze, remove the corresponding line from
`.claude/frozen-paths.txt` directly — there is no separate unfreeze
command.
