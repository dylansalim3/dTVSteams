import { describe, it, expect } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { JSDOM } from "jsdom";

const scriptSource = fs.readFileSync(
  path.resolve(__dirname, "../tv-web/frame-thumbnails.js"),
  "utf-8"
);

function setupWindow() {
  const dom = new JSDOM("<!doctype html><html><body></body></html>", {
    url: "http://localhost/",
    runScripts: "outside-only"
  });
  const win = dom.window as any;
  win.eval(scriptSource);
  return win;
}

function tick() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("Part 1 midpoint frame thumbnails", () => {
  it("uses a cached frame immediately instead of extracting again", () => {
    const win = setupWindow();
    const thumbs = win.DTVFrameThumbs;
    win.localStorage.setItem(
      thumbs.CACHE_KEY,
      JSON.stringify({ "ep-cached": { dataUrl: "data:image/jpeg;base64,cached", ts: Date.now() } })
    );

    const img = win.document.createElement("img");
    img.src = "./preview.png";
    thumbs.attach("ep-cached", img, "/api/stream?part=1");

    expect(img.getAttribute("src")).toBe("data:image/jpeg;base64,cached");
    expect(img.dataset.frameThumb).toBe("ready");
  });

  it("extracts the Part 1 middle frame and caches it", async () => {
    const win = setupWindow();
    const thumbs = win.DTVFrameThumbs;
    const calls: string[] = [];
    thumbs.captureMiddleFrame = async (src: string) => {
      calls.push(src);
      return "data:image/jpeg;base64,fresh";
    };

    const img = win.document.createElement("img");
    img.src = "./preview.png";
    win.document.body.appendChild(img);
    thumbs.attach("ep-fresh", img, "/part-1-midpoint");
    await tick();
    await tick();

    expect(calls).toEqual(["/part-1-midpoint"]);
    expect(img.getAttribute("src")).toBe("data:image/jpeg;base64,fresh");
    expect(img.dataset.frameThumb).toBe("ready");

    const cache = JSON.parse(win.localStorage.getItem(thumbs.CACHE_KEY) || "{}");
    expect(cache["ep-fresh"]?.dataUrl).toBe("data:image/jpeg;base64,fresh");
  });

  it("queues one extraction per episode even when rendered repeatedly", async () => {
    const win = setupWindow();
    const thumbs = win.DTVFrameThumbs;
    let calls = 0;
    thumbs.captureMiddleFrame = async () => {
      calls += 1;
      return "data:image/jpeg;base64,once";
    };

    const first = win.document.createElement("img");
    const second = win.document.createElement("img");
    win.document.body.appendChild(first);
    win.document.body.appendChild(second);
    thumbs.attach("ep-once", first, "/part-1");
    thumbs.attach("ep-once", second, "/part-1");
    await tick();
    await tick();

    expect(calls).toBe(1);
    expect(first.dataset.frameThumb).toBe("ready");
    expect(second.dataset.frameThumb).toBe("ready");
    expect(second.getAttribute("src")).toBe("data:image/jpeg;base64,once");
  });

  it("keeps the poster fallback and stops retrying when extraction fails", async () => {
    const win = setupWindow();
    const thumbs = win.DTVFrameThumbs;
    let calls = 0;
    thumbs.captureMiddleFrame = async () => {
      calls += 1;
      throw new Error("cors blocked");
    };

    const img = win.document.createElement("img");
    img.src = "./preview.png";
    thumbs.attach("ep-broken", img, "/part-1");
    await tick();
    await tick();

    expect(img.getAttribute("src")).toBe("./preview.png");
    expect(img.dataset.frameThumb).toBeUndefined();
    expect(calls).toBe(1);

    // A later render must not hammer the failing stream again.
    thumbs.attach("ep-broken", img, "/part-1");
    await tick();
    expect(calls).toBe(1);
  });

  it("rejects capture early when no stream URL is provided", async () => {
    const win = setupWindow();
    await expect(win.DTVFrameThumbs.captureMiddleFrame("")).rejects.toThrow("missing stream url");
  });
});
