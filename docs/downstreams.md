# Downstream Projects

포지가 유지보수하는 다운스트림(사용자 프로젝트) 목록.
경로는 forge repo 루트 기준 상대경로.

Base dir: `../../workouts/`

## Upgrade 대상 (harness 이미 설치됨)

포지/템플릿 변경 시 `upgrade-harness.sh --apply` 로 동기화.

- `../../workouts/divebase`
- `../../workouts/kody-workspace`

## Install 대상 (harness 미설치, git 있음)

새 프로젝트로 편입 시 `setup.sh` 로 최초 설치.

- `../../workouts/char-maker`
- `../../workouts/honbabseoul`

## 미정 (git 없음 — 프로젝트 결정 후 편입)

`.git` 없음. 프로젝트 성격 확정되면 `git init` → install 대상으로 이동.

- `../../workouts/beststcad`
- `../../workouts/haink-workspace`
- `../../workouts/lecture`

## 운영 규칙

- 업데이트는 **forge 세션에서 1개씩**: dry-run 검토 → `--apply`
- 커스텀 보존: `.harness-manifest` 의 `[seed]` 섹션이 프로젝트 로컬 파일(CLAUDE.md, skills/* 등) 보호
- 커밋은 각 다운스트림 repo 의 규칙에 따름 (`.claude/rules/git.md` 참조)
- 한꺼번에 전파 금지 (장애 시 롤백 지점 확보)
