# dTVSteams Development Roadmap & Feature Tracker (TODO.md)

This roadmap documents the implementation plan for the 4 core enhancements requested for **dTVSteams**. Items are executed sequentially one by one with complete automated testing, UI inspection, and verification on Android device / emulator.

---

## 🎯 Progress Overview

- [x] **Feature 1: Playback Progress & Watch History** *(Completed)*
- [x] **Feature 2: Batch Download & Storage Automation** *(Completed)*
- [x] **Feature 3: Multi-Show & Channel Expansion** *(Completed)*
- [x] **Feature 4: Picture-in-Picture (PiP) & Background Audio** *(Completed)*
- [x] **Feature 5: 播放器「長按 2x 倍速快進」與畫面比例縮放（Fit / Fill / 16:9）** *(Completed)*
- [x] **Feature 6: 「我的收藏」與「稍後觀看」清單（Favorites / Watchlist & Bookmarks）** *(Completed)*
- [x] **Feature 7: 「觀看歷史紀錄」專屬管理頁面（Watch History Dedicated Management Screen）** *(Completed)*
- [x] **Feature 8: 播放器「螢幕鎖定防誤觸（Screen Lock OSD）」功能** *(Completed)*

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

---

## 📌 Feature 5: 播放器「長按 2x 倍速快進」與畫面比例縮放（Fit / Fill / 16:9）

### Goals:
* **長按 2x 倍速 (Press-and-Hold 2x Speed)**：
  - 在播放器畫面任意空白處長按時，即刻暫時進入 2.0x 倍速播放，頂部中央浮現半透明膠囊「⚡ 2X 倍速快進中」HUD 動效，並附帶微震動（HapticFeedback）。
  - 手指鬆開即刻還原原先設定的播放速度（如 1.0x、1.25x），HUD 動態淡出。
  - 不與單擊 OSD 切換、雙擊快進退、垂直滑動亮度音量產生衝突。
* **畫面比例縮放模式 (Aspect Ratio Scaling)**：
  - 提供多種畫面適配模式：
    - `Fit（適應螢幕，預設）`：保持原生視訊長寬比，黑邊補全。
    - `Fill（填滿裁剪）`：等比放大填滿整面螢幕，裁切上下或左右黑邊。
    - `Stretch 16:9`：強制 16:9 比例拉伸。
  - 頂部 OSD 或控制列提供直覺圖示切換按鈕，點擊循環切換並彈出 Toast 提示目前比例模式。
* **雙端同步**：Mobile App 與 Web App（支援滑鼠按住與觸控長按）同步具備上述功能。

### Implementation Checklist:
- [x] **5.1 Long-Press 2x Gesture Handler (`player_screen.dart` & `web-app/app.js`)**:
  - 實作長按偵測邏輯，記錄 `_savedSpeedBeforeLongPress`。
  - 長按觸發時呼叫 `controller.setPlaybackSpeed(2.0)`，顯示頂部 `_showSpeedHud`。
  - 長按結束時呼叫 `controller.setPlaybackSpeed(_savedSpeedBeforeLongPress)` 並隱藏 HUD。
- [x] **5.2 Top Speed HUD Widget**:
  - 半透明膠囊背景、快進圖示與 `2X 倍速中` 標籤，平滑透明度過渡。
- [x] **5.3 Aspect Ratio Fit/Fill/Stretch Logic**:
  - 定義 `VideoAspectRatioMode { fit, fill, stretch16x9 }`。
  - 在 `player_screen.dart` 中動態封裝 `FittedBox(fit: BoxFit.contain / BoxFit.cover / BoxFit.fill)`。
  - Web 端透過 `object-fit: contain / cover / fill` 支援相同效果。
- [x] **5.4 Aspect Ratio Switcher OSD Button**:
  - 頂部控制列或設定清單加入切換按鈕，點擊即時輪播並顯示狀態。
