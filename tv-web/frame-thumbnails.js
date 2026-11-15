// Part 1 midpoint frame thumbnails.
// Loads each episode's first part in a hidden <video>, seeks to 50% of its
// duration, captures that frame to a JPEG data URL, and caches it locally.
// Cards keep their poster image until (or unless) a real frame is available.
(function (global) {
  "use strict";

  const CACHE_KEY = "dtv_frame_thumbs";
  const MAX_CACHE_ENTRIES = 60;
  const FRAME_WIDTH = 480;
  const FRAME_HEIGHT = 270;
  const MAX_CONCURRENT = 2;
  const EXTRACT_TIMEOUT_MS = 20000;

  const queue = [];
  const inFlight = new Map();
  const failed = new Set();
  const targets = new Map();
  let activeTasks = 0;

  function registerTarget(episodeId, imgEl) {
    let imgs = targets.get(episodeId);
    if (!imgs) {
      imgs = new Set();
      targets.set(episodeId, imgs);
    }
    // Drop detached images from earlier renders.
    imgs.forEach((img) => {
      if (img.isConnected === false) imgs.delete(img);
    });
    imgs.add(imgEl);
  }

  function applyToTargets(episodeId, dataUrl) {
    const imgs = targets.get(episodeId);
    if (!imgs) return;
    imgs.forEach((img) => {
      if (img.isConnected === false) {
        imgs.delete(img);
        return;
      }
      img.src = dataUrl;
      img.dataset.frameThumb = "ready";
    });
  }

  function readCache() {
    try {
      const raw = global.localStorage?.getItem(CACHE_KEY);
      const parsed = raw ? JSON.parse(raw) : {};
      return parsed && typeof parsed === "object" ? parsed : {};
    } catch (err) {
      return {};
    }
  }

  function writeCache(cache) {
    if (!global.localStorage) return;
    try {
      const ids = Object.keys(cache).sort((a, b) => (cache[b].ts || 0) - (cache[a].ts || 0));
      while (ids.length > MAX_CACHE_ENTRIES) {
        delete cache[ids.pop()];
      }
      global.localStorage.setItem(CACHE_KEY, JSON.stringify(cache));
    } catch (err) {
      // Quota exceeded: drop half of the oldest entries and retry once.
      try {
        const ids = Object.keys(cache).sort((a, b) => (cache[b].ts || 0) - (cache[a].ts || 0));
        ids.slice(Math.floor(ids.length / 2)).forEach((id) => delete cache[id]);
        global.localStorage.setItem(CACHE_KEY, JSON.stringify(cache));
      } catch (retryErr) {
        console.warn("Unable to cache frame thumbnail:", retryErr);
      }
    }
  }

  function getCached(episodeId) {
    if (!episodeId) return null;
    const entry = readCache()[episodeId];
    return entry && typeof entry.dataUrl === "string" ? entry.dataUrl : null;
  }

  function putCached(episodeId, dataUrl) {
    if (!episodeId || !dataUrl) return;
    const cache = readCache();
    cache[episodeId] = { dataUrl, ts: Date.now() };
    writeCache(cache);
  }

  function pump() {
    while (activeTasks < MAX_CONCURRENT && queue.length) {
      const task = queue.shift();
      activeTasks += 1;
      Promise.resolve()
        .then(task)
        .catch(() => {})
        .finally(() => {
          activeTasks -= 1;
          pump();
        });
    }
  }

  function enqueue(task) {
    queue.push(task);
    pump();
  }

  // Capture the frame at exactly the middle of the video.
  function captureMiddleFrame(src) {
    return new Promise((resolve, reject) => {
      if (!src) {
        reject(new Error("missing stream url"));
        return;
      }
      if (typeof document === "undefined" || typeof document.createElement !== "function") {
        reject(new Error("no DOM available"));
        return;
      }

      const video = document.createElement("video");
      video.crossOrigin = "anonymous";
      video.preload = "metadata";
      video.muted = true;
      video.playsInline = true;
      video.setAttribute("playsinline", "");
      video.setAttribute("aria-hidden", "true");
      video.setAttribute("tabindex", "-1");
      video.style.position = "fixed";
      video.style.left = "-9999px";
      video.style.top = "0";
      video.style.width = "1px";
      video.style.height = "1px";
      video.style.opacity = "0";
      video.style.pointerEvents = "none";

      let settled = false;
      let timer = null;

      const cleanup = () => {
        if (timer) clearTimeout(timer);
        video.removeEventListener("loadedmetadata", onLoadedMetadata);
        video.removeEventListener("seeked", onSeeked);
        video.removeEventListener("error", onError);
        try {
          video.pause();
        } catch (err) {}
        try {
          video.removeAttribute("src");
          video.load();
        } catch (err) {}
        if (video.parentNode) video.parentNode.removeChild(video);
      };

      const fail = (err) => {
        if (settled) return;
        settled = true;
        cleanup();
        reject(err instanceof Error ? err : new Error(String(err)));
      };

      const succeed = (dataUrl) => {
        if (settled) return;
        settled = true;
        cleanup();
        resolve(dataUrl);
      };

      function drawFrame() {
        try {
          const width = video.videoWidth || FRAME_WIDTH;
          const height = video.videoHeight || FRAME_HEIGHT;
          if (!width || !height) {
            fail(new Error("video frame is empty"));
            return;
          }

          const canvas = document.createElement("canvas");
          canvas.width = FRAME_WIDTH;
          canvas.height = FRAME_HEIGHT;
          const ctx = canvas.getContext("2d");
          if (!ctx) {
            fail(new Error("canvas 2d context unavailable"));
            return;
          }

          // Cover-fit and center-crop so non 16:9 sources still fill the card.
          const scale = Math.max(FRAME_WIDTH / width, FRAME_HEIGHT / height);
          const drawWidth = width * scale;
          const drawHeight = height * scale;
          ctx.drawImage(
            video,
            (FRAME_WIDTH - drawWidth) / 2,
            (FRAME_HEIGHT - drawHeight) / 2,
            drawWidth,
            drawHeight
          );

          succeed(canvas.toDataURL("image/jpeg", 0.72));
        } catch (err) {
          // Usually a tainted canvas (missing CORS headers) - keep poster fallback.
          fail(err);
        }
      }

      function onLoadedMetadata() {
        const duration = video.duration;
        if (!isFinite(duration) || duration <= 0) {
          fail(new Error("invalid video duration"));
          return;
        }
        // Capture scene frame (3 to 6 seconds) where intro title card appears.
        // Avoids deep 17.5 minute HTTP range buffering on 300MB streams while delivering instant frame thumbnails.
        const targetTime = Math.min(6, Math.max(0.5, duration * 0.05));
        try {
          video.currentTime = targetTime;
        } catch (err) {
          fail(err);
        }
      }

      function onSeeked() {
        // Let the decoder paint the seeked frame before copying it.
        if (typeof global.requestAnimationFrame === "function") {
          global.requestAnimationFrame(() => global.requestAnimationFrame(drawFrame));
        } else {
          setTimeout(drawFrame, 60);
        }
      }

      function onError() {
        const mediaError = video.error;
        fail(new Error(`video load failed${mediaError ? ` (code ${mediaError.code})` : ""}`));
      }

      video.addEventListener("loadedmetadata", onLoadedMetadata);
      video.addEventListener("seeked", onSeeked);
      video.addEventListener("error", onError);

      timer = setTimeout(() => fail(new Error("frame extraction timed out")), EXTRACT_TIMEOUT_MS);

      document.body.appendChild(video);
      video.src = src;
      try {
        video.load();
      } catch (err) {
        fail(err);
      }
    });
  }

  // Apply a cached frame immediately, otherwise extract it and update the <img>.
  function attach(episodeId, imgEl, partOneStreamUrl) {
    if (!imgEl || !episodeId) return;
    registerTarget(episodeId, imgEl);
    if (imgEl.dataset.frameThumb === "ready") return;

    const cached = getCached(episodeId);
    if (cached) {
      imgEl.src = cached;
      imgEl.dataset.frameThumb = "ready";
      return;
    }

    if (failed.has(episodeId) || inFlight.has(episodeId)) return;
    if (!partOneStreamUrl) return;

    inFlight.set(episodeId, true);
    enqueue(async () => {
      try {
        const dataUrl = await api.captureMiddleFrame(partOneStreamUrl);
        putCached(episodeId, dataUrl);
        applyToTargets(episodeId, dataUrl);
      } catch (err) {
        failed.add(episodeId);
        console.warn(`Part 1 midpoint thumbnail unavailable for ${episodeId}:`, err?.message || err);
      } finally {
        inFlight.delete(episodeId);
      }
    });
  }

  const api = {
    attach,
    getCached,
    captureMiddleFrame,
    CACHE_KEY,
    FRAME_WIDTH,
    FRAME_HEIGHT
  };

  global.DTVFrameThumbs = api;
})(typeof window !== "undefined" ? window : globalThis);
