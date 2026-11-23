# dTVSteams Development Roadmap & Feature Tracker (TODO.md)

This roadmap documents the implementation plan for the 4 core enhancements requested for **dTVSteams**. Items are executed sequentially one by one with complete automated testing, UI inspection, and verification on Android device / emulator.

---

## 🎯 Progress Overview

- [x] **Feature 1: Playback Progress & Watch History** *(Completed)*
- [x] **Feature 2: Batch Download & Storage Automation** *(Completed)*
- [x] **Feature 3: Multi-Show & Channel Expansion** *(Completed)*
- [x] **Feature 4: Picture-in-Picture (PiP) & Background Audio** *(Completed)*

---

## 📌 Feature 1: Playback Progress & Watch History

### Goals:
* Remember exact playback timestamp (seconds/ms) across all episodes and parts.
* Allow users to resume watching right where they left off seamlessly.
* Visually display watched progress on the main feed list items (e.g. YouTube-style red progress bar along the bottom of the card or part chips).
* Display "✓ 已看完" status indicator when a part has reached >90% duration.

### Implementation Checklist:
- [x] **1.1 Storage Engine**: Create `PlaybackHistoryManager` (`services/playback_history_manager.dart`) saving to `playback_history.json` via `path_provider` (with in-memory cache and atomic file writes).
- [x] **1.2 Real-time Tracking**: Hook into `VideoPlayerController` in `player_screen.dart` to save current playback timestamp every 2 seconds and upon screen dispose / navigation.
- [x] **1.3 Auto-Resume Prompt**: When opening a previously watched part, automatically seek to the saved timestamp and show an undo action ("從頭播放").
- [x] **1.4 UI Visual Feedback**:
  - Add watch progress bar to each episode card in `YouTubeEpisodeCard` in `main.dart`.
  - Mark completed parts (>90%) with `✓` and in-progress parts with percentage `(XX%)`.
  - Add `✓ 已看完` badge when entire episode is completed.
  - Smart resume: clicking card play button automatically jumps to the latest in-progress or uncompleted part.
- [x] **1.5 History Management**: Add clear and retrieval utilities in `PlaybackHistoryManager`.
- [x] **1.6 Automated Verification**: Added Step 9 BB-07 Playback History & Watch Progress Tracking in `blackbox_playbook_test.dart` (13/13 passing tests).

---

## 📌 Feature 2: Batch Download & Storage Automation

### Goals:
* Download all parts of an episode with a single click ("下載全集 - 包含所有分段").
* Background sequential download queue in `DownloadManager`.
* Smart storage cleanup: option to automatically delete local video file once a part has been watched to completion (>95%).
* Batch delete option in `DownloadsScreen` ("清空所有下載").

### Implementation Checklist:
- [x] **2.1 Batch Download Engine**: Add `startBatchDownload(episode)` in `DownloadManager` to sequentially queue and download Part 1, Part 2, and Part 3.
- [x] **2.2 Sheet UI Enhancement**: Add a prominent "一鍵下載全集 (剩餘 X 個未下載分段)" button at the top of the download selection sheet.
- [x] **2.3 Auto-Cleanup After Watch**: Auto-cleanup suggestion snackbar in player screen when an offline part finishes playing to preserve disk storage, backed by `cleanupWatchedDownload`.
- [x] **2.4 Batch Delete**: Added "清空所有下載檔案" with storage reclaim confirmation dialog and total bytes freed display in `DownloadsScreen`.
- [x] **2.5 Automated Verification**: Added Step 10 BB-08 Batch Download & Storage Automation in `blackbox_playbook_test.dart` (14/14 tests passing).

---

## 📌 Feature 3: Multi-Show & Channel Expansion

### Goals:
* Expand from "綜藝玩很大" to a multi-show hub supporting additional Taiwanese variety programs:
  - 綜藝玩很大 (Mr. Player) - Default
  - 飢餓遊戲 (The Hunger Games)
  - 全明星運動會 (All Star Sports Day)
  - 小明星大跟班 (Super Ent.)
  - 11點熱吵店 (11 O'Clock Hot Shop)
* Clean show selector in `HomeScreen` (sleek top dropdown or side drawer) that maintains high-density layout.
* Independent per-show caching, pagination, search, and download isolation.

### Implementation Checklist:
- [x] **3.1 Show Model & Catalog Registry**: Defined `ShowChannel` model and `ShowChannels` registry (`lib/catalog/show_channel.dart`) with URLs, taglines, icons, and offline fallback episode bundles.
- [x] **3.2 Multi-Category Parser**: Enhanced `CatalogParser.parseList` to support WordPress category templates (`.entry-title a`, `article h2 a`, `ul.lcp_catlist a`) and contextual overview generation across shows.
- [x] **3.3 Show Switcher UI**: Implemented compact, TV-remote-friendly show switcher pill in `HomeScreen` top bar and bottom sheet picker dialog.
- [x] **3.4 Cache & Pagination Isolation**: Implemented `_channelPageCache` isolating pagination, visited pages, and search queries per channel.
- [x] **3.5 Automated Verification**: Added Step 11 BB-09 Multi-Show Channel Expansion & Switcher in `blackbox_playbook_test.dart` (15/15 tests passing).

---

## 📌 Feature 4: Picture-in-Picture (PiP) & Background Audio

### Goals:
* Support Android system Picture-in-Picture (PiP) mode so the video continues playing in a floating thumbnail when the user leaves the app or presses Home.
* In-player PiP toggle button in the OSD controls.
* Background audio playback mode (allow audio to continue with screen locked/off).

### Implementation Checklist:
- [x] **4.1 Android Manifest Configuration**: Add `android:supportsPictureInPicture="true"` and `android:configChanges` to `AndroidManifest.xml`.
- [x] **4.2 PiP MethodChannel Integration**: Implement platform channel in `MainActivity.kt` and Dart wrapper (`pip_manager.dart`) to trigger `enterPictureInPictureMode()`, query capability, and register broadcast receiver callbacks.
- [x] **4.3 Player OSD PiP Button**: Add dedicated PiP icon button in `player_screen.dart` top OSD bar with auto-hide logic during mini floating window mode.
- [x] **4.4 Automatic PiP on Minimize**: Auto-enter PiP on `onUserLeaveHint` when playing video with 16:9 rational aspect ratio.
- [x] **4.5 Automated Verification**: Added Step 12 BB-10 Picture-in-Picture (PiP) & Background Audio in `blackbox_playbook_test.dart` (16/16 tests passing across entire project) and verified on Android emulator `emulator-5554`.
