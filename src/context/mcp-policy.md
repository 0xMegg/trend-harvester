# MCP & External Integration Policy

## Allowed by Default
- Read, Edit, Write inside approved workspaces
- lint, test, build commands
- approved plugins from managed marketplace

## Requires Human Approval
- deployment to production
- customer-facing email/message send
- scheduled tasks with external side effects
- database writes to production
- new MCP server connection

## Blocked
- reading `.env*` files
- destructive shell commands
- unapproved MCP servers
- editing outside approved repositories

## MCP Evaluation Checklist
새로운 MCP를 연결하기 전 반드시 확인:
- [ ] 출처 확인 (공식 / 커뮤니티 / 개인)
- [ ] 필요한 권한 범위 (read-only vs read-write)
- [ ] 유지보수 상태 (최근 업데이트 날짜)
- [ ] 컨텍스트 비용 (도구 설명이 항상 올라오는가, 필요 시만 호출되는가)
- [ ] 조직 정책과의 충돌 여부

## 연결 원칙
- "무엇을 더 붙일까"보다 "이 연결이 사람이 하던 어떤 단계를 줄이는가" 먼저
- MCP는 길을 열어주는 층, Skill은 그 길을 어떤 방식으로 사용할지 정하는 층
- 연결은 많을수록 좋은 것이 아니라, 세션을 무겁게 만들지 않는 선에서 유지

## Connector vs MCP 구분
- Connector: 사용자가 설정 UI에서 서비스를 연결하는 표면 (앱 장터에서 서비스 연결)
- MCP: 개발자/고급 사용자가 서버/도구 인터페이스를 설계하는 층 (회사 내부 배선반 설계)
- MCP 표준이라는 말이 "아무 서버나 바로 연결해도 된다"는 뜻은 아님
- 출처, 권한 범위, 유지보수 상태를 먼저 보고, 자주 쓰는 연결만 천천히 붙이기

## MCP Allowlist Template
프로젝트에서 사용이 승인된 MCP 목록 (초기화 세션에서 채우기):
- {{APPROVED_MCP_1}} — {{MCP_1_PURPOSE}}
- {{APPROVED_MCP_2}} — {{MCP_2_PURPOSE}}
