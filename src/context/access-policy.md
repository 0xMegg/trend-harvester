# AI Tool Access Policy

이 문서의 목적은 법무 문체가 아니라,
어디까지는 자동화 편의이고 어디서부터는 사람 승인인지를 빨리 긋는 것.

## Allowed by Default (자동 허용)
- 승인된 작업 폴더 내 Read, Edit, Write
- lint, test, build 명령
- git add, commit, push (Reviewer APPROVE 후)
- managed marketplace의 승인된 plugins

## Requires Human Approval (사람 승인 필요)
- 프로덕션 배포
- 고객 대면 이메일/메시지 발송
- 외부 side effect가 있는 scheduled task
- 프로덕션 데이터베이스 쓰기
- 새로운 MCP 서버 연결
- 새로운 의존성(패키지) 추가

## Blocked (차단)
- `.env*` 파일 읽기/수정
- 파괴적 쉘 명령 (rm -rf, git push --force, git reset --hard)
- 미승인 MCP 서버
- 승인된 저장소 외부 파일 편집
- 시크릿/API키 코드 내 하드코딩

## Permission Scope (적용 범위)
- Managed (IT/조직 강제) > Command line > Local > Project > User
- 팀 공유: CLAUDE.md + .claude/settings.json
- 개인 로컬: CLAUDE.local.md + .claude/settings.local.json
- 이 구분이 중요한 이유: 팀 표준과 개인 편의 설정을 섞지 않기 위함

## 고위험 작업 승인선
- 3개 이상 파일 수정하는 작업 → Planner가 계획 먼저
- 프로덕션 영향 작업 → 반드시 사람 승인
- 민감 데이터 접근 → 격리 환경에서 먼저 시험

## 4층 강제 구조
| 층 | 역할 |
|----|------|
| 문서 (Documentation) | 팀 정책, 승인 기준, 금지 경로, 외부 발송 규칙 |
| 설정 (Configuration) | managed settings, permission rules, plugin/MCP allowlist |
| 실행 중 강제 (Runtime) | hooks, path validation, approval UI, review steps |
| 사후 흔적 (Post-execution) | session trace, diff, review notes, usage records |

이 네 층 중 하나라도 비면 균형이 무너진다.
