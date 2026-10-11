# Spec: tv-app

## Objective
Personal-only Android TV app, Netflix-style Leanback browse + play. Same model as web: cached catalog, on-entry refresh + manual refresh, play-time Part URL resolve. Sideload only, no Play release.
User: owner on TV. Success = D-pad browse -> play without phone/PC.

## Tech Stack
- Language: Kotlin
- UI: Compose for TV (`androidx.tv:tv-material`), Leanback launcher only
- Player: Media3 ExoPlayer (`androidx.media3:media3-exoplayer`, `media3-ui`)
- MinSdk 31 (Android 12 TV), targetSdk 34
- Logic: Kotlin port of `catalog-core` selectors (same `parseList`/`parseParts` contract)

## Commands
Build: `./gradlew :tv-app:assembleDebug`
Test: `./gradlew :tv-app:testDebugUnitTest`
Lint: `./gradlew :tv-app:lintDebug`
Dev: `Android Studio → Run 'tv-app' on TV emulator (1080p, API 34)`

## Project Structure
```
tv-app/
  src/main/java/.../catalog/ → Parser.kt, Cache.kt (port of catalog-core)
  src/main/java/.../ui/      → HomeScreen.kt, DetailsScreen.kt, PlayerScreen.kt
  src/main/AndroidManifest.xml → LEANBACK_LAUNCHER, uses-feature leanback
  src/test/                  → ParserTest (fixture HTML, no network)
```

## Code Style
- Compose functions, no XML layouts except manifest.
- Example:
```kotlin
@Composable
fun EpisodeRow(episodes: List<Episode>, onClick: (Episode) -> Unit) {
  TvLazyRow { items(episodes) { Text(it.title, modifier = Modifier.clickable { onClick(it) }) } }
}
```
- Parser selectors centralized in `Parser.kt` only.

## Testing Strategy
- JUnit + Robolectric for parser/cache, no instrumentation for v1.
- Fixture HTML in `src/test/resources/`, assert 10 items + 3 parts.
- UI: manual D-pad check on emulator for v1.

## Boundaries
- Always: focus-visible, D-pad navigable, cache-first, background refresh.
- Ask first: adding accounts, recommendations, backend sync.
- Never: commit signed URLs, bypass Play policy (sideload only), block UI thread on fetch.

## Success Criteria
- [ ] Home shows cached rows, D-pad navigable
- [ ] Refresh on entry + manual, failure shows cache + toast
- [ ] Player plays Parts sequentially via Media3
- [ ] `./gradlew :tv-app:testDebugUnitTest` passes, no live HTTP in tests

## Open Questions
- None for v1 — Compose for TV + Media3 locked.
