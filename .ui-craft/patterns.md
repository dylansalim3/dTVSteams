# Design Patterns: BoardUI Crimson Mobile-Mirrored UI

## 1. Sticky Mobile-Mirrored Header (`56px`, `max-width: 760px`)
- Sticky frosted top bar (`rgba(23, 23, 23, 0.94)` + `backdrop-filter: blur(12px)`, `1px solid` bottom border `#262626`).
- Left cluster: Square crimson `dTV` badge (`26x26` / `radius: 6px`), `dTVStream` / `STEAMS` wordmark, and interactive Channel Selector Pill (`rounded-full`, chevron indicator) opening the Channel Picker sheet.
- Right cluster (`44px` hit / `36px` icon buttons): Favorites toggle, Watch History, Refresh catalog, Share (`QR + copy link`), and Settings linking directly to `https://github.com/dylansalim3/dTVSteams/releases/latest` (web) or opening Settings sheet (mobile).

## 2. Full-Width Search + Year Filter Rail
- Elevated BoardUI pill/control input (`radius: 10px`, `#171717` / interactive hover border) with live query filtering and optional clear button.
- Horizontal scrollable year filter chips (`全部年份`, `2026`…) + sort direction toggle (`新→舊` / `舊→新`) using high-contrast active pill states.

## 3. Expandable Inline Player Surface
- Collapsible player card (`radius: 16px`, subtle card border) housing the `16:9` `<video>` / Video.js canvas with centered primary Play/Pause button and uncluttered bottom bar (playtime + essential fullscreen/PiP actions only — no `1080p` badges or bottom `±10s` buttons).
- Supports gesture HUDs (vertical brightness/volume, double-tap seek indicator, `2x` hold speed pill, screen lock overlay), Sleep Timer, Audio-only Radio Mode, Picture-in-Picture pause/play controls, and Part switcher pills (`Part 1`, `Part 2`, `Part 3`) with autoplay countdown card.

## 4. Single-Column Episode Cards & Numbered Pagination
- Full-width single-column feed matching Flutter `YouTubeEpisodeCard`: crisp `16:9` thumbnail (`radius: 10px`), watched status pill (`#46d369`), two-line clamped title, metadata row, and `36px`/`44px` quick favorite & play actions.
- Numbered pagination strip (`< 上一頁 [1] [2] … 下一頁 >`) with tabular numerals and page-level loading/error/empty states.

## 5. Multi-Theme & Compact Settings (Flutter Android)
- `ThemePickerSheet`: 20 curated light/dark themes from `21st.dev/themes` + default `boardUiDefault` (`#e50914`), guaranteed contrast-safe `onAccent` / `onSuccess` / `onWarning` foregrounds.
- `CompactSwitchTile`: `0.72`-scaled switches with compact two-line descriptions replacing bulky Material 3 default toggles.
