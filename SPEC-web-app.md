# Spec: web-app

## Objective
Personal-only Netflix-style web UI to browse/search/play variety series. Reads `catalog-core` cache, on-entry auto-refresh + manual refresh button. No backend, static hosting.
User: owner only. Success = open -> see new eps -> play Parts 1/2/3.

## Tech Stack
- Vite 6 + React 18 + TypeScript 5
- Player: native HTML5 video (MP4 direct), Shaka-ready if HLS appears
- Styling: CSS modules, no UI framework for v1
- Deps: `catalog-core` (local import)

## Commands
Build: `npm run build`
Test: `npm test -- --coverage`
Lint: `npm run lint`
Dev: `npm run dev -- --host`

## Project Structure
```
web-app/
  src/pages/       → Home, Series, Player
  src/components/  → Row, Card, PlayerView
  src/hooks/       → useCatalog (cache + refresh)
catalog-core/      → shared parser/cache (imported)
```

## Code Style
- Functional components, hooks, no class components.
- Example:
```tsx
export function EpisodeCard({ ep }: { ep: Episode }) {
  return <a href={`/play/${ep.id}`}>{ep.title}</a>;
}
```

## Testing Strategy
- Vitest + React Testing Library, tests in `web-app/tests/`.
- Mock `catalog-core` fetch, assert cache-first render + refresh flag.
- No live network.

## Boundaries
- Always: show cached rows instantly, refresh in background, fail-soft banner.
- Ask first: adding router lib, adding auth, adding backend.
- Never: store signed MP4 URLs, autoplay with sound, scrape >2 pages per entry.

## Success Criteria
- [ ] Home renders rows from cache <3s offline
- [ ] Manual refresh updates list, shows timestamp
- [ ] Player plays Part 1->2->3 sequentially
- [ ] `npm run build` + `npm test` pass

## Open Questions
- Single series v1? (assumed yes)
