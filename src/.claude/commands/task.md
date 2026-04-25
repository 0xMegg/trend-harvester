---
model: sonnet
description: Run 3-Role automation (Plan → Develop → Review) for a single task
---

Run the 3-Role automation script for a single task.
This executes Plan → Develop → Review in separate sessions automatically.

## Instructions
Run the following command as a **background task** using `run_in_background: true` with a **10-minute timeout**:

```bash
./scripts/run-task.sh $ARGUMENTS
```

Tell the user the task is running, then **monitor progress every 60 seconds** with a single status check command:

```bash
bash .claude/scripts/check-task-status.sh {{PROJECT_NAME}}
```

**Rules:**
- Check **once per 60 seconds** — not more frequently
- Report each check as a short 1-line status (e.g., "⏱ 1m 30s — develop phase")
- Do NOT read full log files — only run the status command above
- When the background task completes (automatic notification), read the full output and report the final result
- If the script fails, show the relevant log output and suggest next steps
