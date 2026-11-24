import { describe, it, expect, beforeEach } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { JSDOM } from "jsdom";

describe("YouTube Web App UI & Video.js Compliance", () => {
  const htmlPath = path.resolve(__dirname, "../web-app/index.html");
  const cssPath = path.resolve(__dirname, "../web-app/app.css");
  const jsPath = path.resolve(__dirname, "../web-app/app.js");
  const catalogPath = path.resolve(__dirname, "../web-app/catalog.json");

  it("loads web-app files properly", () => {
    expect(fs.existsSync(htmlPath)).toBe(true);
    expect(fs.existsSync(cssPath)).toBe(true);
    expect(fs.existsSync(jsPath)).toBe(true);
    expect(fs.existsSync(catalogPath)).toBe(true);
  });

  it("contains YouTube-style brand header and search navigation", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const dom = new JSDOM(html);
    const doc = dom.window.document;

    // YouTube Header
    const header = doc.querySelector("header.yt-header");
    expect(header).not.toBeNull();

    // YouTube brand logo and title
    expect(doc.querySelector(".yt-brand-title")?.textContent).toBe("dTVStream");
    expect(doc.querySelector(".yt-brand-sub")?.textContent).toBe("綜藝玩很大");
    expect(doc.querySelector(".yt-logo-badge")).not.toBeNull();

    // YouTube search bar
    expect(doc.querySelector("#q")).not.toBeNull();
    expect(doc.querySelector("#search-clear-btn")).not.toBeNull();
    expect(doc.querySelector("#refresh-btn")).not.toBeNull();
    expect(doc.querySelector("#catalog-status")).not.toBeNull();
  });

  it("contains Theater Video.js Player section and Part selector", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const dom = new JSDOM(html);
    const doc = dom.window.document;

    // Theater Player
    const playerSection = doc.querySelector(".yt-player-section");
    expect(playerSection).not.toBeNull();

    const video = doc.querySelector("video#main-player");
    expect(video).not.toBeNull();
    expect(video?.classList.contains("video-js")).toBe(true);
    expect(video?.classList.contains("vjs-theme-yt")).toBe(true);

    // Metadata & Badges under player
    expect(doc.querySelector("#player-title")).not.toBeNull();
    expect(doc.querySelector("#player-part-badge")).not.toBeNull();
    expect(doc.querySelector("#player-date-badge")).not.toBeNull();
    expect(doc.querySelector("#player-stream-status")).not.toBeNull();
    expect(doc.querySelector("#player-parts-nav")).not.toBeNull();
    expect(doc.querySelector("#open-source-btn")).not.toBeNull();
    expect(doc.querySelector("#download-btn")).not.toBeNull();
    expect(doc.querySelector("#download-menu")).not.toBeNull();
    expect(doc.querySelector("#share-btn")).not.toBeNull();
    expect(doc.querySelector("#share-modal")).not.toBeNull();
    expect(doc.querySelector("#share-qr-container")).not.toBeNull();
    expect(doc.querySelector("#share-copy-btn")).not.toBeNull();
    expect(doc.querySelector("#player-resume-toast")).not.toBeNull();
  });

  it("contains Simple YouTube Episode List Grid (no Netflix fake recommendations)", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const dom = new JSDOM(html);
    const doc = dom.window.document;

    const listSection = doc.querySelector("#episodes-section");
    expect(listSection).not.toBeNull();

    const grid = doc.querySelector("#episodes-grid");
    expect(grid).not.toBeNull();

    expect(doc.querySelector("#episode-count-badge")).not.toBeNull();

    // Netflix fake elements should be eliminated
    expect(doc.querySelector("#billboard")).toBeNull();
    expect(doc.querySelector("#moviemodal")).toBeNull();
    expect(doc.querySelector(".n-series-badge")).toBeNull();
  });

  it("verifies YouTube CSS tokens and styling in app.css", () => {
    const css = fs.readFileSync(cssPath, "utf-8");
    expect(css).toContain("--yt-bg: #0f0f0f");
    expect(css).toContain("--yt-red: #ff0000");
    expect(css).toContain("--yt-surface: #181818");
    expect(css).toContain("--yt-card-bg: #212121");
    expect(css).toContain(".yt-episodes-grid");
    expect(css).toContain(".yt-card");
    expect(css).toContain(".yt-card-part-btn");
    expect(css).toContain(".yt-thumb-progress");
    expect(css).toContain(".yt-resume-toast");
  });

  it("verifies YouTube Footer and keyboard shortcuts guide", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const dom = new JSDOM(html);
    const doc = dom.window.document;

    const footer = doc.querySelector("footer.yt-footer");
    expect(footer).not.toBeNull();
    expect(footer?.textContent).toContain("Space / Enter");
    expect(footer?.textContent).toContain("1 / 2 / 3");
  });

  it("implements localStorage resume persistence in web-app app.js", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const js = fs.readFileSync(jsPath, "utf-8");
    const dom = new JSDOM(html, { runScripts: "dangerously", url: "http://localhost/" });
    const win = dom.window as any;

    // Evaluate web-app script in JSDOM window context
    win.eval(js);
    win.initPlayer();

    expect(typeof win.saveResume).toBe("function");
    expect(typeof win.getEpisodeResume).toBe("function");
    expect(typeof win.clearEpisodeResume).toBe("function");
    expect(typeof win.formatTime).toBe("function");

    // Test formatTime
    expect(win.formatTime(75)).toBe("01:15");
    expect(win.formatTime(3665)).toBe("1:01:05");

    // Test localStorage persistence
    const testId = "https://srgoideas.com/test-ep-resume/";
    win.saveResume(testId, 1, 350, 2100);

    const saved = win.getEpisodeResume(testId);
    expect(saved).not.toBeNull();
    expect(saved.episodeId).toBe(testId);
    expect(saved.partIndex).toBe(1);
    expect(saved.currentTime).toBe(350);
    expect(saved.percentage).toBe(17);
    expect(saved.completed).toBe(false);

    // Test clear
    win.clearEpisodeResume(testId);
    expect(win.getEpisodeResume(testId)).toBeNull();
  });

  it("implements playback speed controls and persistence in web-app app.js", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const js = fs.readFileSync(jsPath, "utf-8");
    const dom = new JSDOM(html, { runScripts: "dangerously", url: "http://localhost/" });
    const win = dom.window as any;

    win.eval(js);
    win.initPlayer();

    expect(typeof win.applyPlaybackSpeed).toBe("function");
    expect(typeof win.cycleSpeed).toBe("function");
    expect(Array.isArray(win.SPEED_STEPS)).toBe(true);
    expect(win.SPEED_STEPS).toContain(1.25);
    expect(win.SPEED_STEPS).toContain(1.5);
    expect(win.SPEED_STEPS).toContain(2.0);

    // Apply speed 1.5x
    win.applyPlaybackSpeed(1.5, false);
    expect(win.localStorage.getItem("dtv_playback_rate")).toBe("1.5");

    const badge = win.document.getElementById("player-speed-badge");
    expect(badge?.textContent).toContain("1.5x");

    // Cycle speed forward
    win.cycleSpeed(1); // 1.5 -> 1.75
    expect(win.localStorage.getItem("dtv_playback_rate")).toBe("1.75");
    expect(badge?.textContent).toContain("1.75x");
  });

  it("implements debounced seeking and quick skip buttons", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const js = fs.readFileSync(jsPath, "utf-8");
    const dom = new JSDOM(html, { runScripts: "dangerously", url: "http://localhost/" });
    const win = dom.window as any;

    win.eval(js);
    win.initPlayer();
    win.initPlayer();

    expect(typeof win.seekRelative).toBe("function");

    // Quick skip buttons present
    expect(win.document.getElementById("skip-back-10")).not.toBeNull();
    expect(win.document.getElementById("skip-fwd-10")).not.toBeNull();
    expect(win.document.getElementById("skip-fwd-30")).not.toBeNull();
    expect(win.document.getElementById("skip-fwd-60")).not.toBeNull();

    // Trigger seek
    win.seekRelative(30);
    const hud = win.document.getElementById("yt-seek-hud");
    expect(hud).not.toBeNull();
    expect(hud.textContent).toContain("+30s");
  });

  it("generates correct clean download filenames for parts and episodes", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const js = fs.readFileSync(jsPath, "utf-8");
    const dom = new JSDOM(html, { runScripts: "dangerously", url: "http://localhost/" });
    const win = dom.window as any;
    win.eval(js);
    win.initPlayer();

    expect(typeof win.getDownloadFilename).toBe("function");

    const ep1 = {
      title: "【綜藝玩很大】第450集 嘉義 經典大對決",
      date: "2026-11-08",
      parts: [
        { label: "Part 1", url: "https://example.com/p1" },
        { label: "Part 2", url: "https://example.com/p2" }
      ]
    };
    expect(win.getDownloadFilename(ep1, 0)).toBe("綜藝玩很大_2026-11-08_Part 1.mp4");
    expect(win.getDownloadFilename(ep1, 1)).toBe("綜藝玩很大_2026-11-08_Part 2.mp4");
  });

  it("generates correct share URLs and creates valid QR Code SVGs", () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    const js = fs.readFileSync(jsPath, "utf-8");
    const qrJs = fs.readFileSync(path.resolve(__dirname, "../web-app/qrcode.js"), "utf-8");
    const dom = new JSDOM(html, { runScripts: "dangerously", url: "http://localhost/" });
    const win = dom.window as any;
    win.eval(qrJs);
    win.eval(js);
    win.initPlayer();

    expect(typeof win.getShareUrl).toBe("function");
    expect(typeof win.QRCode.generateSVG).toBe("function");

    const ep = {
      id: "https://srgoideas.com/ep-20261108/",
      title: "【綜藝玩很大】嘉義 經典大對決",
      date: "2026-11-08",
      parts: [{ label: "Part 1" }, { label: "Part 2" }]
    };

    const urlP1 = win.getShareUrl(ep, 0);
    expect(urlP1).toContain("?ep=" + encodeURIComponent(ep.id));
    expect(urlP1).not.toContain("&part=");

    const urlP2 = win.getShareUrl(ep, 1);
    expect(urlP2).toContain("?ep=" + encodeURIComponent(ep.id));
    expect(urlP2).toContain("&part=2");

    const svg = win.QRCode.generateSVG(urlP2);
    expect(svg).toContain("<svg");
    expect(svg).toContain("</svg>");
    expect(svg).toContain("<rect");
  });

  it("implements sleep timer and double-tap seek controls in web-app app.js", () => {
    const htmlPath = path.resolve(__dirname, "../web-app/index.html");
    const jsPath = path.resolve(__dirname, "../web-app/app.js");

    const html = fs.readFileSync(htmlPath, "utf-8");
    const js = fs.readFileSync(jsPath, "utf-8");

    const dom = new JSDOM(html, {
      runScripts: "dangerously",
      url: "https://dtvsteams.pages.dev/"
    });
    const win = dom.window as any;

    win.eval(js);
    win.initPlayer();

    // Verify DOM structure for Sleep Timer and Seek Overlays
    const sleepBtn = win.document.getElementById("sleep-timer-btn");
    const sleepBadge = win.document.getElementById("sleep-timer-badge");
    const sleepModal = win.document.getElementById("sleep-timer-modal");
    const seekLeft = win.document.getElementById("seek-overlay-left");
    const seekRight = win.document.getElementById("seek-overlay-right");

    expect(sleepBtn).not.toBeNull();
    expect(sleepBadge).not.toBeNull();
    expect(sleepModal).not.toBeNull();
    expect(seekLeft).not.toBeNull();
    expect(seekRight).not.toBeNull();

    // Verify setSleepTimer functionality
    expect(typeof win.setSleepTimer).toBe("function");
    win.setSleepTimer("30");
    expect(sleepBadge.style.display).toBe("inline-block");
    expect(sleepBadge.textContent).toBe("30m");

    win.setSleepTimer("end");
    expect(sleepBadge.textContent).toBe("分段");

    win.setSleepTimer("0");
    expect(sleepBadge.style.display).toBe("none");

    // Verify triggerDoubleTapSeek
    expect(typeof win.triggerDoubleTapSeek).toBe("function");
    win.triggerDoubleTapSeek(true);
    expect(seekRight.style.display).toBe("flex");
    const textRight = win.document.getElementById("seek-text-right");
    expect(textRight.textContent).toContain("+10秒");

    // Verify vertical swipe HUDs for brightness and volume
    const hudBri = win.document.getElementById("hud-brightness");
    const hudVol = win.document.getElementById("hud-volume");
    const textBri = win.document.getElementById("hud-brightness-text");
    const textVol = win.document.getElementById("hud-volume-text");
    const player = win.document.getElementById("main-player");

    expect(hudBri).not.toBeNull();
    expect(hudVol).not.toBeNull();
    expect(typeof win.updateBrightness).toBe("function");
    expect(typeof win.updateVolume).toBe("function");
    expect(typeof win.setupVerticalSwipe).toBe("function");

    // Adjust brightness
    win.updateBrightness(0.6, true);
    expect(hudBri.style.opacity).toBe("1");
    expect(textBri.textContent).toBe("60%");
    expect(player.style.filter).toContain("brightness(");

    // Adjust volume
    win.updateVolume(0.8, true);
    expect(hudVol.style.opacity).toBe("1");
    expect(textVol.textContent).toBe("80%");
    expect(player.volume).toBeCloseTo(0.8);

    // Verify 2X Fast-forward HUD & Scale Mode
    const hud2x = win.document.getElementById("hud-speed-2x");
    const scaleBtn = win.document.getElementById("scale-mode-btn");
    const scaleLabel = win.document.getElementById("scale-mode-label");

    expect(hud2x).not.toBeNull();
    expect(scaleBtn).not.toBeNull();
    expect(scaleLabel).not.toBeNull();
    expect(typeof win.setupPressAndHold2x).toBe("function");
    expect(typeof win.cycleScaleMode).toBe("function");

    // Cycle scale modes: contain -> cover -> fill -> contain
    expect(scaleLabel.textContent).toContain("適應");
    win.cycleScaleMode();
    expect(player.style.objectFit).toBe("cover");
    expect(scaleLabel.textContent).toContain("填滿");

    win.cycleScaleMode();
    expect(player.style.objectFit).toBe("fill");
    expect(scaleLabel.textContent).toContain("拉伸");

    win.cycleScaleMode();
    expect(player.style.objectFit).toBe("contain");
    expect(scaleLabel.textContent).toContain("適應");

    // Verify Favorites System (Feature 6)
    const favFilterBtn = win.document.getElementById("fav-filter-btn");
    const favBadge = win.document.getElementById("fav-badge");
    const favBtn = win.document.getElementById("fav-btn");

    expect(favFilterBtn).not.toBeNull();
    expect(favBadge).not.toBeNull();
    expect(favBtn).not.toBeNull();
    expect(typeof win.getFavorites).toBe("function");
    expect(typeof win.isFavorite).toBe("function");
    expect(typeof win.toggleFavorite).toBe("function");

    const sampleEp = {
      id: "ep-fav-test",
      title: "【綜藝玩很大】宜蘭 溫泉大作戰",
      date: "2026-11-23",
      parts: [{ label: "Part 1" }]
    };

    expect(win.isFavorite(sampleEp.id)).toBe(false);
    win.toggleFavorite(sampleEp);
    expect(win.isFavorite(sampleEp.id)).toBe(true);
    expect(favBadge.textContent).toBe("1");
    expect(favBadge.style.display).toBe("inline-block");

    // Toggle off
    win.toggleFavorite(sampleEp);
    expect(win.isFavorite(sampleEp.id)).toBe(false);
    expect(favBadge.style.display).toBe("none");

    // Verify Dedicated Watch History Screen / Modal (Feature 7)
    const historyBtn = win.document.getElementById("history-btn");
    const historyBadge = win.document.getElementById("history-badge");
    const historyModal = win.document.getElementById("history-modal");
    const historyContainer = win.document.getElementById("history-list-container");
    const historyClearAllBtn = win.document.getElementById("history-clear-all-btn");

    expect(historyBtn).not.toBeNull();
    expect(historyBadge).not.toBeNull();
    expect(historyModal).not.toBeNull();
    expect(historyContainer).not.toBeNull();
    expect(historyClearAllBtn).not.toBeNull();
    expect(typeof win.getHistoryRecords).toBe("function");
    expect(typeof win.openHistoryModal).toBe("function");
    expect(typeof win.closeHistoryModal).toBe("function");
    expect(typeof win.clearAllHistory).toBe("function");

    // Clear history to start clean
    win.clearAllHistory();
    expect(win.getHistoryRecords().length).toBe(0);
    expect(historyBadge.style.display).toBe("none");

    // Save a playback record
    win.saveResume("ep-history-test-1", 0, 120, 300);
    const records = win.getHistoryRecords();
    expect(records.length).toBe(1);
    expect(records[0].episodeId).toBe("ep-history-test-1");
    expect(records[0].currentTime).toBe(120);
    expect(records[0].duration).toBe(300);
    expect(historyBadge.textContent).toBe("1");
    expect(historyBadge.style.display).toBe("flex");

    // Open history modal and verify rendering
    win.openHistoryModal();
    expect(historyModal.style.display).toBe("flex");
    expect(historyModal.getAttribute("aria-hidden")).toBe("false");
    expect(historyContainer.innerHTML).toContain("ep-history-test-1");
    expect(historyContainer.innerHTML).toContain("40%");

    // Close history modal
    win.closeHistoryModal();
    expect(historyModal.style.display).toBe("none");
    expect(historyModal.getAttribute("aria-hidden")).toBe("true");

    // Clear all history
    win.clearAllHistory();
    expect(win.getHistoryRecords().length).toBe(0);
    expect(historyBadge.style.display).toBe("none");

    // Verify Screen Lock OSD (Feature 8)
    const lockBtn = win.document.getElementById("screen-lock-btn");
    const lockLabel = win.document.getElementById("screen-lock-label");
    const unlockOverlay = win.document.getElementById("screen-unlock-overlay");
    const unlockBtn = win.document.getElementById("screen-unlock-btn");
    const playerContainer = win.document.getElementById("player-container");

    expect(lockBtn).not.toBeNull();
    expect(lockLabel).not.toBeNull();
    expect(unlockOverlay).not.toBeNull();
    expect(unlockBtn).not.toBeNull();
    expect(typeof win.lockScreen).toBe("function");
    expect(typeof win.unlockScreen).toBe("function");
    expect(typeof win.toggleScreenLock).toBe("function");

    // Lock screen
    win.lockScreen();
    expect(playerContainer.classList.contains("player-screen-locked")).toBe(true);
    expect(lockLabel.textContent).toBe("已鎖定");
    expect(unlockOverlay.style.display).toBe("flex");

    // Unlock screen
    win.unlockScreen();
    expect(playerContainer.classList.contains("player-screen-locked")).toBe(false);
    expect(lockLabel.textContent).toBe("鎖定");
    expect(unlockOverlay.style.display).toBe("none");

    // Toggle screen lock
    win.toggleScreenLock();
    expect(playerContainer.classList.contains("player-screen-locked")).toBe(true);
    win.toggleScreenLock();
    expect(playerContainer.classList.contains("player-screen-locked")).toBe(false);

    // Verify Auto-Play Next Part/Episode Countdown HUD & Toggle (Feature 9)
    const autoPlayBtn = win.document.getElementById("autoplay-toggle-btn");
    const autoPlayLabel = win.document.getElementById("autoplay-toggle-label");
    const autoPlayCard = win.document.getElementById("autoplay-next-card");
    const apPlayBtn = win.document.getElementById("ap-play-btn");
    const apCancelBtn = win.document.getElementById("ap-cancel-btn");
    const apNextTitle = win.document.getElementById("ap-next-title");
    const apCountdownNum = win.document.getElementById("ap-countdown-num");

    expect(autoPlayBtn).not.toBeNull();
    expect(autoPlayLabel).not.toBeNull();
    expect(autoPlayCard).not.toBeNull();
    expect(apPlayBtn).not.toBeNull();
    expect(apCancelBtn).not.toBeNull();
    expect(apNextTitle).not.toBeNull();
    expect(apCountdownNum).not.toBeNull();

    expect(typeof win.startAutoPlayCountdown).toBe("function");
    expect(typeof win.cancelAutoPlay).toBe("function");
    expect(typeof win.proceedAutoPlayNext).toBe("function");
    expect(typeof win.toggleAutoPlay).toBe("function");

    // Toggle auto-play
    expect(autoPlayLabel.textContent).toBe("連播: 開");
    win.toggleAutoPlay();
    expect(autoPlayLabel.textContent).toBe("連播: 關");
    win.toggleAutoPlay();
    expect(autoPlayLabel.textContent).toBe("連播: 開");

    // Start auto-play countdown with multi-part episode
    const multiPartEp = {
      id: "ep-auto-test",
      title: "【綜藝玩很大】宜蘭 溫泉大作戰",
      date: "2026-11-23",
      parts: [{ label: "Part 1" }, { label: "Part 2" }]
    };
    win.playPart(multiPartEp, 0, false, true);
    win.startAutoPlayCountdown();
    expect(autoPlayCard.style.display).toBe("flex");
    expect(apNextTitle.textContent).toContain("Part 2");
    expect(apCountdownNum.textContent).toBe("5");

    // Cancel auto-play
    win.cancelAutoPlay(true);
    expect(autoPlayCard.style.display).toBe("none");

    // Verify Year Filter Chips, Chronological Sort & Search History (Feature 10)
    const yearChipsBar = win.document.getElementById("year-chips-bar");
    const sortOrderBtn = win.document.getElementById("sort-order-btn");
    const sortIcon = win.document.getElementById("sort-icon");
    const sortLabel = win.document.getElementById("sort-label");
    const searchDropdown = win.document.getElementById("search-dropdown");
    const searchHistorySection = win.document.getElementById("search-history-section");
    const searchHistoryChips = win.document.getElementById("search-history-chips");
    const hotTagsChips = win.document.getElementById("hot-tags-chips");

    expect(yearChipsBar).not.toBeNull();
    expect(sortOrderBtn).not.toBeNull();
    expect(sortIcon).not.toBeNull();
    expect(sortLabel).not.toBeNull();
    expect(searchDropdown).not.toBeNull();
    expect(searchHistorySection).not.toBeNull();
    expect(searchHistoryChips).not.toBeNull();
    expect(hotTagsChips).not.toBeNull();

    // Verify exported functions
    expect(typeof win.matchesYear).toBe("function");
    expect(typeof win.setYearFilter).toBe("function");
    expect(typeof win.toggleSortOrder).toBe("function");
    expect(typeof win.addSearchHistory).toBe("function");
    expect(typeof win.removeSearchHistory).toBe("function");
    expect(typeof win.clearSearchHistory).toBe("function");
    expect(typeof win.getSearchHistory).toBe("function");

    // Test matchesYear
    const ep2026 = { title: "2026-11-20 台北", date: "2026-11-20" };
    const ep2025 = { title: "2025-05-10 高雄", date: "2025-05-10" };
    const epClassic = { title: "2019-08-01 經典回顧", date: "2019-08-01" };

    expect(win.matchesYear(ep2026, "all")).toBe(true);
    expect(win.matchesYear(ep2026, "2026")).toBe(true);
    expect(win.matchesYear(ep2026, "2025")).toBe(false);
    expect(win.matchesYear(epClassic, "classic")).toBe(true);
    expect(win.matchesYear(ep2026, "classic")).toBe(false);

    // Test Year Filtering on Grid
    win.setYearFilter("2025");
    const chip2025 = win.document.querySelector('.yt-year-chip[data-year="2025"]');
    expect(chip2025.classList.contains("active")).toBe(true);

    win.setYearFilter("all");
    const chipAll = win.document.querySelector('.yt-year-chip[data-year="all"]');
    expect(chipAll.classList.contains("active")).toBe(true);

    // Test Chronological Sort Toggle
    expect(sortLabel.textContent).toBe("新到舊");
    win.toggleSortOrder();
    expect(sortLabel.textContent).toBe("舊到新");
    expect(sortIcon.textContent).toBe("⬆");
    win.toggleSortOrder();
    expect(sortLabel.textContent).toBe("新到舊");
    expect(sortIcon.textContent).toBe("⬇");

    // Test Search History and Hot Tags
    win.clearSearchHistory();
    expect(win.getSearchHistory().length).toBe(0);

    win.addSearchHistory("澎湖");
    win.addSearchHistory("KID");
    win.addSearchHistory("憲哥");
    let hist = win.getSearchHistory();
    expect(hist.length).toBe(3);
    expect(hist[0]).toBe("憲哥");

    // Test deduplication
    win.addSearchHistory("澎湖");
    hist = win.getSearchHistory();
    expect(hist[0]).toBe("澎湖");
    expect(hist.length).toBe(3);

    // Test remove and clear
    win.removeSearchHistory("KID");
    expect(win.getSearchHistory()).not.toContain("KID");

    win.clearSearchHistory();
    expect(win.getSearchHistory().length).toBe(0);

    // Verify Audio-Only Radio Mode (Feature 11)
    const radioBtn = win.document.getElementById("radio-mode-btn");
    const radioLabel = win.document.getElementById("radio-mode-label");
    const radioOverlay = win.document.getElementById("radio-mode-overlay");
    const vinylDisc = win.document.getElementById("radio-vinyl-disc");
    const waveformBars = win.document.getElementById("radio-waveform-bars");
    const radioReturnBtn = win.document.getElementById("radio-return-btn");
    const radioBack15 = win.document.getElementById("radio-back-15");
    const radioFwd15 = win.document.getElementById("radio-fwd-15");
    const radioPlayBtn = win.document.getElementById("radio-play-btn");

    expect(radioBtn).not.toBeNull();
    expect(radioLabel).not.toBeNull();
    expect(radioOverlay).not.toBeNull();
    expect(vinylDisc).not.toBeNull();
    expect(waveformBars).not.toBeNull();
    expect(radioReturnBtn).not.toBeNull();
    expect(radioBack15).not.toBeNull();
    expect(radioFwd15).not.toBeNull();
    expect(radioPlayBtn).not.toBeNull();

    expect(typeof win.toggleAudioOnlyMode).toBe("function");
    expect(typeof win.setupRadioMode).toBe("function");
    expect(typeof win.updateRadioView).toBe("function");

    // Initially in video mode
    expect(radioOverlay.style.display).toBe("none");
    expect(radioLabel.textContent).toBe("聽劇模式");

    // Toggle Audio-Only Radio Mode ON
    win.toggleAudioOnlyMode();
    expect(radioOverlay.style.display).toBe("flex");
    expect(radioLabel.textContent).toBe("聽劇中");

    // Toggle Audio-Only Radio Mode OFF
    win.toggleAudioOnlyMode();
    expect(radioOverlay.style.display).toBe("none");
    expect(radioLabel.textContent).toBe("聽劇模式");
  });
});
