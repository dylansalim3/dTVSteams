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
});
