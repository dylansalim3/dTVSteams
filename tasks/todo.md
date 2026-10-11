## Task 1: catalog-core parser + fixtures

**Description:** Scaffold TS package, save 1 list + 1 episode HTML fixture, implement parseList/parseParts.

**Acceptance criteria:**
- [ ] `parseList` returns 10 items with id/title/date/url from fixture
- [ ] `parseParts` returns 3 part page URLs from fixture
- [ ] No live network in tests

**Verification:**
- [ ] Tests pass: `npm test -- --coverage`
- [ ] Build succeeds: `npm run build`
- [ ] Manual check: parse fixture files locally

**Dependencies:** None

**Files likely touched:**
- `catalog-core/src/parser.ts`
- `catalog-core/tests/parser.test.ts`
- `catalog-core/tests/fixtures/list.html`
- `catalog-core/tests/fixtures/episode.html`

**Estimated scope:** Small: 3-5 files

## Task 2: catalog-core cache + refresh

**Description:** JSON cache with TTL, stale-while-revalidate, manual + on-entry refresh entry points.

**Acceptance criteria:**
- [ ] Cache loads offline <3s
- [ ] Refresh updates JSON + timestamp, failure keeps cache + error flag

**Verification:**
- [ ] Tests pass: `npm test`
- [ ] Build succeeds: `npm run build`
- [ ] Manual check: toggle offline, confirm cached render

**Dependencies:** Task 1

**Files likely touched:**
- `catalog-core/src/cache.ts`
- `catalog-core/tests/cache.test.ts`

**Estimated scope:** Small: 1-2 files

## Checkpoint: Foundation
- [ ] All tests pass
- [ ] Parser handles selector-miss gracefully
- [ ] Review with human before proceeding

## Task 3: web-app browse (home + series)

**Description:** Vite React scaffold, rows/cards from cache, background refresh on entry + manual button.

**Acceptance criteria:**
- [ ] Home renders rows from cache instantly
- [ ] Refresh indicator + timestamp visible
- [ ] Search/filter by title works

**Verification:**
- [ ] Tests pass: `npm test`
- [ ] Build succeeds: `npm run build`
- [ ] Manual check: `npm run dev`, open home

**Dependencies:** Task 2

**Files likely touched:**
- `web-app/src/pages/Home.tsx`
- `web-app/src/hooks/useCatalog.ts`
- `web-app/src/components/Row.tsx`

**Estimated scope:** Medium: 3-5 files

## Task 4: web-app player Parts 1-2-3

**Description:** Player view resolves current Part URLs at click-time, sequential playback.

**Acceptance criteria:**
- [ ] Click episode resolves 3 parts at play-time
- [ ] Auto-advance Part 1->2->3
- [ ] Expired URL failure shows retry, not crash

**Verification:**
- [ ] Tests pass: `npm test`
- [ ] Build succeeds: `npm run build`
- [ ] Manual check: play 1 episode end-to-end

**Dependencies:** Task 3

**Files likely touched:**
- `web-app/src/pages/Player.tsx`
- `web-app/src/components/PlayerView.tsx`

**Estimated scope:** Small: 1-2 files

## Checkpoint: Core web flow
- [ ] End-to-end browse->play works
- [ ] Cached offline open works
- [ ] Review with human before TV port

## Task 5: tv-app scaffold + parser port

**Description:** Android Studio TV module, Kotlin port of Parser/Cache with same fixtures, unit tests.

**Acceptance criteria:**
- [ ] `Parser.kt` passes same 10-item + 3-part assertions
- [ ] No live HTTP in unit tests

**Verification:**
- [ ] Tests pass: `./gradlew :tv-app:testDebugUnitTest`
- [ ] Build succeeds: `./gradlew :tv-app:assembleDebug`
- [ ] Manual check: run on TV emulator, app launches

**Dependencies:** Task 2

**Files likely touched:**
- `tv-app/src/main/java/.../catalog/Parser.kt`
- `tv-app/src/main/java/.../catalog/Cache.kt`
- `tv-app/src/test/.../ParserTest.kt`

**Estimated scope:** Medium: 3-5 files

## Task 6: tv-app browse + player

**Description:** Compose for TV home rows + details + Media3 player with sequential parts, D-pad focus.

**Acceptance criteria:**
- [ ] D-pad navigable rows, focus visible
- [ ] Player plays Parts sequentially
- [ ] Refresh on entry + manual, failure toasts + keeps cache

**Verification:**
- [ ] Tests pass: `./gradlew :tv-app:testDebugUnitTest`
- [ ] Build succeeds: `./gradlew :tv-app:assembleDebug`
- [ ] Manual check: emulator D-pad browse->play

**Dependencies:** Task 5

**Files likely touched:**
- `tv-app/src/main/java/.../ui/HomeScreen.kt`
- `tv-app/src/main/java/.../ui/PlayerScreen.kt`

**Estimated scope:** Medium: 3-5 files

## Checkpoint: Complete
- [ ] All acceptance criteria met
- [ ] Ready for review
