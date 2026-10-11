# Spec: catalog-core

## Objective
Shared catalog logic for personal-only Netflix-style apps. Fetches srgoideas.com series/episode HTML app-side (no backend), parses episode title/date/link + Part 1/2/3 playback pages, caches to local JSON with stale-while-revalidate. Serves `web-app` and `tv-app`.
User: owner only. Success = open app sees cached catalog instantly, refresh updates without backend.

Out of scope: redistribution, long-term MP4 URL storage (tokens expire), DRM bypass, full-site scrape.

## Tech Stack
- Language: TypeScript (shared, framework-agnostic)
- HTML parsing: DOMParser (web) / Jsoup-equivalent on TV side port (Kotlin port keeps same selectors)
- Storage: local JSON file + in-memory cache (no DB)
- No backend, no new native deps for v1

## Commands
Build: `npm run build` (web) / `./gradlew :tv-app:assembleDebug` (TV, later)
Test: `npm test -- --coverage`
Lint: `npm run lint`
Dev: `npm run dev`

## Project Structure
```
catalog-core/        → Shared parsing + cache logic (TS source of truth)
  src/parser.ts      → List + episode page parsers (selectors isolated here)
  src/cache.ts       → JSON load/save, TTL, stale-while-revalidate
  tests/fixtures/    → Saved HTML snapshots (1 list page, 1 episode page)
web-app/             → (later module)
tv-app/              → (later module)
CAPABILITY-MAP.md    → Module index
SPEC-catalog-core.md → This spec
```

## Code Style
- Selectors live ONLY in `parser.ts`, never scattered in UI.
- Functions pure: `parseList(html): Episode[]`, `parseParts(html): Part[]`.
- Example:
```ts
export type Episode = { id: string; title: string; date: string; url: string };
export function parseList(html: string): Episode[] { /* DOMParser + querySelectorAll, no regex */ }
```
- Naming: camelCase, files kebab or lower, no abbreviations except `url`, `id`.

## Testing Strategy
- Framework: Vitest (TS).
- Tests live in `catalog-core/tests/`.
- Fixture-based: saved HTML snapshots, assert parser output. No live network in tests.
- Coverage: 100% of parser branches (selector miss, missing Part, empty list).
- Levels: unit only for v1 (no e2e — site is third-party and flaky).

## Boundaries
- Always: use cached catalog on fetch failure; resolve Part URLs at play-time only; keep fixtures offline.
- Ask first: adding backend/cron, adding new series, changing cache schema.
- Never: commit real signed MP4 URLs/tokens, check in full scraped catalogs, add auto-scrape of all 63 pages on every launch.

## Success Criteria
- [ ] `parseList` returns id/title/date/url for 10 items from 1 saved list fixture
- [ ] `parseParts` returns 3 playable page URLs from 1 saved episode fixture
- [ ] Cache loads <3s offline, refresh path callable manually + on-entry
- [ ] Fetch failure shows cached data + error flag, never blank crash
- [ ] `npm test` passes, no live HTTP in tests

## Open Questions
- Start with 綜藝玩很大 only? (assumed yes)
- Max pages per refresh: 1 (assumed) or 2?
