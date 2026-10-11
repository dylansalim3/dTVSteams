# Implementation Plan: dTVSteams Personal

## Overview
App-only personal Netflix-style catalog for variety series. Build `catalog-core` parser/cache first (highest risk: third-party HTML), then vertical slice web browse+play, then TV port. No backend.

## Architecture Decisions
- Selectors isolated in parser modules so site changes touch 1 file per platform.
- Cache-first stale-while-revalidate: UI never blocks on network.
- Fixture-based tests, no live HTTP in tests.
- Web first to validate parsing/UX before Kotlin port.

## Dependency Graph
```
fixtures (saved HTML)
  → catalog-core parser + cache
    → web-app browse + player
      → tv-app parser port + browse + player
```

## Task List (index)
- Phase 1: Tasks 1-2 (catalog-core) — see tasks/todo.md
- Checkpoint: Foundation
- Phase 2: Tasks 3-4 (web-app)
- Checkpoint: Core web flow
- Phase 3: Tasks 5-6 (tv-app)
- Checkpoint: Complete

Tasks tracked in `tasks/todo.md`.

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Site HTML changes | High | Selectors in 1 file, fixtures pin behavior |
| Token expiry / hotlink block | High | Resolve at play-time only, fail-soft to cache |
| CORS on web fetch | Med | Use background fetch via extension/proxy note; document limitation in Task 3 |
| TV emulator setup heavy | Low | Defer instrumentation, unit tests only v1 |

## Open Questions
- Confirm single series v1 (綜藝玩很大)?
- Max 1 list page per entry refresh?
