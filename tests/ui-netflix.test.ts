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
  });
});
