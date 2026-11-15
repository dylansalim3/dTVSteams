import { describe, it, expect, beforeEach } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { JSDOM } from "jsdom";

describe("Catalog Pagination & Load More Multi-Page Support", () => {
  const tvHtmlPath = path.resolve(__dirname, "../tv-web/index.html");
  const catalogPath = path.resolve(__dirname, "../tv-web/catalog.json");
  const catalogData = JSON.parse(fs.readFileSync(catalogPath, "utf-8"));

  let dom: JSDOM;
  let win: any;
  let doc: Document;

  beforeEach(async () => {
    const html = fs.readFileSync(tvHtmlPath, "utf-8");
    dom = new JSDOM(html, {
      runScripts: "dangerously",
      url: "http://localhost/"
    });
    win = dom.window;
    doc = win.document;

    win.Element.prototype.scrollIntoView = () => {};
    win.HTMLMediaElement.prototype.play = async () => {};
    win.HTMLMediaElement.prototype.pause = () => {};

    // Mock fetch for catalog.json and /api/episodes
    win.fetch = async (url: string) => {
      if (url.includes("catalog.json")) {
        return {
          ok: true,
          json: async () => catalogData
        };
      }
      if (url.includes("/api/episodes?page=2")) {
        return {
          ok: true,
          json: async () => ({
            ok: true,
            page: 2,
            totalPages: 64,
            episodes: [
              {
                id: "https://srgoideas.com/page2-ep1/",
                title: "綜藝玩很大 2026-08-30 關西 命運筆記本",
                date: "2026-08-30",
                url: "https://srgoideas.com/page2-ep1/",
                parts: [
                  { label: "Part 1", streamUrl: "./media/sample-part1.mp4" },
                  { label: "Part 2", streamUrl: "./media/sample-part2.mp4" },
                  { label: "Part 3", streamUrl: "./media/sample-part3.mp4" }
                ]
              }
            ]
          })
        };
      }
      return { ok: false, status: 404 };
    };

    if (win.setupPlayerUi) win.setupPlayerUi();
    if (win.loadCatalog) await win.loadCatalog();
  });

  it("renders TV Load More card at the end of the episode list", () => {
    const loadMoreCard = doc.getElementById("tv-card-10");
    expect(loadMoreCard).not.toBeNull();
    expect(loadMoreCard?.classList.contains("tv-card-load-more")).toBe(true);
    expect(loadMoreCard?.textContent).toContain("載入更多歷史集數");
  });

  it("loads next page of episodes and appends to episode list", async () => {
    expect(typeof win.loadMoreTvEpisodes).toBe("function");
    const initialCount = win.getEpisodes().length;
    expect(initialCount).toBe(10);

    await win.loadMoreTvEpisodes();

    const updatedEpisodes = win.getEpisodes();
    expect(updatedEpisodes.length).toBe(11);
    expect(updatedEpisodes[10].title).toContain("2026-08-30");

    // Check count badge updated
    const countBadge = doc.getElementById("tv-episode-count");
    expect(countBadge?.textContent).toContain("共 11 集 (第 2 頁)");
  });

  it("navigates to TV Load More card via D-pad ArrowRight and triggers load on Enter", async () => {
    const state = win.getFocusState();
    expect(state.focusCardIndex).toBe(0);

    // Navigate right to the end of cards
    for (let i = 0; i < 10; i++) {
      win.handleDpad("ArrowRight");
    }

    // Now focus should be on the 10th card (the load more card)
    expect(win.getFocusState().focusCardIndex).toBe(10);
    const loadMoreCard = doc.getElementById("tv-card-10");
    expect(loadMoreCard?.classList.contains("focused")).toBe(true);

    // Press Enter to load more
    win.handleDpad("Enter");

    // Wait microtask
    await new Promise(r => setTimeout(r, 20));
    expect(win.getEpisodes().length).toBe(11);
  });
});
