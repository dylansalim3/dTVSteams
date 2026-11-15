import { describe, it, expect } from "vitest";
import fs from "node:fs";
import path from "node:path";
// @ts-ignore
import { generateEpisodeThumbnailSvg } from "../scripts/thumbnail-generator.mjs";

describe("Episode Thumbnails System Integrity", () => {
  const webCatalogPath = path.resolve(__dirname, "../web-app/catalog.json");
  const tvCatalogPath = path.resolve(__dirname, "../tv-web/catalog.json");
  const webCatalog = JSON.parse(fs.readFileSync(webCatalogPath, "utf-8"));
  const tvCatalog = JSON.parse(fs.readFileSync(tvCatalogPath, "utf-8"));

  it("ensures web-app catalog has no broken tmdb or generic preview.png thumbnails", () => {
    expect(webCatalog.episodes.length).toBeGreaterThan(0);
    for (const ep of webCatalog.episodes) {
      expect(ep.poster).toBeDefined();
      expect(ep.poster).not.toContain("tmdb.org");
      expect(ep.poster).not.toContain("preview.png");
      expect(ep.backdrop).toBeDefined();
      expect(ep.backdrop).not.toContain("tmdb.org");
      expect(ep.backdrop).not.toContain("preview.png");

      // Check physical file exists on disk
      const filePath = path.resolve(__dirname, "../web-app", ep.poster.replace(/^\.\//, ""));
      expect(fs.existsSync(filePath), `Thumbnail file missing: ${filePath}`).toBe(true);
      const content = fs.readFileSync(filePath, "utf-8");
      expect(content).toContain("<svg");
      expect(content).toContain("綜藝玩很大");
    }
  });

  it("ensures tv-web catalog has no broken tmdb or generic preview.png thumbnails", () => {
    expect(tvCatalog.episodes.length).toBeGreaterThan(0);
    for (const ep of tvCatalog.episodes) {
      expect(ep.poster).toBeDefined();
      expect(ep.poster).not.toContain("tmdb.org");
      expect(ep.poster).not.toContain("preview.png");

      const filePath = path.resolve(__dirname, "../tv-web", ep.poster.replace(/^\.\//, ""));
      expect(fs.existsSync(filePath), `TV thumbnail file missing: ${filePath}`).toBe(true);
    }
  });

  it("generates crisp 16:9 SVG with title, date, and location badge", () => {
    const svg = generateEpisodeThumbnailSvg({
      title: "綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家",
      date: "2026-11-08",
      id: "ep-test"
    });

    expect(svg).toContain("<svg");
    expect(svg).toContain('viewBox="0 0 640 360"');
    expect(svg).toContain("綜藝玩很大");
    expect(svg).toContain("2026-11-08");
    expect(svg).toContain("台北 搗蛋鬼到你家");
    expect(svg).toContain("1080P HD");
  });

  it("provides reliable fallback thumbnail thumb-default.svg", () => {
    const defaultWeb = path.resolve(__dirname, "../web-app/media/thumb-default.svg");
    const defaultTv = path.resolve(__dirname, "../tv-web/media/thumb-default.svg");
    expect(fs.existsSync(defaultWeb)).toBe(true);
    expect(fs.existsSync(defaultTv)).toBe(true);
  });
});
