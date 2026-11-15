const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

const resolveCache = new Map();

export async function onRequestGet(context) {
  const url = new URL(context.request.url);
  const targetUrl = url.searchParams.get("url");

  if (!targetUrl) {
    return new Response(JSON.stringify({ ok: false, error: "Missing url parameter" }), {
      status: 400,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  }

  const cached = resolveCache.get(targetUrl);
  if (cached && Date.now() - cached.timestamp < 30 * 60 * 1000) {
    return new Response(JSON.stringify({ ok: true, streamUrl: cached.streamUrl, fromCache: true }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "public, max-age=1800"
      }
    });
  }

  try {
    const res = await fetch(targetUrl, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) {
      return new Response(JSON.stringify({ ok: false, error: `Upstream HTTP ${res.status}` }), {
        status: 502,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }
    const html = await res.text();
    const match = html.match(/<source\s+src=['"]([^'"]+)['"]/i);
    if (match && match[1]) {
      resolveCache.set(targetUrl, { streamUrl: match[1], timestamp: Date.now() });
      return new Response(JSON.stringify({ ok: true, streamUrl: match[1] }), {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Cache-Control": "public, max-age=1800"
        }
      });
    }
    return new Response(JSON.stringify({ ok: false, error: "No video source found" }), {
      status: 404,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  }
}

export async function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Max-Age": "86400"
    }
  });
}
