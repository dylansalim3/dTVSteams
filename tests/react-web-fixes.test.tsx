// @vitest-environment jsdom
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import React from "react";
import { render, screen, fireEvent, waitFor, cleanup } from "@testing-library/react";
import { App } from "../src/react/demo.js";
import {
  ALL_DARK_THEMES,
  ALL_LIGHT_THEMES,
  THEME_PAIRS,
  contrastRatio,
  resolveAccentForeground,
  readWebSettings,
} from "../src/react/themes.js";
import {
  VideoJs10Player,
  getStoredResume,
  saveStoredResume,
} from "../src/react/VideoJs10Player.js";

const STALE_EPISODE = {
  id: "https://srgoideas.com/mr-player-2026-11-01/",
  title: "綜藝玩很大 2026-11-01 舊集數",
  date: "2026-11-01",
  url: "https://srgoideas.com/mr-player-2026-11-01/",
  showId: "mr_player",
  showName: "綜藝玩很大",
  parts: [
    { label: "Part 1", url: "https://srgoideas.com/mr-player-2026-11-01/" },
    { label: "Part 2", url: "https://srgoideas.com/mr-player-2026-11-01/2/" },
  ],
};

const LIVE_EPISODES = [
  {
    id: "https://srgoideas.com/mr-player-2026-11-22/",
    title: "綜藝玩很大 2026-11-22 台北 最新特輯",
    date: "2026-11-22",
    url: "https://srgoideas.com/mr-player-2026-11-22/",
    showId: "mr_player",
    showName: "綜藝玩很大",
    parts: [
      { label: "Part 1", url: "https://srgoideas.com/mr-player-2026-11-22/" },
      { label: "Part 2", url: "https://srgoideas.com/mr-player-2026-11-22/2/" },
    ],
  },
  STALE_EPISODE,
];

