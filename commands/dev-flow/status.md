---
name: "Dev Flow: Status"
description: Report the current dev-flow cycle's phase and progress
category: Workflow
tags: [workflow, dev-flow]
---

Report the current dev-flow cycle's state without modifying anything.
Run this exact shell command from the project root, then report its
output to the user verbatim — do not paraphrase or summarize it
differently:

```bash
source lib/state.sh
if state_exists; then
  feature="$(state_get feature)"
  phase="$(state_get phase)"
  blocks="$(state_get blocks)"
  echo "feature=${feature} phase=${phase} blocks=${blocks}"
else
  echo "No active dev-flow cycle."
fi
```
