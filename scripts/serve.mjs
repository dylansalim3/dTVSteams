// Zero-dep static server: node scripts/serve.mjs <dir> <port>
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Readable } from "node:stream";
import { generateEpisodeThumbnailSvg } from "./thumbnail-generator.mjs";

process.on("uncaughtException", (err) => {
  if (err?.code === "ECONNRESET" || err?.message?.includes("terminated") || err?.code === "EPIPE") {
    return;
  }
  console.error("Uncaught exception:", err);
});

process.on("unhandledRejection", (reason) => {
  if (reason?.code === "ECONNRESET" || reason?.message?.includes("terminated")) {
    return;
  }
  console.error("Unhandled rejection:", reason);
});

const root = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(root, "..");
const dir = path.resolve(repo, process.argv[2] || "web-app");
const port = Number(process.argv[3] || 8000);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".mp4": "video/mp4",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
  ".woff": "font/woff",
};

const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

const pageCache = new Map();
const resolvedStreamCache = new Map();

async function resolveFreshStreamUrl(pageUrl, bypassCache = false) {
  if (!pageUrl) return null;
  const cached = resolvedStreamCache.get(pageUrl);
  if (!bypassCache && cached && Date.now() - cached.timestamp < 10 * 60 * 1000) {
    return cached.streamUrl;
  }
  try {
    const res = await fetch(pageUrl, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) return null;
    const html = await res.text();
    const match = html.match(/<source\s+src=['"]([^'"]+)['"]/i);
    if (match && match[1]) {
      const freshUrl = match[1];
      resolvedStreamCache.set(pageUrl, { streamUrl: freshUrl, timestamp: Date.now() });
      return freshUrl;
    }
  } catch (err) {
    console.warn("Failed to resolve fresh stream from", pageUrl, err.message);
  }
  return null;
}

const SHOW_SLUGS = {
  mr_player: "綜藝玩很大",
  hunger_games: "飢餓遊戲",
  all_stars: "全明星運動會",
  super_ent: "小明星大跟班",
  hot_shop: "11點熱吵店",
};

