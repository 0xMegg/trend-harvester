# Plugin Guide

## Skill vs Plugin — 언제 승격하는가

| Plugin으로 올릴 때 | Skill로 남길 때 |
|---|---|
| 팀 전체 온보딩을 줄여야 할 때 | 아직 개인 실험 단계일 때 |
| skill + hook + MCP + command 묶어 한 번에 설치해야 할 때 | 단일 루틴, 취향성 세팅 |
| 특정 언어/직무용 작업장을 통째로 배포할 때 | 검증되지 않은 흐름 |

핵심: 실제 사용이 검증을 결정한다 — 중앙 계획이 아님.
실험용 폴더나 샌드박스 저장소에서 먼저 써 보고,
팀 안에서 실사용 반응이 생기면 그때 설치 장터나 공용 plugin으로 올린다.

## Plugin 구조

```
plugin-name/
├── PLUGIN.md           # 설명, 설치법, 의존성
├── skills/             # 포함된 Skill들
├── hooks/              # 자동 개입 규칙
├── .mcp.json           # MCP 연결 설정
├── settings.json       # 권한 설정
└── examples/           # 사용 예시
```

Plugin은 단일 Skill보다 무겁다 — skill, agent, hook, MCP, 설정 파일이
함께 들어갈 수 있기 때문. 설치 전 반드시 포함 파일과 권한 범위를 확인한다.

## 외부 Plugin 보안 체크리스트

1. **SKILL.md 너머까지 확인** — scripts/, assets/, references/ 내용 점검
2. **네트워크 호출 여부** — 외부 URL fetch, API call이 있는가
3. **도구 범위** — allowed-tools가 과도하게 넓지 않은가
4. **필요 권한 수준** — read-only면 충분한가, write/execute까지 필요한가
5. **격리 환경 테스트** — 고객 데이터를 다루는 경우 격리 환경에서 먼저
6. **테스트 계정 사용** — 자동화 기능은 테스트 계정 + 별도 브라우저 프로필로 먼저 시험
7. **팀 배포 시 승인** — 팀 공유 시스템에는 allowlist + 승인 프로세스 후 배포

## 신뢰 순서

1. 공식 저장소 또는 조직 관리 자산
2. 팀 내 검토된 커뮤니티 자산
3. 외부/개인 자산은 격리 테스트 환경에서만

## 배포 전략

- **작은 팀**: skills를 `./.claude/skills`에 두고 함께 버전 관리 (단순)
- **성장하는 팀**: 내부 marketplace 또는 plugin distribution으로 이동 (큐레이션)
- **둘 다 공통**: 실험용 폴더 → 팀 검증 → 공용 배포 흐름을 거친다
