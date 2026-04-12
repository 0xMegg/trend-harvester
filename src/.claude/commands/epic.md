Run the Epic automation script.
This decomposes an Epic into Slices, then runs Plan → Develop → Review for each Slice automatically.

## Instructions

1. Run the epic script in the background:

```bash
./scripts/run-epic.sh $ARGUMENTS
```
Use `run_in_background: true`.

2. Immediately after, run the status monitor in the background (single command, one approval):

```bash
L=/tmp/{{PROJECT_NAME}}-run/latest; while true; do sleep 45; [ -f "$L/epic-status" ] || { echo "⏱ waiting for epic to start..."; continue; }; ES=$(. "$L/epic-status"; e=$(( $(date +%s) - ${START_EPOCH:-$(date +%s)} )); echo "⏱ $((e/60))m$((e%60))s | ${EPIC_NAME:-?} | Stage ${STAGE:-?}/${STAGE_TOTAL:-?}"); TS=""; for d in "$L"/task-slice-*/ 2>/dev/null; do [ -d "$d" ] || continue; [ -f "$d/task-status" ] || continue; s=$(basename "$d"); TS="$TS$(. "$d/task-status"; r="${ROLE:-?}"; [ -n "${VERDICT:-}" ] && r="${r}[${VERDICT}]"; echo " | $s:$r")"; done; if [ -f "$L/task-status" ]; then TS="$TS$(. "$L/task-status"; r="${ROLE:-?}"; [ -n "${VERDICT:-}" ] && r="${r}[${VERDICT}]"; idx="${TASK_INDEX:-?}"; echo " | seq-${idx}:$r")"; fi; echo "${ES}${TS}"; done
```
Use `run_in_background: true`.

3. Tell the user: "Epic is running. I'll notify you when it completes."

4. **Do NOT run any more Bash commands, status checks, or reads until the epic task completes.**

5. When the epic background task completes (automatic notification), read the output and report the final result concisely.
   - If successful: list slices and their verdicts in 2-3 lines
   - If failed: show which slice failed and the log path
