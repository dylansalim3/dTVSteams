const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

const streamCache = new Map();

async function resolveFreshStreamUrl(pageUrl, bypassCache = false) {
  if (!pageUrl) return null;
  const cached = streamCache.get(pageUrl);
  if (!bypassCache && cached && Date.now() - cached.timestamp < 30 * 60 * 1000) {
    return cached.streamUrl;
  }
  try {
    const res = await fetch(pageUrl, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) return null;
    const html = await res.text();
    const match = html.match(/<source[^>]+src=['"]([^'"]+)['"]/i) || html.match(/<video[^>]+src=['"]([^'"]+)['"]/i);
    if (match && match[1]) {
      const freshUrl = match[1];
      streamCache.set(pageUrl, { streamUrl: freshUrl, timestamp: Date.now() });
      return freshUrl;
    }
  } catch (err) {
    console.warn("Failed to resolve stream from", pageUrl, err.message);
  }
  return null;
}

function buildContentDisposition(rawFilename) {
  const cleanName = (rawFilename || "video.mp4").replace(/[\r\n"/\\:*?<>|]/g, "_").trim() || "video.mp4";
  const asciiName = cleanName
    .replace(/[^\x20-\x7E]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");
  const safeAscii = asciiName && !/^\.mp4$/i.test(asciiName) ? asciiName : "video.mp4";
  return `attachment; filename="${safeAscii}"; filename*=UTF-8''${encodeURIComponent(cleanName)}`;
}

export async function onRequest(context) {
  const { request } = context;
  const method = request.method.toUpperCase();

  if (method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
        "Access-Control-Allow-Headers": "Range, Content-Type, Accept",
        "Access-Control-Expose-Headers": "Content-Range, Content-Length, Accept-Ranges, Location",
        "Access-Control-Max-Age": "86400"
      }
    });
  }

  const url = new URL(request.url);
  let targetUrl = url.searchParams.get("url");
  const pageUrl = url.searchParams.get("pageUrl");
  const forceRefresh = url.searchParams.get("refresh") === "true";
  const download = url.searchParams.get("download") === "true";
  const filename = url.searchParams.get("filename") || "video.mp4";
  const proxyMode = url.searchParams.get("proxy") === "true" || download;

  // Always prioritize authentic live token resolved from pageUrl (cached for 30m)
  // to prevent stale 404 tokens from breaking seeking and playback
  if (pageUrl) {
    const fresh = await resolveFreshStreamUrl(pageUrl, forceRefresh);
    if (fresh) targetUrl = fresh;
  }

  if (!targetUrl) {
    return new Response("Missing stream url or pageUrl", {
      status: 400,
      headers: { "Access-Control-Allow-Origin": "*" }
    });
  }

  // Fast direct 307 Temporary Redirect to high-speed CDN unless explicit proxy mode is requested.
  // This bypasses serverless bandwidth caps and provides instant buffering directly from the CDN.
  if (!proxyMode) {
    return new Response(null, {
      status: 307,
      headers: {
        "Location": targetUrl,
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
        "Access-Control-Expose-Headers": "Location, Range",
        "Cache-Control": "public, max-age=1800"
      }
    });
  }

  const upstreamHeaders = {
    "User-Agent": USER_AGENT,
    "Referer": "https://srgoideas.com/"
  };
  const clientRange = request.headers.get("range");
  if (clientRange) {
    upstreamHeaders["Range"] = clientRange;
  }

  try {
    let upstream = await fetch(targetUrl, {
      method: method === "HEAD" ? "HEAD" : "GET",
      headers: upstreamHeaders
    });

    if ((upstream.status === 403 || upstream.status === 404 || upstream.status === 410) && pageUrl) {
      const freshUrl = await resolveFreshStreamUrl(pageUrl, true);
      if (freshUrl && freshUrl !== targetUrl) {
        targetUrl = freshUrl;
        upstream = await fetch(targetUrl, {
          method: method === "HEAD" ? "HEAD" : "GET",
          headers: upstreamHeaders
        });
      }
    }

    const outHeaders = new Headers();
    outHeaders.set("Content-Type", upstream.ok ? (upstream.headers.get("content-type") || "video/mp4") : (upstream.headers.get("content-type") || "text/plain"));
    outHeaders.set("Accept-Ranges", "bytes");
    outHeaders.set("Cache-Control", "no-store");
    outHeaders.set("Access-Control-Allow-Origin", "*");
    outHeaders.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
    outHeaders.set("Access-Control-Allow-Headers", "Range, Content-Type, Accept");
    outHeaders.set("Access-Control-Expose-Headers", "Content-Range, Content-Length, Accept-Ranges, Content-Disposition");

    if (download && upstream.ok) {
      outHeaders.set("Content-Disposition", buildContentDisposition(filename));
    }

    if (upstream.headers.has("content-range")) {
      outHeaders.set("Content-Range", upstream.headers.get("content-range"));
    }
    if (upstream.headers.has("content-length")) {
      outHeaders.set("Content-Length", upstream.headers.get("content-length"));
    }

    return new Response(upstream.body, {
      status: upstream.status,
      headers: outHeaders
    });
  } catch (err) {
    return new Response(err.message, {
      status: 502,
      headers: { "Access-Control-Allow-Origin": "*" }
    });
  }
}
