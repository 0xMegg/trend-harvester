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
Must verify before connecting a new MCP:
- [ ] Source verification (official / community / individual)
- [ ] Required permission scope (read-only vs read-write)
- [ ] Maintenance status (date of last update)
- [ ] Context cost (are tool descriptions always loaded, or invoked only on demand?)
- [ ] Conflict with organizational policies

## Connection Principles
- Before asking "what else can we add," ask "which manual step does this connection eliminate?"
- MCP is the layer that opens the path; Skills are the layer that defines how to use that path
- More connections is not better — maintain only what does not weigh down the session

## Connector vs MCP Distinction
- Connector: the surface where users connect services via a settings UI (like connecting a service from an app marketplace)
- MCP: the layer where developers/power users design the server/tool interface (like designing the internal wiring panel for a company)
- "MCP standard" does not mean "any server can be connected without review"
- Check the source, permission scope, and maintenance status first, then gradually add only frequently used connections

## MCP Allowlist Template
Approved MCPs for this project (populate during initialization session):
- {{APPROVED_MCP_1}} — {{MCP_1_PURPOSE}}
- {{APPROVED_MCP_2}} — {{MCP_2_PURPOSE}}

## New MCP Pre-Connection Checklist
MCP 서버는 **프로젝트 루트의 `.mcp.json`** (또는 플러그인 설정) 에 정의한다. Claude Code settings.json 스키마는 서버 정의를 허용하지 않는다 — `settings.json` 에는 `enabledMcpjsonServers` / `allowedMcpServers` / `disabledMcpjsonServers` 같은 정책 필드만 둔다. 스캐폴드는 `.mcp.json.example` 로 리포에 동봉되며, 사용자가 `.mcp.json` 으로 복사해 편집한다.

통과 여부는 `bash scripts/mcp-check.sh` 가 자동 검증 (exit 1 on violation).

1. **Scope** — 이 MCP 가 어떤 디렉토리·레포·리소스에만 접근해야 하는가? `args` 에 구체 경로를 명시했는가? 와일드카드(`/`, `~`)는 피한다.
2. **Secret handling** — API 키·토큰은 반드시 `env` + `${VAR_NAME}` 형태. 리터럴 값(`ghp_*`, `sk-*`, `xoxb-*`, `gho_*`, `xoxp-*`, `sk-ant-*`)이 `.mcp.json` 에 들어가면 즉시 차단.
3. **Failure mode** — 서버 다운·타임아웃·인증 실패 시 예상 동작은? 세션 전체가 멈추는가, 해당 툴만 실패하는가? 확실치 않으면 on-demand 로만 활성화.
4. **On-demand vs resident** — 툴 설명이 컨텍스트에 항상 로드되는가? 자주 쓰지 않으면 기본 비활성화하고 필요할 때만 켠다 (`working-rules.md` "MCP Residency Cost" 참고).
5. **Token/비용** — 어떤 호출이 돈을 쓰는가? `Requires Human Approval` 섹션의 규칙을 위반하는 호출은 없는가?

### 설정 예시 (검증된 스캐폴드 — `.mcp.json.example`)
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${HOME}/Dev/<project>"],
      "description": "scope: Dev/<project> 만 (상위 디렉토리 금지)"
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
    }
  }
}
```

사용:
```bash
cp .mcp.json.example .mcp.json
# edit, then:
bash scripts/mcp-check.sh
# settings.json 에 허용/차단 목록 갱신:
#   "enabledMcpjsonServers": ["filesystem", "github"]
```

`.mcp.json` 은 `.gitignore` 에 추가 (토큰/경로 유출 방지). `.mcp.json.example` 만 커밋.
