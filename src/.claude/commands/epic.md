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
L=/tmp/{{PROJECT_NAME}}-run/latest; while true; do sleep 45; elapsed=$(( $(date +%s) - $(date -r "$L/epic-plan.log" 2>/dev/null || date +%s) )); min=$((elapsed/60)); sec=$((elapsed%60)); status="⏱ ${min}m${sec}s"; for d in "$L"/task-slice-*/; do [ -d "$d" ] || continue; s=$(basename "$d"); p="plan"; [ -f "$d/stdout.log" ] && { grep -q "PHASE 3" "$d/stdout.log" 2>/dev/null && p="review" || { grep -q "PHASE 2" "$d/stdout.log" 2>/dev/null && p="develop"; }; }; v=""; grep -qi "APPROVE" "$d/stdout.log" 2>/dev/null && v="✓"; status="$status | $s:$p$v"; done; echo "$status"; done
```
Use `run_in_background: true`.

3. Tell the user: "Epic 실행 중. 완료되면 알려드리겠습니다."

4. **Do NOT run any more Bash commands, status checks, or reads until the epic task completes.**

5. When the epic background task completes (automatic notification), read the output and report the final result concisely.
   - If successful: list slices and their verdicts in 2-3 lines
   - If failed: show which slice failed and the log path
