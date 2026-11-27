// @vitest-environment jsdom
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import React from "react";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import {
  buildPartDownloadHref,
  getDownloadFilename,
  isIosDevice,
  triggerBrowserDownload,
} from "../src/react/download.js";
import { VideoJs10Player } from "../src/react/VideoJs10Player.js";
import { App } from "../src/react/demo.js";

const SAMPLE_CATALOG = {
  episodes: [
    {
      id: "https://srgoideas.com/ep-2026-11-08/",
      title: "綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家",
      date: "2026-11-08",
      url: "https://srgoideas.com/ep-2026-11-08/",
      showId: "mr_player",
      showName: "綜藝玩很大",
      parts: [
        {
          label: "Part 1",
          url: "https://srgoideas.com/ep-2026-11-08/",
          streamUrl: "./media/sample-part1.mp4",
          duration: "35分",
        },
        {
          label: "Part 2",
          url: "https://srgoideas.com/ep-2026-11-08/2/",
          streamUrl: "./media/sample-part2.mp4",
          duration: "35分",
        },
        {
          label: "Part 3",
          url: "https://srgoideas.com/ep-2026-11-08/3/",
          streamUrl: "./media/sample-part3.mp4",
          duration: "38分",
        },
      ],
    },
  ],
};

describe("Web Download Helpers & Multi-Part Prompt", () => {
  beforeEach(() => {
    localStorage.clear();
    document.body.innerHTML = "";
    window.scrollTo = vi.fn();
    if (typeof globalThis.ResizeObserver === "undefined") {
      globalThis.ResizeObserver = class ResizeObserver {
        observe() {}
        unobserve() {}
        disconnect() {}
      } as unknown as typeof ResizeObserver;
    }
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("builds sanitized per-part MP4 filenames", () => {
    const ep = SAMPLE_CATALOG.episodes[0];
    expect(getDownloadFilename(ep, 0)).toBe("綜藝玩很大_2026-11-08_Part 1.mp4");
    expect(getDownloadFilename(ep, 1)).toBe("綜藝玩很大_2026-11-08_Part 2.mp4");
    expect(getDownloadFilename(ep, 2)).toBe("綜藝玩很大_2026-11-08_Part 3.mp4");

    expect(
      getDownloadFilename(
        {
          showName: "飢餓/遊戲",
          title: '特別:企劃"1"',
          date: "",
          parts: [{ label: "Part 1" }],
        },
        0,
      ),
    ).toBe("飢餓遊戲_特別企劃1_Part 1.mp4");
  });

  it("builds proxy download URLs on HTTP and falls back cleanly for sample streams", () => {
    const filename = "綜藝玩很大_2026-11-08_Part 1.mp4";
    const proxyHref = buildPartDownloadHref(
      SAMPLE_CATALOG.episodes[0].parts[0],
      filename,
      "https://cdn.example.com/part1.mp4?st=abc",
      true,
    );
    expect(proxyHref).toContain("/api/stream?");
    const parsedProxy = new URL(proxyHref!, "http://localhost");
    expect(parsedProxy.searchParams.get("download")).toBe("true");
    expect(parsedProxy.searchParams.get("filename")).toBe(filename);
    expect(parsedProxy.searchParams.get("url")).toBe("https://cdn.example.com/part1.mp4?st=abc");
    expect(parsedProxy.searchParams.get("pageUrl")).toBe("https://srgoideas.com/ep-2026-11-08/");

    const sampleOnlyHref = buildPartDownloadHref(
      { label: "Part 1", streamUrl: "./media/sample-part1.mp4" },
      filename,
      undefined,
      true,
    );
    expect(sampleOnlyHref).toBe("./media/sample-part1.mp4");
  });

  it("triggers proxy downloads via dedicated hidden iframes without target=_blank popups", () => {
    const clicks: Array<{ href: string; download: string; target: string }> = [];
    vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function (this: HTMLAnchorElement) {
      clicks.push({
        href: this.getAttribute("href") || "",
        download: this.getAttribute("download") || "",
        target: this.getAttribute("target") || "",
      });
    });

    triggerBrowserDownload("/api/stream?pageUrl=https%3A%2F%2Fexample.com&download=true&filename=p1.mp4", "p1.mp4", 0);
    triggerBrowserDownload("/api/stream?pageUrl=https%3A%2F%2Fexample.com%2F2&download=true&filename=p2.mp4", "p2.mp4", 1);
    triggerBrowserDownload("./media/sample-part3.mp4", "p3.mp4", 2);

    expect(clicks).toHaveLength(3);
    expect(clicks[0].target).toMatch(/^dtv-dl-frame-/);
    expect(clicks[1].target).toMatch(/^dtv-dl-frame-/);
    expect(clicks[0].target).not.toBe(clicks[1].target);
    expect(clicks[0].target).not.toBe("_blank");
    expect(clicks[2].target).toBe("");
    expect(clicks[2].download).toBe("p3.mp4");
  });

  it("prompts that 3 video parts will be downloaded when the download button is clicked and triggers all 3 on confirm", async () => {
    const clicks: Array<{ href: string; download: string; target: string }> = [];
    vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function (this: HTMLAnchorElement) {
      clicks.push({
        href: this.getAttribute("href") || "",
        download: this.getAttribute("download") || "",
        target: this.getAttribute("target") || "",
      });
    });

    vi.stubGlobal(
      "fetch",
      vi.fn(async (input: RequestInfo | URL) => {
        const url = String(input);
        if (url.includes("catalog.json")) {
          return new Response(JSON.stringify(SAMPLE_CATALOG), {
            status: 200,
            headers: { "Content-Type": "application/json" },
          });
        }
        if (url.includes("/api/resolve-stream")) {
          const parsed = new URL(url, "http://localhost");
          const page = parsed.searchParams.get("url") || "";
          const suffix = page.endsWith("/2/") ? "002" : page.endsWith("/3/") ? "003" : "001";
          return new Response(
            JSON.stringify({ ok: true, streamUrl: `https://cdn.example.com/vplay-${suffix}.mp4` }),
            { status: 200, headers: { "Content-Type": "application/json" } },
          );
        }
        return new Response("Not found", { status: 404 });
      }),
    );

    render(<App />);

    const downloadBtn = await screen.findByRole("button", { name: "下載此集影片" });
    fireEvent.click(downloadBtn);

    // Must prompt before starting any downloads
    expect(clicks).toHaveLength(0);
    expect(screen.getByText("下載整集影片（共 3 個分段）")).toBeTruthy();
    expect(screen.getByText(/將會下載 3 個影片分段（Part 1、Part 2、Part 3）/)).toBeTruthy();

    // Wait for stream pre-resolution to settle
    await waitFor(() => {
      const confirmBtn = screen.getByRole("button", { name: /確認下載全部 \(3 個分段\)/ });
      expect(confirmBtn.textContent).toBe("確認下載全部 (3 個分段)");
    });

    fireEvent.click(screen.getByRole("button", { name: "確認下載全部 (3 個分段)" }));

    expect(clicks).toHaveLength(3);
    expect(clicks.map((c) => c.download)).toEqual([
      "綜藝玩很大_2026-11-08_Part 1.mp4",
      "綜藝玩很大_2026-11-08_Part 2.mp4",
      "綜藝玩很大_2026-11-08_Part 3.mp4",
    ]);
    expect(clicks[0].href).toContain("download=true");
    expect(clicks[0].href).toContain(encodeURIComponent("https://cdn.example.com/vplay-001.mp4"));
    expect(clicks[1].href).toContain(encodeURIComponent("https://cdn.example.com/vplay-002.mp4"));
    expect(clicks[2].href).toContain(encodeURIComponent("https://cdn.example.com/vplay-003.mp4"));
    expect(clicks.every((c) => c.target !== "_blank")).toBe(true);

    vi.unstubAllGlobals();
  });

  it("omits crossOrigin, sets webkit-playsinline, and forces same-origin proxy=true on iOS WebKit", async () => {
    const origUA = navigator.userAgent;
    Object.defineProperty(navigator, "userAgent", {
      value: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
      configurable: true,
    });

    try {
      expect(isIosDevice()).toBe(true);

      const { container } = render(
        <VideoJs10Player
          src="/api/stream?pageUrl=https%3A%2F%2Fsrgoideas.com%2Fep%2F&proxy=true"
          episodeId="ios-ep"
          partIndex={0}
        />,
      );

      const videoEl = container.querySelector("video");
      expect(videoEl).not.toBeNull();
      expect(videoEl?.hasAttribute("crossorigin")).toBe(false);
      expect(videoEl?.getAttribute("webkit-playsinline")).toBe("true");
      expect(videoEl?.getAttribute("preload")).toBe("metadata");

      vi.stubGlobal(
        "fetch",
        vi.fn(async () =>
          new Response(JSON.stringify(SAMPLE_CATALOG), {
            status: 200,
            headers: { "Content-Type": "application/json" },
          }),
        ),
      );

      const appRender = render(<App />);
      await waitFor(() => {
        const appVideo = appRender.container.querySelector("video");
        expect(appVideo?.getAttribute("src") || "").toContain("proxy=true");
      });
    } finally {
      Object.defineProperty(navigator, "userAgent", {
        value: origUA,
        configurable: true,
      });
      vi.unstubAllGlobals();
    }
  });
});