describe("Normal Web (src/react) Fixes & Settings Parity", () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.className = "dark";
    document.documentElement.removeAttribute("style");
    window.history.replaceState({}, "", "/");
    window.scrollTo = vi.fn();
    globalThis.ResizeObserver = class {
      observe() {}
      unobserve() {}
      disconnect() {}
    } as unknown as typeof ResizeObserver;
  });

  afterEach(() => {
    cleanup();
    vi.restoreAllMocks();
  });

  it("provides 21 theme pairs with WCAG AA >= 4.5:1 contrast in both light and dark counterparts", () => {
    expect(THEME_PAIRS.length).toBe(21);
    expect(ALL_DARK_THEMES.length).toBe(21);
    expect(ALL_LIGHT_THEMES.length).toBe(21);

    for (const palette of [...ALL_DARK_THEMES, ...ALL_LIGHT_THEMES]) {
      expect(contrastRatio(palette.onAccent, palette.accent)).toBeGreaterThanOrEqual(4.5);
      for (const surface of [palette.canvas, palette.surfaceSecondary, palette.surfaceRaised]) {
        expect(contrastRatio(palette.textPrimary, surface)).toBeGreaterThanOrEqual(4.5);
        expect(contrastRatio(palette.textSecondary, surface)).toBeGreaterThanOrEqual(4.5);
        expect(contrastRatio(resolveAccentForeground(palette), surface)).toBeGreaterThanOrEqual(4.5);
      }
    }
  });

  it("hydrates Page 1 live from /api/episodes after instant catalog.json render", async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes("catalog.json")) {
        return new Response(JSON.stringify({ episodes: [STALE_EPISODE] }), { status: 200 });
      }
      if (url.includes("/api/episodes?page=1")) {
        return new Response(JSON.stringify({ ok: true, episodes: LIVE_EPISODES }), { status: 200 });
      }
      return new Response("{}", { status: 404 });
    });
    vi.stubGlobal("fetch", fetchMock);

    render(<App />);

    await waitFor(() => {
      expect(screen.getByText(/2026-11-22 台北 最新特輯/)).toBeTruthy();
    });
    expect(fetchMock.mock.calls.some(([u]) => String(u).includes("/api/episodes?page=1"))).toBe(true);
  });

  it("toggles Light/Dark mode from header button and removes unnecessary Settings/Year/Sort/Collapse buttons", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({ episodes: LIVE_EPISODES }), { status: 200 })),
    );

    render(<App />);
    await waitFor(() => {
      expect(screen.getAllByText(/2026-11-22 台北 最新特輯/).length).toBeGreaterThanOrEqual(1);
    });

    // Unnecessary buttons/controls are removed
    expect(screen.queryByRole("button", { name: "開啟應用程式設定" })).toBeNull();
    expect(screen.queryByRole("button", { name: "收合播放器" })).toBeNull();
    expect(screen.queryByRole("button", { name: "切換集數排序" })).toBeNull();
    expect(screen.queryByRole("button", { name: "播放節目" })).toBeNull();
    expect(screen.queryByText("經典懷舊")).toBeNull();
    expect(screen.queryByText("下載最新 Android APK")).toBeNull();

    // Compact 1-tap Light/Dark toggle in the header works
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    fireEvent.click(screen.getByRole("button", { name: "切換為淺色模式" }));
    expect(document.documentElement.classList.contains("dark")).toBe(false);
    expect(readWebSettings().brightness).toBe("light");

    fireEvent.click(screen.getByRole("button", { name: "切換為深色模式" }));
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(readWebSettings().brightness).toBe("dark");
  });

  it("parses ?ep=&part= share deep-link on initial load", async () => {
    const sharedEpId = "https://srgoideas.com/mr-player-2026-11-01/";
    window.history.replaceState({}, "", `/?ep=${encodeURIComponent(sharedEpId)}&part=2`);

    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({ ok: true, episodes: LIVE_EPISODES }), { status: 200 })),
    );

    const { container } = render(<App />);

    await waitFor(() => {
      const video = container.querySelector("video");
      expect(video?.getAttribute("src")).toContain(encodeURIComponent(`${sharedEpId}2/`));
    });
  });

  it("saves history metadata, supports click-to-resume, single delete, clear all, and smart card resume", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({ ok: true, episodes: LIVE_EPISODES }), { status: 200 })),
    );

    // Seed an in-progress record on Part 2 for STALE_EPISODE
    saveStoredResume({
      episodeId: STALE_EPISODE.id,
      partIndex: 1,
      currentTime: 240,
      duration: 1800,
      percentage: 13,
      completed: false,
      updatedAt: Date.now(),
      title: STALE_EPISODE.title,
      showName: STALE_EPISODE.showName,
      partLabel: "Part 2",
    });

    const { container } = render(<App />);
    await waitFor(() => {
      expect(screen.getByText(/2026-11-01 舊集數/)).toBeTruthy();
    });

    // Clicking the episode card smart-resumes Part 2 instead of resetting to Part 1
    fireEvent.click(screen.getByText(/2026-11-01 舊集數/));
    await waitFor(() => {
      const video = container.querySelector("video");
      expect(video?.getAttribute("src")).toContain(encodeURIComponent(`${STALE_EPISODE.id}2/`));
    });

    // Open Library modal -> History tab -> verify title & delete / clear all
    fireEvent.click(screen.getByRole("button", { name: "我的收藏與觀看紀錄" }));
    fireEvent.click(screen.getByRole("radio", { name: /觀看紀錄/ }));
    expect(screen.getAllByText(STALE_EPISODE.title).length).toBeGreaterThanOrEqual(1);

    fireEvent.click(screen.getByRole("button", { name: "清空紀錄" }));
    expect(getStoredResume(STALE_EPISODE.id)).toBeNull();
  });

  it("stores title, showName, and partLabel in VideoJs10Player resume updates", () => {
    const { container } = render(
      <VideoJs10Player
        src="./media/sample-part1.mp4"
        episodeId="https://srgoideas.com/meta-test/"
        episodeTitle="綜藝玩很大 測試標題"
        showName="綜藝玩很大"
        partLabel="Part 2"
        partIndex={1}
      />,
    );

    const videoEl = container.querySelector("video")!;
    Object.defineProperty(videoEl, "currentTime", { value: 90, writable: true });
    Object.defineProperty(videoEl, "duration", { value: 900, writable: true });
    fireEvent.timeUpdate(videoEl);

    const saved = getStoredResume("https://srgoideas.com/meta-test/");
    expect(saved?.title).toBe("綜藝玩很大 測試標題");
    expect(saved?.showName).toBe("綜藝玩很大");
    expect(saved?.partLabel).toBe("Part 2");
  });

  it("auto-advances across parts and episodes only when autoPlayNext is enabled", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({ ok: true, episodes: LIVE_EPISODES }), { status: 200 })),
    );

    const { container } = render(<App />);
    await waitFor(() => {
      expect(screen.getAllByText(/2026-11-22 台北 最新特輯/).length).toBeGreaterThanOrEqual(1);
    });

    const videoEl = container.querySelector("video")!;
    Object.defineProperty(videoEl, "duration", { value: 600, writable: true });

    // Part 1 ends -> advances to Part 2 of Episode 1
    fireEvent.ended(videoEl);
    await waitFor(() => {
      expect(videoEl.getAttribute("src")).toContain(
        encodeURIComponent("https://srgoideas.com/mr-player-2026-11-22/2/"),
      );
    });

    // Part 2 ends -> advances to Episode 2 Part 1
    fireEvent.ended(videoEl);
    await waitFor(() => {
      expect(videoEl.getAttribute("src")).toContain(
        encodeURIComponent("https://srgoideas.com/mr-player-2026-11-01/"),
      );
    });
  });
});
