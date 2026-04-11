# Harness Forge

Claude Code 하네스를 자동으로 개선하는 self-improvement 파이프라인.

외부 트렌드를 수집하고, 프로젝트 철학에 맞는지 필터링하고, 실제 효과를 측정한 뒤에만 적용한다.

> "외부 세계가 빠르게 변하므로 시스템도 진화해야 한다. 단, 맹목적이지 않게."

## How It Works

```
Phase 0  Guard       ─  lock + cooldown
Phase 1  Collect     ─  WebFetch, WebSearch, 수동 입력, 내부 피드백
Phase 2  Analyze     ─  5축 Fitness Filter (임계값 6/10)
Phase 3  Measure     ─  harness-report baseline
Phase 3.5 Judge      ─  임시 적용 → 재측정 → keep/discard
Phase 4  Apply       ─  정책 기반 자동/수동 적용
Phase 5  Report      ─  실행 보고서 생성
```

모든 제안은 **Double-Gating**을 통과해야 한다:
1. **SOFT gate** — 5축 점수 >= 6 (프로젝트에 적합한가?)
2. **HARD gate** — harness-report 실측 (실제로 개선되는가?)

## Quick Start

```bash
cd harness-forge
claude

# 현황 확인
/harvest status

# 수동으로 규칙 제안
/harvest add "bash 스크립트에 set -euo pipefail 누락 시 경고"

# 외부 트렌드 수집
/harvest scan

# 전체 파이프라인
/harvest
```

## 5-Axis Fitness Filter

| 축 | 질문 | 0 | 1 | 2 |
|----|------|---|---|---|
| Automation | 수동 단계를 줄이는가? | 영향 없음 | 부분 축소 | 완전 제거 |
| Friction | 기존 함정을 방지하는가? | 무관 | 간접 관련 | 직접 방지 |
| HARD conversion | exit code로 강제 가능? | 불가 | 경고만 | 직접 강제 |
| Token efficiency | 토큰을 줄이는가? | 영향 없음 | 간접 개선 | 측정 가능 |
| Measurability | 단일 지표로 추적? | 불가 | 간접 추적 | 직접 추적 |

총 10점 만점, **6점 이상**이면 Gate 2(실측)로 진행.

## Auto-Apply Policy

| 조건 | 동작 |
|------|------|
| rule/scaffold-rule + score >= 7 + risk low + harness 유지 | 자동 적용 |
| new-skill, hook, config 변경 | 승인 필요 |
| 삭제, risk high, harness 하락 | 차단 |

## Project Structure

```
harness-forge/
├── CLAUDE.md                    # 프로젝트 계약서
├── .claude/
│   ├── commands/harvest.md      # /harvest 커맨드
│   └── skills/                  # 3개 스킬
│       ├── trend-harvest/       #   파이프라인 오케스트레이션
│       ├── fitness-filter/      #   5축 점수 산출
│       └── harness-report/      #   하네스 품질 측정
├── scripts/
│   ├── run-harvest.sh           # 파이프라인 오케스트레이터 (참조용)
│   ├── harness-report.sh        # 하네스 점수 측정 (0-100)
│   └── build-template.sh        # src/ → 하네스 템플릿 레포 배포
├── harvest/
│   ├── config.json              # 수집 소스 + 임계값 설정
│   ├── baseline.json            # 현재 harness 점수
│   ├── applied/                 # 적용 이력
│   └── reports/                 # 실행 보고서
├── src/                         # 하네스 템플릿 소스 (배포 대상)
│   ├── .claude/
│   │   ├── hooks/               # 6 훅 (block-dangerous, post-edit-check/lint/test,
│   │   │                        #        post-edit-size-check, pre-commit-branch-check)
│   │   └── rules/               # api/frontend/testing/git/gotchas
│   ├── .mcp.json.example        # MCP 서버 스캐폴드 (사용자가 .mcp.json으로 복사·편집)
│   ├── scripts/
│   │   ├── run-task.sh          # 3-Role + 자동 task/{id} 브랜치
│   │   ├── run-epic.sh          # Epic + overlap gate + worktree opt-in
│   │   ├── diagnose.sh          # 실패 상태 자동 진단 (exit 0/1)
│   │   └── mcp-check.sh         # .mcp.json 인라인 토큰·scope 검증
│   ├── context/
│   │   ├── mcp-policy.md        # MCP 연결 체크리스트 + .mcp.json 가이드
│   │   └── working-rules.md     # 세션 분할 체크리스트 + 파일 크기 상한
│   └── docs/
│       ├── epic-guide.md        # Epic 분할 + 병렬 안전장치
│       └── troubleshooting.md   # 5개 실패 시나리오 복구
├── context/
│   └── harvest-policy.md        # 프로젝트 자체 적용 정책 (2단계 판단 의무)
├── docs/harvest-guide.md        # 파이프라인 상세 가이드
└── templates/                   # 제안서/보고서 형식
```

