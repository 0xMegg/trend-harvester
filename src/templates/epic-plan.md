# Epic Plan

## Epic
[Epic number] — [Epic name]

## Goal
[What this feature looks like when fully complete, 2-3 sentences]

## Context
- User need: [what problem this solves for the user]
- Related docs: [design docs, specs, references]
- Dependencies: [external APIs, DB changes, other epics]

## Stages & Slices
Break the epic into independently deliverable slices, grouped into stages.
- **Stages** run sequentially (Stage 2 waits for Stage 1 to finish).
- **Slices within the same Stage** run in parallel and must NOT modify the same files or depend on each other.

If parallelism is not needed, put all slices in a single stage or omit Stage headings entirely (backward compatible — treated as sequential).

**Epic Lite:** 수정 파일 6~9개 + 단일 관심사 → Stage 분해 없이 Slice 1개로 작성.
Opus 4.6은 이 규모를 한 세션에서 일관되게 처리할 수 있다.
(자세한 기준은 `docs/epic-guide.md`의 "Epic Lite" 참조)

### Stage 1
#### Slice 1: [name]
- **What:** [what this slice delivers]
- **Repo:** [target repo name — omit for single-repo]
- **Files:** [expected files to create/modify — multi-repo: use repo prefix e.g. `backend/src/...`]
- **Depends on:** (none)
- **Done when:** [specific acceptance criteria]

#### Slice 2: [name]
- **What:** [what this slice delivers]
- **Repo:** [target repo name]
- **Files:** [expected files]
- **Depends on:** (none)
- **Done when:** [specific acceptance criteria]

### Stage 2
#### Slice 3: [name]
- **What:** [what this slice delivers]
- **Repo:** [target repo name]
- **Files:** [expected files]
- **Depends on:** Stage 1
- **Done when:** [specific acceptance criteria]

### Stage N
#### Slice N: [name]
- **What:** [what this slice delivers]
- **Repo:** [target repo name]
- **Files:** [expected files]
- **Depends on:** [Stage number or "none"]
- **Done when:** [specific acceptance criteria]

## Slicing Principles
- Each slice is independently testable and reviewable
- Data layer before UI (repository → provider → widget)
- Shared/core changes before feature-specific ones
- No slice should touch more than ~5 files

### Parallel Rules (same Stage)
- Slices in the same Stage must NOT modify the same files (전체 워크스페이스 기준, repo별이 아님)
- Multi-repo: 서로 다른 repo만 수정하는 Slice는 파일 겹침이 불가능하므로 병렬 안전
- Slices in the same Stage must NOT have data dependencies on each other
- Each parallel slice must have independent tests
- When in doubt, put slices in separate Stages (sequential is always safe)

## Epic Acceptance Criteria
- [ ] All slices completed and reviewed
- [ ] Lint/analyze passes
- [ ] Tests pass
- [ ] [end-to-end user flow description]

## Open Questions
- [Undecided items that may affect slice scope]

## Rollback Strategy
If the epic must be abandoned mid-way: [which slices are safe to keep, which to revert]
