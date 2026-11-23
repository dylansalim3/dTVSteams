# dTVSteams - Mobile & TV Black Box Testing Playbook

> **Target Application:** `com.dtvsteams.dtvsteams` (Flutter Engine / Android API 34 & Android TV)  
> **Testing Type:** Pure Black Box (End-to-End User Journeys, Visual Outputs, Input Injections, Filesystem Validation)  
> **Version:** 1.0.0  
> **Last Updated:** 2026-11-23

---

## 📋 Table of Contents
1. [Overview & Black Box Principles](#1-overview--black-box-principles)
2. [Prerequisites & Test Environment](#2-prerequisites--test-environment)
3. [Test Suite 1: Cold Boot & Header Integrity (BB-01)](#test-suite-1-cold-boot--header-integrity-bb-01)
4. [Test Suite 2: YouTube-Style 1-by-1 Vertical Feed (BB-02)](#test-suite-2-youtube-style-1-by-1-vertical-feed-bb-02)
5. [Test Suite 3: Search & Discovery Engine (BB-03)](#test-suite-3-search--discovery-engine-bb-03)
6. [Test Suite 4: 1080p Native Video Player & OSD (BB-04)](#test-suite-4-1080p-native-video-player--osd-bb-04)
7. [Test Suite 5: Autoplay Next Part Progression (BB-05)](#test-suite-5-autoplay-next-part-progression-bb-05)
8. [Test Suite 6: Offline Downloads & Downloads Folder (BB-06)](#test-suite-6-offline-downloads--downloads-folder-bb-06)
9. [Test Suite 7: Dynamic Pagination & Infinite Catalog (BB-07)](#test-suite-7-dynamic-pagination--infinite-catalog-bb-07)
10. [Test Suite 8: Remote D-Pad & TV Navigation (BB-08)](#test-suite-8-remote-d-pad--tv-navigation-bb-08)
11. [Automated Execution & CLI Harness](#11-automated-execution--cli-harness)

---

## 1. Overview & Black Box Principles

This playbook specifies the complete end-to-end verification of the `dTVSteams` Flutter client purely from an external user's perspective. 

### Principles:
* **Zero Code Introspection:** Tests evaluate only visible rendered pixels, accessibility labels, user taps/swipes, remote key events, and persisted download files on disk.
* **Deterministic Verification:** Every test scenario defines an explicit **Precondition**, **Input Actions**, **Expected Visual Outcome**, and **Failure Criteria**.
* **Reproducibility:** Every test includes exact ADB / UI automation command lines.

---

## 2. Prerequisites & Test Environment

| Item | Requirement |
| :--- | :--- |
| **Operating System** | Android 14 (API 34) or higher |
| **Form Factor** | Mobile Portrait (`1080x2400`), Foldable, or Android TV (`1920x1080`) |
| **Package ID** | `com.dtvsteams.dtvsteams` |
| **Primary Activity**| `com.dtvsteams.dtvsteams.MainActivity` |
| **Download Storage** | `/data/user/0/com.dtvsteams.dtvsteams/app_flutter/dTVSteams_Downloads/` |
| **Network** | Online (Wi-Fi/Mobile) & Offline (Airplane mode) |

---

## Test Suite 1: Cold Boot & Header Integrity (BB-01)

### BB-01-A: Cold Launch & Branding Verification
* **Goal:** Verify app launches cleanly without crashes or blank black screens.
* **Steps:**
  1. Force stop app: `adb shell am force-stop com.dtvsteams.dtvsteams`
  2. Launch app: `adb shell monkey -p com.dtvsteams.dtvsteams -c android.intent.category.LAUNCHER 1`
  3. Wait 2 seconds for initial render.
* **Expected Outcome:**
  - Red `dTV` badge and white `STEAMS` title are visible at top-left.
  - `📁 下載庫` (Downloads Folder) button is displayed in the header.
  - `🔄 刷新` (Refresh) button is visible.
  - Device indicator pill (`📱 Mobile` or `📺 TV`) is visible.
  - No `RenderFlex overflowed` red/yellow debug banner anywhere on screen.
* **Failure Criteria:** App crashes, freezes on black screen, or shows header overflow.

### BB-01-B: Search Bar Prominence & Absence of Filter Pills
* **Goal:** Verify category filter pills under the search bar have been completely removed.
* **Steps:**
  1. Inspect the area immediately beneath the search input bar.
* **Expected Outcome:**
  - Search bar with placeholder `搜尋集數、日期 (如 2026-11-08) 或地點 (台北、宜蘭)...` is displayed prominently.
  - **No horizontal pills** (`全部 (All)`, `熱門 (Trending)`, `原創 (Originals)`, etc.) exist below the search bar.
  - Feed section title `最新劇集與節目 (Episodes)` directly follows the search bar.
* **Failure Criteria:** Old category pills are still visible.

---

## Test Suite 2: High-Density List View & Direct Chapter Selectors (BB-02)

### BB-02-A: High-Density List View Layout
* **Goal:** Maximize screen real-estate by displaying episodes in a compact list view without empty preview image clutter.
* **Steps:**
  1. Observe the main feed layout on a mobile screen.
* **Expected Outcome:**
  - Episodes are presented as high-density list items (~90px height each).
  - 6 to 8 episodes are immediately visible on screen at once without extensive scrolling.
  - Zero placeholder / empty preview images taking up vertical screen height.
  - Left displays a neat circular red play button indicator.
  - Right displays the quick download action button.
* **Failure Criteria:** Large empty preview image cards displayed or only 1–2 items visible per viewport.

### BB-02-B: Clean Typography & Metadata (Avatar & Match % Removed)
* **Goal:** Verify list items present minimal, essential metadata without visual distraction.
* **Steps:**
  1. Inspect the metadata line underneath each episode title.
* **Expected Outcome:**
  - Displays episode title in crisp bold white text (max 2 lines with clean ellipsis).
  - Subtitle displays clean release date (`2026-11-08`), destination tag (`📍 台北`), and quality badge (`1080p FHD`).
  - **Zero channel avatar** (removed per user specification).
  - **Zero `xx% match`** and **zero `x分段` text** (removed per user specification).
* **Failure Criteria:** Presence of channel avatar circle or presence of `% Match` or `分段` text.

### BB-02-C: Direct Part Quick Selectors
* **Goal:** Verify users can launch specific parts directly from the list item.
* **Steps:**
  1. Inspect the chips under the title block: `▶ Part 1`, `▶ Part 2`, `▶ Part 3`.
  2. Tap `▶ Part 2`.
* **Expected Outcome:**
  - Player opens immediately targeting **Part 2** without having to play Part 1 first.
  - Subtitle inside player confirms `Part 2 • ExoPlayer 1080p Engine`.
* **Failure Criteria:** Tapping `Part 2` opens Part 1 or crashes.

---

## Test Suite 3: Search & Discovery Engine (BB-03)

### BB-03-A: Keyword Search by Location and Date
* **Goal:** Verify real-time list filtering.
* **Steps:**
  1. Tap the search bar.
  2. Type `台北`.
  3. Observe the episode list update.
  4. Type `2026-10-31`.
* **Expected Outcome:**
  - Feed filters in real time without lag.
  - Only episodes matching the query are displayed.
  - Section count indicator updates (e.g., `(1 集)`).
* **Failure Criteria:** List fails to filter or shows non-matching episodes.

### BB-03-B: Search Query Clearing
* **Goal:** Verify quick reset of search filters.
* **Steps:**
  1. Tap the `X` icon inside the search bar.
* **Expected Outcome:**
  - Search field is cleared.
  - Entire episode catalog is immediately restored.
* **Failure Criteria:** `X` icon missing or tap does not clear input.

### BB-03-C: Zero-Match Empty State
* **Goal:** Verify user feedback when no search results exist.
* **Steps:**
  1. Type `ZZZXYZ999` in search bar.
* **Expected Outcome:**
  - Displays centered message: `無符合篩選條件之集數`.
  - App does not crash.
* **Failure Criteria:** Blank screen or uncaught exception.

---

## Test Suite 4: 1080p Native Video Player & OSD (BB-04)

### BB-04-A: Video Launch & ExoPlayer Surface Initialization
* **Goal:** Verify native video stream initialization.
* **Steps:**
  1. Tap the center play button or thumbnail of an episode card.
* **Expected Outcome:**
  - Full-screen black player background appears with `正在連線即時串流... (Connecting live stream)`.
  - Player resolves the stream token and launches native ExoPlayer playback within 2–4 seconds.
  - Broadcast video with SET (三立都會台) watermarks and audio plays smoothly.
* **Failure Criteria:** Endless loading spinner, `Bad state: No active player`, or 404 token error.

### BB-04-B: Auto-Hiding OSD (On-Screen Display)
* **Goal:** Verify controls disappear during playback and reappear on tap.
* **Steps:**
  1. Start playback and leave screen untouched for 4 seconds.
  2. Tap anywhere on the video surface.
* **Expected Outcome:**
  - OSD controls fade out cleanly after 4 seconds of uninterrupted playback.
  - Single tap restores OSD controls immediately.
* **Failure Criteria:** OSD permanently blocks the video or tap fails to reveal controls.

### BB-04-C: Playback Speed Controls
* **Goal:** Verify variable playback speeds.
* **Steps:**
  1. Tap the speed chip at the top right of the player (starts at `1.0x`).
  2. Tap sequentially: observe `1.25x` -> `1.5x` -> `2.0x` -> `1.0x`.
* **Expected Outcome:**
  - Video and audio tempo accelerate proportionally without pitch distortion.
  - Chip text reflects current speed setting.
* **Failure Criteria:** Speed does not change or causes video stutter.

### BB-04-D: Seek Bar & 10s Skip Buttons
* **Goal:** Verify forward and rewind navigation.
* **Steps:**
  1. Tap `10s Forward` button (`Icons.forward_10`).
  2. Tap `10s Rewind` button (`Icons.replay_10`).
  3. Drag the red progress slider to 50%.
* **Expected Outcome:**
  - Timestamp updates immediately.
  - ExoPlayer resumes playing from the target position.
* **Failure Criteria:** Seek resets video to 00:00 or causes endless buffering.

---

## Test Suite 5: Autoplay Next Part Progression (BB-05)

### BB-05-A: Natural Part 1 to Part 2 Transition
* **Goal:** Verify app automatically advances to the next part when the current part reaches the end.
* **Steps:**
  1. Open Part 1 of an episode with 3 parts.
  2. Drag the slider to the final 10 seconds of the video (e.g. `33:55 / 34:03`).
  3. Wait for video to reach completion.
* **Expected Outcome:**
  - A bottom notification toast/banner appears: `分段播放完畢，自動為您播放：Part 2`.
  - Subtitle updates to `Part 2 • ExoPlayer 1080p Engine`.
  - The `Part 2` pill in the parts row turns active red.
  - Live video stream for Part 2 starts playing automatically without user intervention.
* **Failure Criteria:** Player stops at 34:03 and remains frozen on black screen or pauses indefinitely.

### BB-05-B: Final Part Completion Handling
* **Goal:** Verify player behavior when the last part finishes.
* **Steps:**
  1. Open Part 3 (final part).
  2. Seek to last 5 seconds and let it finish.
* **Expected Outcome:**
  - Playback ends gracefully; does not crash.
* **Failure Criteria:** Index out of bounds exception or crash.

---

## Test Suite 6: Offline Downloads & Downloads Folder (BB-06)

### BB-06-A: Triple-Ring Progress Download Button & Multi-Part Selection Popover
* **Goal:** Verify the episode card download button features 3 concentric circular progress rings (one per part), and clicking it opens an interactive popover showing which parts are downloaded and allowing selection of specific parts to download.
* **Steps:**
  1. On Card 1, inspect the download button on the right of the title.
  2. Tap the triple-ring download button.
* **Expected Outcome:**
  - Download button renders a **pie-segmented surround border with 3 quadrants** (thirds) around the central download icon, with **no inner border**:
    - Quadrant 0 represents Part 1.
    - Quadrant 1 represents Part 2.
    - Quadrant 2 represents Part 3.
    - Downloaded parts glow with solid green border arcs (`#46D369`).
    - Active downloads render live progress arcs in red (`#E50914`).
    - Un-downloaded parts display subtle neutral border tracks (`Colors.white24`).
    - The interior of the circle contains only the download icon with zero inner concentric borders.
  - Tapping opens the **下載分段管理 (Multi-Part Selection Popover)**:
    - Clearly shows which parts are already downloaded (green `✓ 已下載完成 (${sizeStr})` with local play & delete options).
    - Clearly shows which parts are un-downloaded with a clean `[下載全集 (1080p FHD)]` button (no 快速版).
    - Tapping the button queues that specific part for background download with live progress.
    - On the main feed card, downloaded parts display distinct dark green backgrounds, green borders, and `Part X (已下載)` text.
* **Failure Criteria:** Popover does not open, part status is not reflected, or rings do not render.

### BB-06-B: Trigger Download from Player OSD
* **Goal:** Verify user can download the currently playing part.
* **Steps:**
  1. While in player, tap the download icon in the top OSD bar.
* **Expected Outcome:**
  - Download begins; download icon shows circular progress indicator.
  - Tapping again while in progress shows a detailed status toast with percentage, downloaded MB, and total MB.
* **Failure Criteria:** Button unresponsive or unmounted.

### BB-06-C: Single Source of Truth, Deduplication, and Cross-Scheme Matching
* **Goal:** Guarantee that an episode part (e.g. `2026-10-31 Part 1`) is never downloaded twice, never duplicated in the manifest or storage list, and is accurately recognized as downloaded regardless of whether it was registered via disk scanner (`Date_Title` ID) or live feed (`URL` ID).
* **Steps:**
  1. Have an episode part downloaded on disk (e.g. `2026-10-31 Part 1`).
  2. Cold boot the app so `init()` loads and prunes manifest/disk files.
  3. Inspect `HomeScreen` feed card for `2026-10-31`.
  4. Inspect `DownloadsScreen` completed downloads list.
  5. Attempt to trigger download for `2026-10-31 Part 1`.
* **Expected Outcome:**
  - `_findItem` and `isDownloaded` match the completed part by date and canonical file path, returning `true`.
  - `HomeScreen` card accurately highlights `Part 1 (已下載)`, `已載 1/3`, and green pie quadrant on the triple-circle button.
  - In `DownloadsScreen`, the episode part is listed exactly once (no duplicate rows, exact total storage byte count).
  - Attempting to download again detects the completed file on disk, logs `Episode is already downloaded`, and aborts without network re-fetching.
  - Manifest is saved without duplicate file paths.
* **Failure Criteria:** Episode is downloaded twice, duplicate entries appear in `DownloadsScreen`, or `isDownloaded` returns `false` due to ID scheme divergence.

### BB-06-C: Dedicated Downloads Folder Screen with Live & Completed Sections
* **Goal:** Verify both active downloads and completed offline files are displayed with live metrics.
* **Steps:**
  1. Tap the `📁 下載庫` button in the top app bar.
* **Expected Outcome:**
  - Opens `下載資料夾 (Downloads)` screen.
  - Storage summary card shows:
    - Total offline storage used (e.g. `70.8 MB`, `316 MB`).
    - File count and active download count (e.g. `1 個分段檔案 (1 個下載中)`).
    - Physical folder path: `/data/user/0/com.dtvsteams.dtvsteams/app_flutter/dTVSteams_Downloads`.
  - **正在下載中 (Active Downloads)** Section:
    - Lists active tasks with part badge, episode title, and pause button.
    - Real-time `LinearProgressIndicator` in red (`#E50914`).
    - Live text statistics: `Percentage% (Downloaded MB / Total MB)` and current download speed (e.g. `1.8 MB/s`).
  - **已完成下載 (Completed Downloads)** Section:
    - Left play icon / thumbnail removed per design specifications to maximize layout breathing room.
    - Useful information stands out clearly:
      - High-contrast red Part badge (`Part 1`, `Part 2`, `Part 3`)
      - Green `[✓ 已下載離線]` status pill and `[1080p FHD]` resolution tag
      - Full episode title across up to 2 lines without cramped single-line truncation
      - Metadata row displaying extracted location (`📍 宜蘭`), air date (`📅 2026-10-18`), and file size (`💾 25.0 MB`)
    - Displays dedicated right `[▶ 播放]` action button and delete button. Whole card is tap-to-play.
    - On HomeScreen feed cards, downloaded parts distinctly stand out with dark green background (`#13381B`), bright green border (`#46D369`), and `Part X (已下載)` indicator.
  - **磁碟重新整理 (Refresh Disk)** button in top right bar scans and reconciles local storage on demand.
* **Failure Criteria:** Screen fails to load, path is missing, active downloads are invisible, or downloaded items do not appear.

### BB-06-D: True Offline Playback (Airplane Mode)
* **Goal:** Verify downloaded files play without internet.
* **Steps:**
  1. Turn off Wi-Fi and Mobile Data: `adb shell svc wifi disable && adb shell svc data disable`.
  2. Open Downloads Screen.
  3. Tap Play on a downloaded episode part.
* **Expected Outcome:**
  - Video plays immediately using `VideoPlayerController.file` from local disk.
  - Subtitle indicates `Part 1 • 本機離線播放`.
  - Playback starts in under 0.5s with zero network buffering.
  4. Restore network: `adb shell svc wifi enable && adb shell svc data enable`.
* **Failure Criteria:** 404 error or network connection error on downloaded content.

### BB-06-E: Resumable Downloads & Space Reclamation
* **Goal:** Verify pausing, resuming (HTTP Range), and deletion removes file and updates storage counter.
* **Steps:**
  1. Pause an active download in `DownloadsScreen`.
  2. Verify item moves to `下載中斷或暫停` with a `繼續下載 (斷點續傳)` play button.
  3. Tap `繼續下載`; verify it resumes from the existing byte offset without redownloading from scratch.
  4. Tap the trash icon on a completed item; tap `刪除` in the confirmation dialog.
* **Expected Outcome:**
  - Item is removed from the list.
  - Total storage used decreases accordingly.
  - File is deleted from disk.
* **Failure Criteria:** Resume starts from byte 0, file remains on disk, or counter does not decrement.

---

## Test Suite 7: Full-Width Numbered Pagination (BB-07)

### BB-07-A: Full-Width Numbered Pagination Bar
* **Goal:** Verify users can navigate catalog pages using a clean, full-width numbered pagination bar (`[< 上一頁] [1] [2] [3] [4] [5] [下一頁 >]`).
* **Steps:**
  1. Scroll to the bottom of the episode feed.
* **Expected Outcome:**
  - Pagination bar spans the full width of the screen (`width: double.infinity`) with comfortable, flexible touch targets.
  - Zero Google logo/icons and zero page count text clutter.
  - Previous page button `[< 上一頁]` is rendered on the left (disabled on Page 1).
  - 5 numbered pills (`[1]`, `[2]`, `[3]`, `[4]`, `[5]`) scale flexibly to fill the bar.
  - Currently active page is highlighted in bold Netflix Red (`#E50914`) with a glowing halo shadow.
  - Inactive pages are styled with dark `#222222` background and white24 borders.
  - Next page button `[下一頁 >]` is rendered on the right.
  - All pagination buttons are wrapped in `TvFocusableButton` for Android TV D-Pad remote navigation.
* **Failure Criteria:** Pagination bar missing, numbers not visible, or bar does not fill width.

### BB-07-B: Direct Page Switching, Caching & Auto-Scroll
* **Goal:** Verify tapping any page number loads that page's episodes, leverages in-memory caching (`_pageCache`), and scrolls back to top smoothly.
* **Steps:**
  1. Tap page `[2]`.
* **Expected Outcome:**
  - Shows subtle inline loading indicator if fetching over network (`/page/2/`).
  - Active page updates to `[2]`, and `[< 上一頁]` becomes enabled.
  - Scroll controller smoothly scrolls back to top (`0.0`).
  - Feed displays page 2 episodes (~10 items).
  - Switching back to page `[1]` is instantaneous due to memory caching (`_pageCache[1]`).
* **Failure Criteria:** Fails to load, active page does not update, or page fails to scroll to top.

---

## Test Suite 8: Remote D-Pad & TV Navigation (BB-08)

### BB-08-A: D-Pad Spatial Navigation
* **Goal:** Verify Android TV remote and Bluetooth controller support.
* **Steps:**
  1. Send D-pad key events:
     - Down: `adb shell input keyevent KEYCODE_DPAD_DOWN`
     - Up: `adb shell input keyevent KEYCODE_DPAD_UP`
     - Select: `adb shell input keyevent KEYCODE_DPAD_CENTER`
* **Expected Outcome:**
  - Active button displays a red glowing halo shadow (`#E50914` blur 16) with scale zoom (`1.05x`).
  - Pressing `DPAD_CENTER` triggers the focused action.
* **Failure Criteria:** No visual focus indicator or D-pad keys ignored.

---

## 11. Automated Execution & CLI Harness

### 1. Run Automated Black Box Playbook Suite:
```bash
cd flutter_app
flutter test test/blackbox_playbook_test.dart
```

### 2. Run Full App Unit & Widget Suites:
```bash
flutter test
```

### 3. Verify on Live Android Device / Emulator via ADB:
```bash
# Check running activity
adb shell dumpsys window | grep -E "mCurrentFocus|mFocusedApp"

# Capture visual verification screenshot
android screen capture --device emulator-5554 --output test_screen.png

# Check persisted downloads directory
adb shell run-as com.dtvsteams.dtvsteams ls -la app_flutter/dTVSteams_Downloads
```