> `src/context/` vs 루트 `context/`: 루트는 **harvester 자체 운영 정책**(파이프라인이 참고), `src/context/`는 **템플릿으로 배포되는 운영 가이드**(프로젝트가 참고).

## Hardening Highlights (2026-04)

외부 트렌드 + 자체 운영 피드백을 파이프라인으로 적용한 최근 강화 항목:

| 영역 | 변경 | 효과 |
|------|------|------|
| Context 예산 | `working-rules.md` 세션 분할 체크리스트 + 파일 크기 상한 + `post-edit-size-check.sh` 훅 | 편집 시 `CLAUDE.md>200`, `rules/*>50`, `context/*>150` 초과 자동 경고 |
| 실패 복구 | `docs/troubleshooting.md` + `scripts/diagnose.sh` | 5개 시나리오(run-task mid-fail, Reviewer loop, slice 충돌, hook 실패, lock 잔존) 자동 스캔 + 복구 명령 |
| 브랜치 격리 | `run-task.sh` `task/{id}` / `run-epic.sh` `epic/{RUN_ID}` 자동 분기 + `pre-commit-branch-check.sh` 훅 | main 직접 커밋 차단 (exit 2), APPROVE 시 ff-only 자동 병합, `HARVEST_ALLOW_MAIN=1` 우회 |
| 병렬 안정성 | `run-epic.sh` overlap gate (상시) + `HARVEST_PARALLEL_WORKTREE=1` git worktree 격리 (opt-in) | slice 간 파일 충돌 사전 차단, 선택적 워크트리 완전 격리 |
| MCP 실전 설정 | `.mcp.json.example` 스캐폴드 + `mcp-policy.md` 5항목 체크리스트 + `scripts/mcp-check.sh` 검증기 | inline 토큰(`ghp_*`, `sk-*`, `sk-ant-*`, `xoxX-*`, `AKIA...`) 감지, `command` 필드 누락 차단, bare `/`·`~` scope 거부 |
| Harness score 포화 해제 | `harness-report.sh` 8영역 재설계 + Rules/Guidance 깊이 메트릭 + Hooks/Scripts HARD enforcement 카운트 | Phase 3.5 Gate 2 판별력 복원 — 이전 체계에서 src/ 65/100 고정 → 현재 53/100 + headroom 47. 규칙 1개(300줄) 추가 시 +6점 이동 실측 확인 |

상세 적용 내역은 `harvest/applied/` 각 JSON과 `handoff/latest.md` 참고.

## Relationship with Harness Template

```
harness-forge/            claude-code-harness-template/
(이 레포)                  (결과물 레포)
    │                          │
    │  src/ 편집               │  순수 하네스 템플릿
    │  build-template.sh ──→   │  (플레이스홀더 포함)
    │                          │
    │  harvest pipeline        │  프로젝트에 복사해서
    │  로 src/ 개선            │  사용하는 대상
    └──────────────────────    └──────────────────
```

- **이 레포**: 하네스를 만들고, 측정하고, 개선하는 시스템
- **[harness-template](https://github.com/0xMegg/claude-code-harness-template)**: 시스템이 만든 결과물

## Harness Score

`bash scripts/harness-report.sh`로 측정. 8개 영역, 100점 만점 (2026-04-11 포화 방지 재설계).

| 영역 | 배점 | 측정 기준 |
|------|------|-----------|
| Rules | 20 | 파일 수(max 10) + 유효 라인 수 tier (200/400/600/800/1200) |
| Skills | 15 | 스킬 수 + examples + Gotchas/Context Required 섹션 |
| Hooks | 15 | 파일 수 + 전원 실행권한 보너스 + HARD exit/return 1 강제 수 |
| Guidance | 10 | `context/` + `docs/` 파일 수 + 유효 라인 수 tier (200/500/1000/1500/2500) |
| Scripts | 10 | 파일 수 + `exit 1/2` 또는 `set -euo pipefail` 강화 수 |
| Templates | 10 | 파일 수 + 채워진 비율 (%) |
| Evaluations | 10 | 평가 기록 수 (`outputs/evaluations/*.md`) |
| Test/Lint | 10 | shellcheck + 프로젝트 테스트 통과율 (full 모드만) |

> 재설계 이유: 이전 6개 영역 체계는 `rules 15/20, skills 20/20, hooks 15/15, templates 15/15`에서 포화해 Phase 3.5 HARD 게이트가 무력화됐다. 깊이 기반 메트릭(유효 라인 수)과 HARD enforcement 카운트(실제 `exit 1/2` 사용 수)를 도입해 Gate 2의 판별력을 복원했다. `context/` + `docs/`를 포함하는 `Guidance`와 hardening을 측정하는 `Scripts` 카테고리가 신설됐다.

## License

Private