- [x] **5.5 Automated Tests**:
  - Flutter 測試與 Web 端 Vitest 測試驗證長按 2x 與畫面縮放。

---

## 📌 Feature 6: 「我的收藏」與「稍後觀看」清單（Favorites / Watchlist & Bookmarks）

### Goals:
* 讓使用者隨時收藏感興趣的節目或特定集數，無縫離線持久化儲存。
* 首頁每張卡片右上角或詳情列加入「❤️ 收藏」或「➕ 稍後觀看」按鈕，即時反饋狀態。
* 導覽列或首頁提供專屬「我的收藏」分頁，支援一鍵直接觀看與批次整理。
* Web App 同步持久化至 `localStorage`。

### Implementation Checklist:
- [x] **6.1 FavoritesManager Engine (`favorites_manager.dart`)**:
  - 記錄收藏集數 ID、標題、封面圖、所屬頻道、加入時間。
  - 支援 `addFavorite`, `removeFavorite`, `isFavorite`, `getFavorites` 與本機 JSON 持久化。
- [x] **6.2 Card & Player Favorite Button**:
  - 首頁 `YouTubeEpisodeCard` 與播放器頂部控制列整合愛心收藏按鈕。
- [x] **6.3 Favorites Tab / Screen**:
  - 新增專屬收藏頁面或分類分頁，呈現收藏節目列表，支援空狀態引導與一鍵續播。
- [x] **6.4 Web App Favorites**:
  - Web 端提供收藏按鈕與收藏清單檢視。
- [x] **6.5 Automated Tests**:
  - 建立 FavoritesManager 單元測試與 UI 元件測試。

---

## 📌 Feature 7: 「觀看歷史紀錄」專屬管理頁面（Watch History Dedicated Management Screen）

### Goals:
* 獨立且視覺豐富的「觀看紀錄（History）」管理介面，讓使用者隨時回頭找尋看過的集數。
* 顯示觀看時間戳、各分段觀看百分比進度條、上次觀看時間。
* 支援個別滑動刪除、一鍵「清空歷史紀錄」與點擊一鍵直接從上次中斷處續播。

### Implementation Checklist:
- [x] **7.1 HistoryScreen UI (`history_screen.dart`)**:
  - 按觀看時間分組顯示（今天、昨天、本週、更早）。
  - 顯示分段進度條、已看完狀態與剩餘時間。
- [x] **7.2 History Actions & Clear Confirmation**:
  - 單項刪除、全部清空對話框。
- [x] **7.3 Navigation & Entry Points**:
  - 首頁頂部或底部選單提供「觀看歷史」快捷入口。
- [x] **7.4 Web App History**:
  - Web 端提供歷史記錄檢視與管理面板。
- [x] **7.5 Automated Tests**:
  - 測試歷史清單排序、刪除與續播觸發。

---

## 📌 Feature 8: 播放器「螢幕鎖定防誤觸（Screen Lock OSD）」功能

### Goals:
* 防止躺著看片或顛簸環境下手持誤觸進度條、切集、退出鍵或左右滑動手勢。
* 側邊浮動鎖定按鈕，點擊後鎖定所有控制項並隱藏 OSD。
* 鎖定期間點擊螢幕僅浮現簡約「🔒 輕觸解鎖」按鈕，連點解鎖或長按解鎖。

### Implementation Checklist:
- [x] **8.1 Lock State Machine (`player_screen.dart` & `web-app/app.js`)**:
  - 引入 `_isScreenLocked` 狀態。
  - 鎖定時凍結所有手勢（垂直亮度音量、雙擊快進退、長按 2x、進度拖曳）。
- [x] **8.2 Floating Lock / Unlock Capsule HUD**:
  - 側邊半透明解鎖鈕，防誤觸機制。
- [x] **8.3 Web App Screen Lock**:
  - Web 端同步鎖定控制列與快捷手勢。
- [x] **8.4 Automated Tests**:
  - 驗證鎖定與解鎖狀態切換。
