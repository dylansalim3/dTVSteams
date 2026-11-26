# Design Decisions: dTVSteams

### 2026-10-11: Full Netflix Parity Pass
- **Context**: Replaced generic prototype layout with complete Netflix visual and interaction system referencing deepanik/Netflix.
- **Decision 1: Zero External Framework Dependencies for Runtime**: Maintained vanilla ES2022 + CSS variables to ensure zero build overhead, zero hydration lag, and instant offline cache performance.
- **Decision 2: 10-Foot Spatial Engine for TV Web**: Built custom 2D D-pad remote engine (`ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, `Enter`, `Back/ESC`, `1/2/3`) with dynamic Billboard that updates on focus, high-contrast glow focus ring (`4px solid #fff`), and auto-centering scroll.
- **Decision 3: Multi-Part Episode Continuity**: Designed video player with top Part switcher bar (`[Part 1] [Part 2] [Part 3]`) and auto-progression on video end.
- **Decision 4: Accent Budget**: Restricted `--netflix-red` (`#e50914`) to brand mark, top 10 badges, active indicators, and focus highlights to preserve visual hierarchy and prevent noise.

### 2026-11-26: BoardUI Crimson Parity, 20x 21st.dev Themes & Mobile-Mirrored Web Redesign
- **Context**: Evolved the UI architecture from the initial Netflix clone (`deepanik/Netflix`) to the BoardUI design system (`src/react/styles/theme.css`) paired with Flutter Mobile parity and runtime theme customization.
- **Decision 1: Three-Layer BoardUI Crimson Token Spine**: Replaced generic `--netflix-*` literals with neutral-925 `#121212` dark canvas, neutral-900 `#171717` elevated surfaces, `#262626`/`#404040` border rings, Inter + JetBrains Mono composite typography, and differentiated radii (`10px` controls, `16px` cards, `24px` modals, `9999px` pills).
- **Decision 2: Mobile-Mirrored Web Layout (`web-app/` & `src/react/`)**: Replaced the wide Netflix hero/row layout with a `760px` single-column mobile shell mirroring Flutter `HomeScreen` — sticky 56px header with Channel Selector Pill, inline Favorites/History/Refresh/Share actions, direct Settings link to `github.com/dylansalim3/dTVSteams/releases/latest`, full-width Search bar, expandable Player block, and episode feed. Retained 10-foot spatial engine in `tv-web/`.
- **Decision 3: Calm Player Chrome & PiP Controls**: Centered play/pause button inside the video frame, removed `-10s`/`+10s` bottom transport buttons and all `1080p` quality strings, and enabled native PiP play/pause callbacks.
- **Decision 4: 20 Curated `21st.dev` Themes + Sleek Switches**: Added 20 light/dark themes from `21st.dev/themes` alongside `boardUiDefault` (`app_themes.dart`) with automated WCAG contrast resolution (`onAccent`, `onSuccess`, `onWarning`) and replaced chunky Material 3 toggles with `CompactSwitchTile` (`0.72` scale).
