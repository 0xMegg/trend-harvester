# Project Contract

## Project
- Name: Trend Harvester
- Type: Harness Self-Improvement System
- Stack: Bash, Markdown, Claude Code Skills

## What It Does
외부 트렌드를 수집 → 5축 필터링 → 실측 검증 → 하네스 템플릿에 자동/수동 적용하는 자기 개선 파이프라인.
결과물(개선된 하네스 템플릿)은 별도 레포에 저장된다.

## Build & Test Commands
- Build template: `bash scripts/build-template.sh`
- Harness report: `bash scripts/harness-report.sh`
- Run harvest: `bash scripts/run-harvest.sh`
- Lint: `shellcheck scripts/*.sh`

## Key Directories
- `src/` — 하네스 템플릿 소스 ({{플레이스홀더}} 포함, 편집 대상)
- `harvest/` — 파이프라인 데이터 (수집/분석/적용 이력)
- `scripts/` — 파이프라인 실행 스크립트
- `outputs/` — 작업 산출물 (plans, reviews, evaluations)

## Output Target
- 빌드된 템플릿 → `../claude-code-harness-template/` 에 배포
- `scripts/build-template.sh`가 src/ → 대상 레포로 복사

## Architecture
- 7-Element Harness: Permissions, Validation, Execution Mode, State, Decision Trace, External Integration, Self-Improvement Loop
- 6-Phase Pipeline: Guard → Collect → Analyze → Measure → Judge → Apply → Report
- Double-Gating: SOFT (5축 filter) + HARD (harness-report 실측)

## Folder Boundaries
- Do NOT modify: `harvest/.seen.json`, `harvest/.lock`
- 템플릿 수정은 반드시 `src/`에서 → build로 반영

## Work Protocol
1. Read the relevant code before modifying
2. Keep changes feature-local first
3. Run lint/analyze after every change
4. Make the smallest change that completes the task
5. Update `handoff/latest.md` with what changed and what's next
6. After modifying src/, run `bash scripts/build-template.sh`

## Restrictions
- Never commit secrets, API keys, or .env files
- Never run `rm -rf` on project directories
- Never force push to main/master
- Never use `git reset --hard` — use `git checkout -- .` for rollback
- Never modify target repo directly — always edit src/ and rebuild

## Self-Improvement (Harvest Module)
- `harvest/config.json` — 수집 소스, 임계값, 스케줄 설정
- `context/harvest-policy.md` — 자동 적용 vs 수동 승인 정책
- `/harvest` — 전체 파이프라인 실행
- `/harvest scan` — 수집만
- `/harvest add <URL/설명>` — 수동 입력
- `/harvest judge` — baseline 측정 + autoresearch
- `/harvest status` — 현황 확인

## References
- `context/harvest-policy.md` — 자동 적용 정책
- `context/working-rules.md` — 워크플로우 규칙 + self-improvement loop
- `docs/harvest-guide.md` — 파이프라인 설명서
- `handoff/latest.md` — 현재 상태
- `templates/evaluation.md` — 작업 평가 (6 metrics)
