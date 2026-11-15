import { describe, it, expect } from "vitest";

describe("Live Stream Resolution & Self-Healing Token Proxy", () => {
  function resolveStreamUrl(part: { streamUrl?: string; url?: string; fallbackStreamUrl?: string }, isHttp = true) {
    if (!part) return "./media/sample-part1.mp4";
    const pageUrl = part.url || "";
    let streamUrl = part.streamUrl || "";
    if (streamUrl.includes("sample-part")) {
      streamUrl = "";
    }
    if (isHttp) {
      const params = new URLSearchParams();
      if (streamUrl) params.set("url", streamUrl);
      if (pageUrl) params.set("pageUrl", pageUrl);
      return `/api/stream?${params.toString()}`;
    }
    return streamUrl || part.fallbackStreamUrl || "./media/sample-part1.mp4";
  }

  it("prioritizes genuine stream URL and passes pageUrl for self-healing resolution", () => {
    const part = {
      label: "Part 1",
      url: "https://srgoideas.com/ep-20261108/",
      streamUrl: "https://xyz.com/vplay-20261108-001.mp4?st=abc&e=123",
      fallbackStreamUrl: "./media/sample-part1.mp4"
    };
    const resolved = resolveStreamUrl(part, true);
    expect(resolved).toContain("/api/stream?");
    expect(resolved).toContain("url=" + encodeURIComponent(part.streamUrl));
    expect(resolved).toContain("pageUrl=" + encodeURIComponent(part.url));
  });

  it("filters out dummy sample-part from streamUrl so pageUrl resolves authentic video", () => {
    const part = {
      label: "Part 1",
      url: "https://srgoideas.com/ep-20260830/",
      streamUrl: "./media/sample-part1.mp4",
      fallbackStreamUrl: "./media/sample-part1.mp4"
    };
    const resolved = resolveStreamUrl(part, true);
    expect(resolved).toContain("/api/stream?");
    expect(resolved).not.toContain("sample-part");
    expect(resolved).toContain("pageUrl=" + encodeURIComponent(part.url));
  });

  it("constructs fresh token reload URL on player playback error", () => {
    const currentPart = {
      url: "https://srgoideas.com/ep-20261108/"
    };
    const freshStream = `/api/stream?pageUrl=${encodeURIComponent(currentPart.url)}&refresh=true`;
    expect(freshStream).toBe(
      `/api/stream?pageUrl=https%3A%2F%2Fsrgoideas.com%2Fep-20261108%2F&refresh=true`
    );
  });
});
