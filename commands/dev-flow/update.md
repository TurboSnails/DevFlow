---
name: "Dev Flow: Update"
description: Refresh this project's dev-flow files via the installer
category: Workflow
tags: [workflow, dev-flow]
---

Refresh this project's dev-flow skill/hook/reference files to the
latest version, if an installer is available. Run this exact shell
command from the project root, then report its output to the user
verbatim — do not paraphrase or summarize it differently:

```bash
if [ -f install.sh ]; then
  bash install.sh
else
  echo "installer not available yet in this project (install.sh not found) - no action taken."
fi
```
