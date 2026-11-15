const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

async function resolveFreshStreamUrl(pageUrl) {
  if (!pageUrl) return null;
  try {
    const res = await fetch(pageUrl, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) return null;
    const html = await res.text();
    const match = html.match(/<source\s+src=['"]([^'"]+)['"]/i);
    if (match && match[1]) {
      return match[1];
    }
  } catch (err) {
    console.warn("Failed to resolve stream from", pageUrl, err.message);
  }
  return null;
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
        "Access-Control-Expose-Headers": "Content-Range, Content-Length, Accept-Ranges",
        "Access-Control-Max-Age": "86400"
      }
    });
  }

  const url = new URL(request.url);
  let targetUrl = url.searchParams.get("url");
  const pageUrl = url.searchParams.get("pageUrl");
  const forceRefresh = url.searchParams.get("refresh") === "true";

  if (forceRefresh && pageUrl) {
    const fresh = await resolveFreshStreamUrl(pageUrl);
    if (fresh) targetUrl = fresh;
  } else if (pageUrl && (!targetUrl || targetUrl.includes("sample-part") || targetUrl.startsWith("./") || targetUrl.startsWith("/media/"))) {
    targetUrl = await resolveFreshStreamUrl(pageUrl);
  }

  if (!targetUrl && pageUrl) {
    targetUrl = await resolveFreshStreamUrl(pageUrl);
  }

  if (!targetUrl) {
    return new Response("Missing stream url or pageUrl", {
      status: 400,
      headers: { "Access-Control-Allow-Origin": "*" }
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
      const freshUrl = await resolveFreshStreamUrl(pageUrl);
      if (freshUrl && freshUrl !== targetUrl) {
        targetUrl = freshUrl;
        upstream = await fetch(targetUrl, {
          method: method === "HEAD" ? "HEAD" : "GET",
          headers: upstreamHeaders
        });
      }
    }

    const outHeaders = new Headers();
    outHeaders.set("Content-Type", upstream.headers.get("content-type") || "video/mp4");
    outHeaders.set("Accept-Ranges", "bytes");
    outHeaders.set("Access-Control-Allow-Origin", "*");
    outHeaders.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
    outHeaders.set("Access-Control-Allow-Headers", "Range, Content-Type, Accept");
    outHeaders.set("Access-Control-Expose-Headers", "Content-Range, Content-Length, Accept-Ranges");

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
