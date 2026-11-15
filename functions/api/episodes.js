const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

export async function onRequestGet(context) {
  const url = new URL(context.request.url);
  const page = Math.max(1, parseInt(url.searchParams.get("page") || "1", 10));

  try {
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

    return new Response(JSON.stringify({ ok: true, page, totalPages: 64, episodes }), {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Cache-Control": "public, max-age=3600"
      }
    });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: err.message, page }), {
      status: 500,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Access-Control-Allow-Origin": "*"
      }
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
