const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

const SHOW_SLUGS = {
  mr_player: "綜藝玩很大",
  hunger_games: "飢餓遊戲",
  all_stars: "全明星運動會",
  super_ent: "小明星大跟班",
  hot_shop: "11點熱吵店",
};

function parseUpstreamEpisodes(html, showId, showName) {
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

  return episodes;
}

export async function onRequestGet(context) {
  const url = new URL(context.request.url);
  const page = Math.max(1, parseInt(url.searchParams.get("page") || "1", 10));
  const rawShow = (url.searchParams.get("show") || "mr_player").trim();
  const showId = SHOW_SLUGS[rawShow] ? rawShow : "mr_player";
  const showName = SHOW_SLUGS[showId];

  try {
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
    const episodes = parseUpstreamEpisodes(html, showId, showName);

    return new Response(JSON.stringify({ ok: true, show: showId, page, totalPages: 64, episodes }), {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Cache-Control": "public, max-age=3600"
      }
    });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: err.message, show: showId, page }), {
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
