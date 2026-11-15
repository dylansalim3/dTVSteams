// @vitest-environment jsdom
import { describe, it, expect, beforeEach, vi } from "vitest";
import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import {
  VideoJs10Player,
  getStoredResume,
  saveStoredResume,
  clearStoredResume,
} from "../src/react/VideoJs10Player.js";

describe("Video.js v10 React Implementation (https://videojs.org/docs/guides/installation/react)", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("exports official Video.js 10 React components and storage helpers", () => {
    expect(typeof VideoJs10Player).toBe("function");
    expect(typeof getStoredResume).toBe("function");
    expect(typeof saveStoredResume).toBe("function");
    expect(typeof clearStoredResume).toBe("function");
  });

  it("renders VideoPlayer, VideoSkin, and Video elements matching videojs.org structure", () => {
    const { container } = render(
      <VideoJs10Player
        src="./media/sample-part1.mp4"
        poster="./preview.png"
        title="綜藝玩很大"
        episodeId="test-ep-1"
        partIndex={0}
      />
    );

    // Verify container and elements exist
    const playerWrapper = container.querySelector(".vjs10-player-container");
    expect(playerWrapper).not.toBeNull();

    // Verify Video component rendered with videojs.org fallback link
    const fallbackLinks = screen.getAllByText("Video player not working?");
    expect(fallbackLinks.length).toBeGreaterThanOrEqual(1);
    expect(fallbackLinks[0].getAttribute("href")).toBe("https://videojs.org/help");

    // Verify video element properties
    const videoEl = container.querySelector("video");
    expect(videoEl).not.toBeNull();
    expect(videoEl?.getAttribute("src")).toBe("./media/sample-part1.mp4");
    expect(videoEl?.getAttribute("poster")).toBe("./preview.png");
    expect(videoEl?.getAttribute("crossorigin")).toBe("anonymous");
  });

  it("saves and retrieves playback resume state in localStorage", () => {
    const episodeId = "https://srgoideas.com/ep-react-test/";
    const testRecord = {
      episodeId,
      partIndex: 1,
      currentTime: 420,
      duration: 1800,
      percentage: 23,
      completed: false,
      updatedAt: Date.now(),
    };

    saveStoredResume(testRecord);

    const retrieved = getStoredResume(episodeId);
    expect(retrieved).not.toBeNull();
    expect(retrieved?.episodeId).toBe(episodeId);
    expect(retrieved?.currentTime).toBe(420);
    expect(retrieved?.partIndex).toBe(1);
    expect(retrieved?.percentage).toBe(23);

    // Clear resume
    clearStoredResume(episodeId);
    expect(getStoredResume(episodeId)).toBeNull();
  });

  it("handles video timeupdate and triggers callbacks", () => {
    const onTimeUpdateMock = vi.fn();
    const onEndedMock = vi.fn();

    const { container } = render(
      <VideoJs10Player
        src="./media/sample-part1.mp4"
        episodeId="test-ep-callback"
        partIndex={0}
        onTimeUpdate={onTimeUpdateMock}
        onEnded={onEndedMock}
      />
    );

    const videoEl = container.querySelector("video");
    expect(videoEl).not.toBeNull();

    if (videoEl) {
      // Mock video currentTime and duration
      Object.defineProperty(videoEl, "currentTime", { value: 60, writable: true });
      Object.defineProperty(videoEl, "duration", { value: 600, writable: true });

      fireEvent.timeUpdate(videoEl);
      expect(onTimeUpdateMock).toHaveBeenCalledWith(60, 600);

      fireEvent.ended(videoEl);
      expect(onEndedMock).toHaveBeenCalled();
    }
  });
});
