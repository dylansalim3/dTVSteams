import { describe, it, expect } from "vitest";
import fs from "node:fs";
import { parseList, parseParts, parseStreamUrl } from "../src/parser.js";

function loadFixture(name: string): string {
  return fs.readFileSync(new URL(`./fixtures/${name}`, import.meta.url), "utf-8");
}

describe("parseList", () => {
  it("returns 10 items with id/title/date/url from fixture", () => {
    const eps = parseList(loadFixture("list.html"));
    expect(eps).toHaveLength(10);
    expect(eps[0].title).toContain("2026-10-04");
    expect(eps[0].url).toContain("https://");
    expect(eps[0].id).toBeTruthy();
    expect(eps[0].date).toContain("2026-10-04");
  });

  it("returns empty array when list missing", () => {
    expect(parseList("<html></html>")).toEqual([]);
  });
});

describe("parseParts", () => {
  it("returns 3 part page urls from fixture", () => {
    const parts = parseParts(loadFixture("episode.html"), "https://srgoideas.com/ep1/");
    expect(parts).toHaveLength(3);
    expect(parts[0].label).toBe("Part 1");
  });

  it("returns empty array when parts missing", () => {
    expect(parseParts("<html></html>", "https://x/")).toEqual([]);
  });
});

describe("parseStreamUrl", () => {
  it("extracts direct mp4 video stream url from fixture", () => {
    const stream = parseStreamUrl(loadFixture("episode.html"));
    expect(stream).toBe("https://example.xyz/vplay-001.mp4?st=abc&e=123");
  });

  it("returns null when no source exists", () => {
    expect(parseStreamUrl("<html><body><div>No video</div></body></html>")).toBeNull();
  });
});
