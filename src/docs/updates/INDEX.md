# Harness Updates — Index

forge src/ 에서 다운스트림으로 전파되는 모든 변경의 연대기. 각 hash 클릭하면 상세 update doc.

시스템 설명은 [README.md](./README.md) 참조.

---

## 2026 Q2

| Date | Hash | Severity | Type | Title | Breaking |
|------|------|----------|------|-------|----------|
| 2026-04-29 | [round-5-operating-mode](./round-5-operating-mode.md) | P2 | feat | forge round 5 — Operating Mode template + meta-backlog 단일 위치 | no |
| 2026-04-29 | [cee3b30](./cee3b30.md) | P0 | fix | round 4 P0 — upgrade-harness scoped PROJECT_NAME substitution + missing phase wrapper manifest entries | no |
| 2026-04-26 | [e2ee114](./e2ee114.md) | P0 | fix | forge round 3 — scope-leak grep regression + phase split + resume + regression gate + decision protocol | no |
| 2026-04-25 | [8a8f0d5](./8a8f0d5.md) | P0 | fix | forge round 2 — empirical-first / scope-leak / verdict cross-check / spec invariant grep | no |
| 2026-04-25 | [24070b5](./24070b5.md) | P0 | fix | divebase forge-feedback 5건 (monitoring prompt 폭주 / placeholder 치환 / 옛 root rules 정리) | no |
| 2026-04-25 | [bcb8cf9](./bcb8cf9.md) | P0 | fix | bash3 compat + develop-noop guard + install-before-import rule | no |
| 2026-04-24 | [4d02f86](./4d02f86.md) | P1 | feat | check_harness_version auto-apply (Phase 2) | no |
| 2026-04-23 | [8f2cea7](./8f2cea7.md) | P2 | docs | harness updates changelog system (Phase 1) | no |
| 2026-04-23 | [657575d](./657575d.md) | P0 | fix | write_status() multiline value corruption | no |
| 2026-04-23 | [5fdf9ff](./5fdf9ff.md) | P0 | refactor | .claude/rules/ base/local split (Option Y Phase 0) | **yes** |
| 2026-04-23 | [2a2a51a](./2a2a51a.md) | P1 | feat | post-task handoff gate (role-reviewer + SessionEnd hook) | no |
| 2026-04-23 | [b7bbd19](./b7bbd19.md) | P0 | fix | color var hoist in run-task.sh / run-epic.sh | no |

---

## Retroactive (시스템 도입 이전)

위 4건은 2026-04-23 의 `docs/updates/` 시스템 도입 당시 소급 작성. 그 이전 변경(PM-3, PM-2, 등) 은 소급 대상 아님 — forge git log 와 `docs/downstream-feedback/` 참조.

---

## 작성 convention

새 forge 커밋이 `src/` 를 수정하면 같은 커밋에서 `docs/updates/<hash>.md` 동반 생성 + 이 INDEX 상단에 한 줄 추가. 상세는 [README.md](./README.md).
