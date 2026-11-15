import { describe, it, expect, beforeEach } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { JSDOM } from "jsdom";

describe("tv-web Controller & YouTube TV Remote Navigation Engine", () => {
  const htmlPath = path.resolve(__dirname, "../tv-web/index.html");
  const catalogPath = path.resolve(__dirname, "../tv-web/catalog.json");
  const catalogData = JSON.parse(fs.readFileSync(catalogPath, "utf-8"));

  let dom: JSDOM;
  let doc: Document;
  let win: any;

  beforeEach(async () => {
    const html = fs.readFileSync(htmlPath, "utf-8");
    dom = new JSDOM(html, {
      runScripts: "dangerously",
      url: "http://localhost/"
    });
    win = dom.window;
    doc = win.document;

    // Polyfill scrollIntoView for JSDOM
    win.Element.prototype.scrollIntoView = () => {};

    // Mock HTMLMediaElement play/pause
    win.HTMLMediaElement.prototype.play = async () => {};
    win.HTMLMediaElement.prototype.pause = () => {};

    // Mock fetch for catalog.json in JSDOM
    win.fetch = async (url: string) => {
      if (url.includes("catalog.json")) {
        return {
          ok: true,
          json: async () => catalogData
        };
      }
      return { ok: false, status: 404 };
    };

    // Initialize UI and loadCatalog
    if (win.setupPlayerUi) {
      win.setupPlayerUi();
    }
    if (win.loadCatalog) {
      await win.loadCatalog();
    }
  });

  it("renders simple episode list and sets initial focus on first card", () => {
    const card0 = doc.getElementById("tv-card-0");
    expect(card0).not.toBeNull();
    expect(card0?.classList.contains("focused")).toBe(true);

    const titleEl = doc.getElementById("tv-title");
    expect(titleEl?.textContent).toBe(catalogData.episodes[0].title);
  });

  it("navigates horizontally through episode cards using ArrowRight and ArrowLeft", () => {
    // Press ArrowRight to move to card 1
    const rightEvent = new win.KeyboardEvent("keydown", { key: "ArrowRight" });
    win.dispatchEvent(rightEvent);

    const card1 = doc.getElementById("tv-card-1");
    expect(card1).not.toBeNull();
    expect(card1?.classList.contains("focused")).toBe(true);
    expect(win.getFocusState().focusCardIndex).toBe(1);

    // Press ArrowLeft to move back to card 0
    const leftEvent = new win.KeyboardEvent("keydown", { key: "ArrowLeft" });
    win.dispatchEvent(leftEvent);
    expect(doc.getElementById("tv-card-0")?.classList.contains("focused")).toBe(true);
    expect(win.getFocusState().focusCardIndex).toBe(0);
  });

  it("navigates from card up to parts bar on ArrowUp and back on ArrowDown", () => {
    // From card 0, press ArrowUp
    win.dispatchEvent(new win.KeyboardEvent("keydown", { key: "ArrowUp" }));
    expect(win.getFocusState().focusZone).toBe("parts");

    const partBtn = doc.getElementById("tv-part-btn-0");
    expect(partBtn).not.toBeNull();
    expect(partBtn?.classList.contains("focused")).toBe(true);

    // Press ArrowDown to return to cards
    win.dispatchEvent(new win.KeyboardEvent("keydown", { key: "ArrowDown" }));
    expect(win.getFocusState().focusZone).toBe("cards");
    expect(doc.getElementById("tv-card-0")?.classList.contains("focused")).toBe(true);
  });

  it("switches part directly via remote keys 1, 2, 3 and restarts with 0", () => {
    // Press '2'
    win.dispatchEvent(new win.KeyboardEvent("keydown", { key: "2" }));
    const partBadge = doc.getElementById("tv-part-badge");
    expect(partBadge?.textContent).toBe("Part 2");

    // Press '3'
    win.dispatchEvent(new win.KeyboardEvent("keydown", { key: "3" }));
    expect(partBadge?.textContent).toBe("Part 3");

    // Press '1'
    win.dispatchEvent(new win.KeyboardEvent("keydown", { key: "1" }));
    expect(partBadge?.textContent).toBe("Part 1");

    // Press '0' (Restart from beginning)
    win.dispatchEvent(new win.KeyboardEvent("keydown", { key: "0" }));
    expect(partBadge?.textContent).toBe("Part 1");
  });

  it("contains Video.js player element with YouTube TV theme and remote hints", () => {
    const video = doc.getElementById("tv-player");
    expect(video).not.toBeNull();
    expect(video?.classList.contains("video-js")).toBe(true);
    expect(video?.classList.contains("vjs-theme-yt")).toBe(true);

    const hints = doc.querySelector("footer.tv-remote-hints");
    expect(hints).not.toBeNull();
    expect(hints?.textContent).toContain("OK / Enter");
    expect(hints?.textContent).toContain("1 2 3");
    expect(hints?.textContent).toContain("0");
  });

  it("implements localStorage resume persistence in tv-web", () => {
    expect(typeof win.saveResume).toBe("function");
    expect(typeof win.getEpisodeResume).toBe("function");
    expect(typeof win.clearEpisodeResume).toBe("function");

    const testId = "https://srgoideas.com/tv-test-resume/";
    win.saveResume(testId, 2, 600, 2100);

    const saved = win.getEpisodeResume(testId);
    expect(saved).not.toBeNull();
    expect(saved.episodeId).toBe(testId);
    expect(saved.partIndex).toBe(2);
    expect(saved.currentTime).toBe(600);
    expect(saved.percentage).toBe(29);

    win.clearEpisodeResume(testId);
    expect(win.getEpisodeResume(testId)).toBeNull();
  });

  it("enters fullscreen when clicking into the video or episode card", () => {
    expect(typeof win.enterTvFullscreen).toBe("function");
    expect(typeof win.exitTvFullscreen).toBe("function");

    const wrapper = doc.querySelector(".tv-player-wrapper");
    expect(wrapper).not.toBeNull();

    // Call enterTvFullscreen
    win.enterTvFullscreen();
    expect(wrapper?.classList.contains("tv-fullscreen-mode")).toBe(true);

    // Call exitTvFullscreen
    win.exitTvFullscreen();
    expect(wrapper?.classList.contains("tv-fullscreen-mode")).toBe(false);

    // Click on card 0 triggers fullscreen
    const card0 = doc.getElementById("tv-card-0");
    card0?.click();
    expect(wrapper?.classList.contains("tv-fullscreen-mode")).toBe(true);

    // Clicking exit button exits fullscreen
    const exitBtn = doc.getElementById("tv-exit-fs-btn");
    expect(exitBtn).not.toBeNull();
    exitBtn?.click();
    expect(wrapper?.classList.contains("tv-fullscreen-mode")).toBe(false);

    // Clicking player wrapper enters fullscreen
    wrapper?.dispatchEvent(new win.MouseEvent("click", { bubbles: true }));
    expect(wrapper?.classList.contains("tv-fullscreen-mode")).toBe(true);

    // Escape key exits fullscreen
    win.dispatchEvent(new win.KeyboardEvent("keydown", { key: "Escape" }));
    expect(wrapper?.classList.contains("tv-fullscreen-mode")).toBe(false);

    // Enter fullscreen again and test Back key
    win.enterTvFullscreen();
    expect(wrapper?.classList.contains("tv-fullscreen-mode")).toBe(true);
    win.dispatchEvent(new win.KeyboardEvent("keydown", { key: "Back" }));
    expect(wrapper?.classList.contains("tv-fullscreen-mode")).toBe(false);
  });
});
