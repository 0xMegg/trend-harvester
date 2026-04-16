Run the Epic automation script.
This decomposes an Epic into Slices, then runs Plan → Develop → Review for each Slice automatically.

## Instructions

1. Run the epic script in the background:

```bash
./scripts/run-epic.sh $ARGUMENTS
```
Use `run_in_background: true`.

2. Set up a progress monitor using CronCreate (every ~45 seconds):

Use the CronCreate tool with:
- cron: `*/1 * * * *`
- recurring: true
- prompt: `Run "bash ./scripts/epic-monitor.sh" and report the one-line output to me. If the epic background task has already completed, delete this cron job with CronDelete.`

This outputs progress directly in the conversation stream (not in Shell details).
The monitor script uses `#!/bin/bash` so it works regardless of user's default shell.

3. Tell the user: "Epic is running. I'll report progress every ~45 seconds."

4. **Do NOT run any more Bash commands, status checks, or reads until the epic task completes.**

5. When the epic background task completes (automatic notification):
   - Delete the progress monitor CronCreate job
   - Read the output and report the final result concisely
   - If successful: list slices and their verdicts in 2-3 lines
   - If failed: show which slice failed and the log path
