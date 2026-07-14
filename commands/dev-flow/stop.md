---
name: "Dev Flow: Stop"
description: Stop the current dev-flow cycle and report how far it got
category: Workflow
tags: [workflow, dev-flow]
---

Stop the current dev-flow cycle, if one is running, and report how far
it got. Run this exact shell command from the project root, then report
its output to the user verbatim — do not paraphrase or summarize it
differently:

```bash
source lib/state.sh
if state_exists; then
  feature="$(state_get feature)"
  phase="$(state_get phase)"
  rm -f "$(state_file)"
  echo "Stopped cycle for feature '${feature}' at phase '${phase}'."
else
  echo "No active dev-flow cycle to stop."
fi
```
