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

async function fetchEpisodesPage(page = 1) {
  if (pageCache.has(page)) {
    return pageCache.get(page);
  }

  // Page 1 can return local catalog.json if available
  if (page === 1) {
    const localCatalog = path.join(dir, "catalog.json");
    if (fs.existsSync(localCatalog)) {
      try {
        const data = JSON.parse(fs.readFileSync(localCatalog, "utf-8"));
        if (data.episodes && data.episodes.length > 0) {
          pageCache.set(1, data.episodes);
          return data.episodes;
        }
      } catch {}
    }
  }

  const upstreamUrl = `https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/?lcp_page0=${page}#lcp_instance_0`;
  const res = await fetch(upstreamUrl, {
    headers: { "User-Agent": USER_AGENT }
  });
  if (!res.ok) {
    throw new Error(`Upstream HTTP ${res.status}`);
  }
  const html = await res.text();

  const lcpMatch = html.match(/<ul\s+class=["'][^"']*lcp_catlist[^"']*["'][^>]*>([\s\S]*?)<\/ul>/i);
  const targetHtml = lcpMatch ? lcpMatch[1] : html;

  const linkRegex = /<a\s+[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  const episodes = [];
  const seen = new Set();
  let match;

  while ((match = linkRegex.exec(targetHtml)) !== null) {
    const rawUrl = match[1];
    const rawTitle = match[2].replace(/<[^>]+>/g, "").trim();
    if (!rawTitle.includes("玩很大") || seen.has(rawUrl)) continue;
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

  pageCache.set(page, episodes);
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

  // Dynamic pagination endpoint: /api/episodes?page=1..64
  if (urlPath === "/api/episodes") {
    const page = Math.max(1, parseInt(parsedUrl.searchParams.get("page") || "1", 10));
    try {
      const episodes = await fetchEpisodesPage(page);
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

    // If targetUrl is a dummy sample, empty, or refresh requested, resolve genuine stream from pageUrl
    if (forceRefresh && pageUrl) {
      const fresh = await resolveFreshStreamUrl(pageUrl, true);
      if (fresh) targetUrl = fresh;
    } else if (pageUrl && (!targetUrl || targetUrl.includes("sample-part") || targetUrl.startsWith("./") || targetUrl.startsWith("/media/"))) {
      targetUrl = await resolveFreshStreamUrl(pageUrl, false);
    }

    if (!targetUrl && pageUrl) {
      targetUrl = await resolveFreshStreamUrl(pageUrl, true);
    }

    if (!targetUrl) {
      res.writeHead(400, { "Access-Control-Allow-Origin": "*" });
      res.end("Missing stream url or pageUrl");
      return;
    }

    const proxyMode = parsedUrl.searchParams.get("proxy") === "true";
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
        "Access-Control-Expose-Headers": "Content-Range, Content-Length, Accept-Ranges",
      };
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