async function fetchEpisodesPage(page = 1, rawShow = "mr_player") {
  const showId = SHOW_SLUGS[rawShow] ? rawShow : "mr_player";
  const showName = SHOW_SLUGS[showId];
  const cacheKey = `${showId}:${page}`;
  if (pageCache.has(cacheKey)) {
    return pageCache.get(cacheKey);
  }

  // Page 1 of default channel can return local catalog.json if available
  if (page === 1 && showId === "mr_player") {
    const localCatalog = path.join(dir, "catalog.json");
    if (fs.existsSync(localCatalog)) {
      try {
        const data = JSON.parse(fs.readFileSync(localCatalog, "utf-8"));
        if (data.episodes && data.episodes.length > 0) {
          pageCache.set(cacheKey, data.episodes);
          return data.episodes;
        }
      } catch {}
    }
  }

  const upstreamUrl = showId === "mr_player"
    ? `https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/?lcp_page0=${page}#lcp_instance_0`
    : (page <= 1
        ? `https://srgoideas.com/category/variety-show/${encodeURIComponent(showName)}/`
        : `https://srgoideas.com/category/variety-show/${encodeURIComponent(showName)}/page/${page}/`);

  const res = await fetch(upstreamUrl, {
    headers: { "User-Agent": USER_AGENT }
  });
  if (!res.ok) {
    throw new Error(`Upstream HTTP ${res.status}`);
  }
  const html = await res.text();

  const lcpMatch = html.match(/<ul\s+class=["'][^"']*lcp_catlist[^"']*["'][^>]*>([\s\S]*?)<\/ul>/i);
  const articleMatches = !lcpMatch
    ? html.match(/<(?:h2|h3)[^>]*class=["'][^"']*entry-title[^"']*["'][^>]*>[\s\S]*?<\/(?:h2|h3)>/gi)
    : null;
  const targetHtml = lcpMatch
    ? lcpMatch[1]
    : (articleMatches && articleMatches.length ? articleMatches.join("\n") : html);

  const linkRegex = /<a\s+[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  const episodes = [];
  const seen = new Set();
  let match;
  const filterKeyword = showId === "mr_player" ? "玩很大" : showName;

  while ((match = linkRegex.exec(targetHtml)) !== null) {
    const rawUrl = match[1];
    const rawTitle = match[2].replace(/<[^>]+>/g, "").trim();
    if (!rawUrl.startsWith("http") || !rawTitle || seen.has(rawUrl)) continue;
    if (filterKeyword && !rawTitle.includes(filterKeyword)) continue;
    seen.add(rawUrl);

    const dateMatch = rawTitle.match(/\d{4}-\d{2}-\d{2}/);
    const date = dateMatch ? dateMatch[0] : "";
    const cleanUrl = rawUrl.endsWith("/") ? rawUrl : rawUrl + "/";

    const thumbUrl = `/api/thumbnail?date=${encodeURIComponent(date)}&title=${encodeURIComponent(rawTitle)}&id=${encodeURIComponent(rawUrl)}`;

    episodes.push({
      id: rawUrl,
      title: rawTitle,
      date,
      url: rawUrl,
      showId,
      showName,
      duration: "1小時 48分",
      backdrop: thumbUrl,
      poster: thumbUrl,
      parts: [
        { label: "Part 1", streamUrl: "", fallbackStreamUrl: "", url: cleanUrl, duration: "35分" },
        { label: "Part 2", streamUrl: "", fallbackStreamUrl: "", url: `${cleanUrl}2/`, duration: "35分" },
        { label: "Part 3", streamUrl: "", fallbackStreamUrl: "", url: `${cleanUrl}3/`, duration: "38分" }
      ]
    });
  }

  pageCache.set(cacheKey, episodes);
  return episodes;
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = new URL(req.url, `http://localhost:${port}`);
  const urlPath = decodeURIComponent(parsedUrl.pathname);

  // Global CORS preflight support for media and canvas operations
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
      "Access-Control-Allow-Headers": "Range, Content-Type, Accept",
      "Access-Control-Expose-Headers": "Content-Range, Content-Length, Accept-Ranges",
      "Access-Control-Max-Age": "86400"
    });
    res.end();
    return;
  }

  // Dynamic SVG thumbnail generator endpoint: /api/thumbnail?date=...&title=...&id=...
  if (urlPath === "/api/thumbnail") {
    const title = parsedUrl.searchParams.get("title") || "綜藝玩很大";
    const date = parsedUrl.searchParams.get("date") || "";
    const id = parsedUrl.searchParams.get("id") || "";
    const svg = generateEpisodeThumbnailSvg({ title, date, id });
    res.writeHead(200, {
      "Content-Type": "image/svg+xml; charset=utf-8",
      "Cache-Control": "public, max-age=86400",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS"
    });
    res.end(svg);
    return;
  }

  // Dynamic pagination endpoint: /api/episodes?page=1..64&show=mr_player
  if (urlPath === "/api/episodes") {
    const page = Math.max(1, parseInt(parsedUrl.searchParams.get("page") || "1", 10));
    const show = parsedUrl.searchParams.get("show") || "mr_player";
    try {
      const episodes = await fetchEpisodesPage(page, show);
      res.writeHead(200, {
        "Content-Type": "application/json; charset=utf-8",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS"
      });
      res.end(JSON.stringify({ ok: true, page, totalPages: 64, episodes }));
    } catch (err) {
      res.writeHead(500, {
        "Content-Type": "application/json; charset=utf-8",
        "Access-Control-Allow-Origin": "*"
      });
      res.end(JSON.stringify({ ok: false, error: err.message, page }));
    }
    return;
  }

  if (urlPath === "/api/resolve-stream") {
    const targetUrl = parsedUrl.searchParams.get("url");
    if (!targetUrl) {
      res.writeHead(400, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      res.end(JSON.stringify({ ok: false, error: "Missing url parameter" }));
      return;
    }
    try {
      const freshUrl = await resolveFreshStreamUrl(targetUrl);
      if (freshUrl) {
        res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
        res.end(JSON.stringify({ ok: true, streamUrl: freshUrl }));
        return;
      }
      res.writeHead(404, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      res.end(JSON.stringify({ ok: false, error: "No video source found in page" }));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      res.end(JSON.stringify({ ok: false, error: err.message }));
    }
    return;
  }

  // Streaming proxy endpoint for cross-origin range requests with self-healing token refresh
  if (urlPath === "/api/stream") {
    let targetUrl = parsedUrl.searchParams.get("url");
    const pageUrl = parsedUrl.searchParams.get("pageUrl");
    const forceRefresh = parsedUrl.searchParams.get("refresh") === "true";

    // Always prioritize authentic live token resolved from pageUrl (cached for 30m)
    // to prevent stale 404 tokens from breaking seeking and playback
    if (pageUrl) {
      const fresh = await resolveFreshStreamUrl(pageUrl, forceRefresh);
      if (fresh) targetUrl = fresh;
    }

    if (!targetUrl) {
      res.writeHead(400, { "Access-Control-Allow-Origin": "*" });
      res.end("Missing stream url or pageUrl");
      return;
    }

    const download = parsedUrl.searchParams.get("download") === "true";
    const filename = parsedUrl.searchParams.get("filename") || "video.mp4";
    const proxyMode = parsedUrl.searchParams.get("proxy") === "true" || download;
    if (!proxyMode) {
      res.writeHead(307, {
        "Location": targetUrl,
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
        "Access-Control-Expose-Headers": "Location, Range",
        "Cache-Control": "public, max-age=1800"
      });
      res.end();
      return;
    }

    const headers = { "User-Agent": USER_AGENT, "Referer": "https://srgoideas.com/" };
    if (req.headers.range) {
      headers["range"] = req.headers.range;
    }

    try {
      let upstream = await fetch(targetUrl, { headers });

      // If token expired (403, 404, 410) and pageUrl is available, re-resolve live stream automatically bypassing cache
      if ((upstream.status === 403 || upstream.status === 404 || upstream.status === 410) && pageUrl) {
        const freshUrl = await resolveFreshStreamUrl(pageUrl, true);
        if (freshUrl && freshUrl !== targetUrl) {
          targetUrl = freshUrl;
          upstream = await fetch(targetUrl, { headers });
        }
      }

      const outHeaders = {
        "Content-Type": upstream.headers.get("content-type") || "video/mp4",
        "Accept-Ranges": "bytes",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
        "Access-Control-Allow-Headers": "Range, Content-Type, Accept",
        "Access-Control-Expose-Headers": "Content-Range, Content-Length, Accept-Ranges, Content-Disposition",
      };
      if (download) {
        outHeaders["Content-Disposition"] = `attachment; filename="${encodeURIComponent(filename)}"; filename*=UTF-8''${encodeURIComponent(filename)}`;
      }
      if (upstream.headers.has("content-range")) {
        outHeaders["Content-Range"] = upstream.headers.get("content-range");
      }
      if (upstream.headers.has("content-length")) {
        outHeaders["Content-Length"] = upstream.headers.get("content-length");
      }
      res.writeHead(upstream.status, outHeaders);
      if (!upstream.body) {
        res.end();
        return;
      }
      const stream = Readable.fromWeb(upstream.body);
      stream.on("error", () => {
        // Suppress socket resets or premature closes
      });
      req.on("close", () => {
        stream.destroy();
      });
      stream.pipe(res);
    } catch (err) {
      if (!res.headersSent) {
        res.writeHead(502, { "Access-Control-Allow-Origin": "*" });
      }
      res.end(err.message);
    }
    return;
  }

  let file = path.normalize(path.join(dir, urlPath === "/" ? "index.html" : urlPath));
  if (!file.startsWith(dir)) {
    res.writeHead(403);
    res.end("forbidden");
    return;
  }
  fs.stat(file, (err, st) => {
    if (!err && st.isDirectory()) file = path.join(file, "index.html");
    fs.readFile(file, (e, data) => {
      if (e) {
        res.writeHead(404);
        res.end("not found");
        return;
      }
      res.writeHead(200, { "Content-Type": MIME[path.extname(file)] || "application/octet-stream" });
      res.end(data);
    });
  });
});

server.listen(port, () => console.log(`serving ${dir} at http://localhost:${port}/`));
