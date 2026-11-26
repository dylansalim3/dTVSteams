# Design Brief: dTVSteams (BoardUI Mobile-Mirrored & Multi-Theme Edition)

### 1. Product purpose (1 sentence)
Streams variety shows and multi-part episodic series (`Part 1 -> Part 2 -> Part 3`) across Android mobile, BoardUI web, and 10-foot TV browsers with cross-part continuity, offline caching, and user-selectable themes.

### 2. Primary user (1 sentence)
A Mandarin/bilingual viewer watching Taiwanese and Asian variety shows during evening commutes on an Android phone or on a desktop/laptop browser mirrored to the same mobile workflow, plus living-room D-pad TV playback.

### 3. Operating principles (conflict-resolution order)
1. **Accessibility & WCAG contrast win over theme flavor** — Any selected theme (from the 21st.dev 20-theme catalog or light/dark BoardUI modes) must auto-compute high-contrast `onAccent`, `onSuccess`, and `onWarning` foregrounds and preserve keyboard/screen-reader reachability on every interactive control. *(Supersedes generic style rules when colors conflict.)*
2. **Playback continuity & calm player chrome over dense transport controls** — Center the primary play/pause trigger in the video frame, strip redundant bottom transport buttons (`-10s`/`+10s`, `1080p` quality clutter) down to essential time and fullscreen/PiP actions, and keep background PiP pause/play always active.
3. **Mobile-first parity across web and Flutter** — The primary web shell (`web-app/` and `src/react/`) mirrors the Flutter Android app verbatim: sticky single-column `760px` header, brand + channel selector pill, inline favorite/history/refresh/share/settings icon actions, search bar, inline collapsible mini/expanded player, and dense channel/episode rows.
4. **BoardUI tokens only — zero raw palette leaks in product surfaces** — UI surfaces consume BoardUI primitives, semantic roles, composite typography utilities, and component tokens (`CompactSwitchTile`, `AppCardTokens`) across both light and dark modes; pure `#000000` canvas and raw off-scale hex values are rejected.
5. **Restrained, sleek interactive controls** — Favor compact switches (`0.72` scale), `4px`/`8pt` spacing rhythm, differentiated corner radii (`control: 10px`, `card: 16px`, `modal: 24px`, `pill: 9999px`), and short `150–250ms` ease-out transitions.

#### Superseded Prior Principles (Archive)
- ~~**2026-10-11** — Full Netflix Billboard Hero & Left Desktop Rail Parity~~ — deprecated **2026-11-26**: user redirected the web and mobile product direction to BoardUI Crimson design rules and exact Flutter mobile single-column UI parity (header Share + Settings direct APK link), retaining TV 10-foot support only in `tv-web/`.

### 4. Success metric for the surface (1-2 sentences)
User locates a show via channel switcher or search, starts multi-part playback, or toggles favorites/theme/history within 15 seconds on first visit without squinting at low-contrast active states or navigating away from the primary stream list.

### 5. Out of scope
- User accounts, login walls, subscriptions, or server-side profiles (preferences, theme choice, playback timestamps, and favorites stay local)
- Multi-column marketing landing billboards, promo carousels, or Netflix-style hover expansion posters on the primary mobile-mirrored web view
- In-player resolution pickers (`1080p` badges) or redundant `±10s` bottom bar transport buttons (double-tap horizontal seek overlay remains available)
- Complex multi-step onboarding wizards or blocking modal gates on first launch

### 6. Learned constraints (append-only)
- **2026-11-25** — Center play button in the middle of the player; remove `-10s`/`+10s` transport buttons from the bottom bar keeping only playtime, and remove all `1080p` badges/references. *Why:* cleaner, uncluttered video canvas.
- **2026-11-25** — Enable pause/play actions inside Picture-in-Picture (PiP) mode (`player_screen.dart`). *Why:* users multitask in floating window and expect direct media controls.
- **2026-11-25** — Adopt BoardUI (`boardui.com`) design system and install `@/` BoardUI components + tokens across React web and apply the same token structure cleanly in Flutter. *Why:* unified, accessible design language instead of bespoke styling.
- **2026-11-26** — Include theme selection in mobile Settings populated with 20 curated themes from `21st.dev/themes` plus the default BoardUI crimson theme, verified with automated smoke contrast checks across selected/unselected states on every view. *Why:* personalization without unreadable active/inactive labels.
- **2026-11-26** — Move Share into the top bar alongside Settings, have the web Settings icon open `https://github.com/dylansalim3/dTVSteams/releases/latest`, and redesign the web app to mirror the Android Flutter UI layout (`max-width: 760px`). *Why:* one cohesive product mental model across phone and browser.
- **2026-11-26** — Make on/off toggle switches visibly smaller and sleeker (`CompactSwitchTile` at `0.72` scale). *Why:* standard Material 3 switches look overly bulky inside dense card/sheet rows.

### 7. Fold classes used (append-only)
- **2026-11-26** — `product-dominant` — mobile-mirrored single-column web shell (`web-app/` & `src/react/`): leads immediately with header toolbar, search bar, expandable player surface, and episode feed with zero marketing preamble.
