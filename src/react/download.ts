import { EpisodeItem, EpisodePart, detectShowChannel } from "./channels.js";

function sanitizeFilenameSegment(value: string): string {
  return (value || "").replace(/[/\\:*?"<>|]/g, "").trim();
}

/** Builds a clean, collision-free MP4 filename for a specific episode part. */
export function getDownloadFilename(episode: Partial<EpisodeItem>, partIndex = 0): string {
  if (!episode) return "dtvstream_video.mp4";
  const detected = detectShowChannel(episode);
  const showName = sanitizeFilenameSegment(episode.showName || detected.name || "綜藝玩很大");
  const date = sanitizeFilenameSegment(episode.date || "");
  const rawTitle = sanitizeFilenameSegment(episode.title || "");
  const part = episode.parts?.[partIndex];
  const partLabel = sanitizeFilenameSegment(part?.label || `Part ${partIndex + 1}`);

  if (date) {
    return `${showName}_${date}_${partLabel}.mp4`;
  }
  return `${showName}_${rawTitle || "episode"}_${partLabel}.mp4`;
}

/**
 * Resolves the downloadable URL for a part.
 * Uses `/api/stream?...&download=true` on HTTP(S) origins so the edge/dev proxy
 * attaches `Content-Disposition: attachment` and streams directly to disk.
 * Falls back to static/sample media URLs when no remote pageUrl exists.
 */
export function buildPartDownloadHref(
  part: EpisodePart | undefined,
  filename: string,
  resolvedStreamUrl?: string,
  isHttp = typeof window !== "undefined" && window.location.protocol.startsWith("http"),
): string | null {
  if (!part) return null;

  const pageUrl = (part.url || "").trim();
  const rawStream = (resolvedStreamUrl || part.streamUrl || "").trim();
  const isSampleStream = rawStream.includes("sample-part");
  const externalStream = !isSampleStream && rawStream.startsWith("http") ? rawStream : "";

  if (isHttp && (pageUrl || externalStream)) {
    const params = new URLSearchParams();
    if (externalStream) params.set("url", externalStream);
    if (pageUrl) params.set("pageUrl", pageUrl);
    params.set("download", "true");
    params.set("filename", filename);
    return `/api/stream?${params.toString()}`;
  }

  if (rawStream) return rawStream;
  if (pageUrl) return pageUrl;
  return null;
}

/** Detects iOS / iPadOS WebKit browsers (Safari, Chrome iOS, in-app WebViews). */
export function isIosDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  const ua = navigator.userAgent || "";
  if (/iPad|iPhone|iPod/i.test(ua)) return true;
  // iPadOS 13+ reports Macintosh in UA while having touch points
  return navigator.platform === "MacIntel" && (navigator.maxTouchPoints || 0) > 1;
}

/**
 * Triggers a browser download without popup blockers (`target="_blank"`).
 * For `/api/stream` responses (same-origin `Content-Disposition: attachment`),
 * uses a dedicated hidden iframe per part on desktop/Android so concurrent
 * multi-part downloads do not cancel each other or navigate the main page.
 */
export function triggerBrowserDownload(
  href: string,
  filename: string,
  partIndex = 0,
): void {
  if (typeof document === "undefined" || !href) return;

  const isProxyDownload = href.startsWith("/api/stream");
  const useIframeTarget = isProxyDownload && !isIosDevice();

  const a = document.createElement("a");
  a.href = href;
  a.download = filename;
  a.style.display = "none";

  if (useIframeTarget) {
    const frameName = `dtv-dl-frame-${Date.now()}-${partIndex}`;
    const iframe = document.createElement("iframe");
    iframe.name = frameName;
    iframe.setAttribute("aria-hidden", "true");
    iframe.tabIndex = -1;
    iframe.style.position = "fixed";
    iframe.style.width = "0";
    iframe.style.height = "0";
    iframe.style.border = "0";
    iframe.style.opacity = "0";
    iframe.style.pointerEvents = "none";
    document.body.appendChild(iframe);
    a.target = frameName;

    window.setTimeout(() => {
      if (iframe.parentNode) {
        iframe.parentNode.removeChild(iframe);
      }
    }, 60_000);
  }

  document.body.appendChild(a);
  a.click();
  window.setTimeout(() => {
    if (a.parentNode) {
      a.parentNode.removeChild(a);
    }
  }, 100);
}
