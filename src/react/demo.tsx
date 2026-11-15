import React, { useState, useEffect } from "react";
import { createRoot } from "react-dom/client";
import { VideoJs10Player } from "./VideoJs10Player.js";

interface EpisodeItem {
  id: string;
  title: string;
  date: string;
  url: string;
  duration?: string;
  poster?: string;
  parts: Array<{ label: string; streamUrl?: string; url?: string; duration?: string }>;
}

function resolveStreamUrl(part?: { streamUrl?: string; url?: string }) {
  if (!part) return "./media/sample-part1.mp4";
  const pageUrl = part.url || "";
  let streamUrl = part.streamUrl || "";
  if (streamUrl.includes("sample-part")) {
    streamUrl = "";
  }
  if (typeof window !== "undefined" && window.location.protocol.startsWith("http")) {
    const params = new URLSearchParams();
    if (streamUrl) params.set("url", streamUrl);
    if (pageUrl) params.set("pageUrl", pageUrl);
    return `/api/stream?${params.toString()}`;
  }
  return streamUrl || "./media/sample-part1.mp4";
}

function resolveEpisodeThumb(ep: EpisodeItem) {
  if (ep.poster && !ep.poster.includes("tmdb.org") && !ep.poster.includes("preview.png")) {
    return ep.poster.startsWith("./") ? `../${ep.poster.slice(2)}` : ep.poster;
  }
  const dateSlug = (ep.date || "").replace(/-/g, "");
  if (dateSlug) {
    return `../media/thumbnails/ep-${dateSlug}.svg`;
  }
  return `../media/thumb-default.svg`;
}

function App() {
  const [episodes, setEpisodes] = useState<EpisodeItem[]>([]);
  const [selectedEpIndex, setSelectedEpIndex] = useState(0);
  const [partIndex, setPartIndex] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  useEffect(() => {
    fetch("../catalog.json")
      .then(r => r.json())
      .then(data => {
        if (data.episodes && data.episodes.length > 0) {
          setEpisodes(data.episodes);
        }
      })
      .catch(() => {
        // Fallback
        setEpisodes([
          {
            id: "ep1",
            title: "綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家",
            date: "2026-11-08",
            url: "https://srgoideas.com/ep1/",
            duration: "1小時 48分",
            parts: [
              { label: "Part 1", streamUrl: "./media/sample-part1.mp4", duration: "35分" },
              { label: "Part 2", streamUrl: "./media/sample-part2.mp4", duration: "35分" },
              { label: "Part 3", streamUrl: "./media/sample-part3.mp4", duration: "38分" },
            ]
          }
        ]);
      });
  }, []);

  const activeEp = episodes[selectedEpIndex] || {
    id: "default",
    title: "綜藝玩很大",
    parts: [{ label: "Part 1", streamUrl: "./media/sample-part1.mp4" }]
  };
  const activePart = activeEp.parts?.[partIndex] || activeEp.parts?.[0] || { label: "Part 1", streamUrl: "./media/sample-part1.mp4" };

  const handleLoadMore = async () => {
    if (isLoadingMore || currentPage >= 64) return;
    setIsLoadingMore(true);
    const nextPage = currentPage + 1;
    try {
      const res = await fetch(`/api/episodes?page=${nextPage}`);
      if (!res.ok) throw new Error("HTTP " + res.status);
      const data = await res.json();
      if (data.ok && data.episodes) {
        const seen = new Set(episodes.map(e => e.id));
        const newItems = data.episodes.filter((e: any) => !seen.has(e.id));
        setEpisodes(prev => [...prev, ...newItems]);
        setCurrentPage(nextPage);
      }
    } catch (err) {
      console.error("React loadMore error:", err);
    } finally {
      setIsLoadingMore(false);
    }
  };

  return (
    <div style={{ maxWidth: 1100, margin: "0 auto", padding: "2rem 1.5rem", color: "#f3e7d2", fontFamily: "Roboto, system-ui, sans-serif" }}>
      <header style={{ marginBottom: "1.5rem", borderBottom: "1px solid rgba(255,255,255,0.1)", paddingBottom: "1rem", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <h1 style={{ fontSize: "1.75rem", margin: "0 0 0.5rem 0", color: "#fff" }}>
            Video.js v10 React Player — 綜藝玩很大
          </h1>
          <p style={{ margin: 0, fontSize: "0.95rem", color: "rgba(255,255,255,0.7)" }}>
            官方 Video.js 10 React 規範實作 • 支援多頁分段動態載入與 LocalStorage 斷點續播
          </p>
        </div>
        <a href="../index.html" style={{ color: "#3ea6ff", textDecoration: "none", fontSize: "0.9rem", border: "1px solid rgba(62,166,255,0.4)", padding: "6px 14px", borderRadius: "20px" }}>
          ← 回到一般網頁版
        </a>
      </header>

      <main>
        <VideoJs10Player
          src={resolveStreamUrl(activePart)}
          poster="../preview.png"
          title={`${activeEp.title} · ${activePart.label}`}
          episodeId={activeEp.id}
          partIndex={partIndex}
          autoPlay={false}
          onEnded={() => {
            if (activeEp.parts && partIndex < activeEp.parts.length - 1) {
              setPartIndex(partIndex + 1);
            }
          }}
        />

        {/* Part Selection Bar */}
        <div style={{ display: "flex", gap: "10px", marginTop: "1.25rem", alignItems: "center" }}>
          <span style={{ fontWeight: 600, fontSize: "0.95rem", color: "#aaa" }}>分段切換：</span>
          {(activeEp.parts || []).map((p, idx) => (
            <button
              key={idx}
              onClick={() => setPartIndex(idx)}
              style={{
                padding: "8px 18px",
                background: idx === partIndex ? "#ff0000" : "rgba(255,255,255,0.1)",
                color: "#fff",
                border: "1px solid " + (idx === partIndex ? "#ff0000" : "rgba(255,255,255,0.2)"),
                borderRadius: "6px",
                cursor: "pointer",
                fontWeight: 600,
                fontSize: "0.9rem",
                transition: "all 0.2s ease"
              }}
            >
              ▶ {p.label}
            </button>
          ))}
        </div>

        {/* Episode List Grid */}
        <section style={{ marginTop: "2.5rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
            <h2 style={{ fontSize: "1.3rem", color: "#fff" }}>集數列表</h2>
            <span style={{ fontSize: "0.9rem", color: "#aaa" }}>已載入 {episodes.length} 集 (共 640+ 集)</span>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))", gap: "16px" }}>
            {episodes.map((ep, idx) => (
              <div
                key={ep.id + idx}
                onClick={() => {
                  setSelectedEpIndex(idx);
                  setPartIndex(0);
                }}
                style={{
                  background: idx === selectedEpIndex ? "rgba(255,0,0,0.15)" : "#1f1f1f",
                  border: "1px solid " + (idx === selectedEpIndex ? "#ff0000" : "rgba(255,255,255,0.1)"),
                  borderRadius: "8px",
                  padding: "12px",
                  cursor: "pointer",
                  transition: "all 0.2s ease"
                }}
              >
                <div style={{ position: "relative", width: "100%", aspectRatio: "16 / 9", borderRadius: "6px", overflow: "hidden", marginBottom: "8px", background: "#0a0a0a" }}>
                  <img
                    src={resolveEpisodeThumb(ep)}
                    alt={ep.title}
                    loading="lazy"
                    onError={(e) => { (e.currentTarget as HTMLImageElement).src = "../media/thumb-default.svg"; }}
                    style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }}
                  />
                  <span style={{ position: "absolute", bottom: "6px", right: "6px", background: "rgba(0,0,0,0.8)", color: "#fff", fontSize: "0.75rem", padding: "2px 6px", borderRadius: "4px", fontWeight: 600 }}>
                    {ep.duration || "1小時 48分"}
                  </span>
                </div>
                <div style={{ fontWeight: 600, fontSize: "0.95rem", marginBottom: "6px", color: idx === selectedEpIndex ? "#fff" : "#eee" }}>
                  {ep.title}
                </div>
                <div style={{ fontSize: "0.8rem", color: "#888" }}>
                  {ep.date || "最新"} · 共 {ep.parts?.length || 3} 個分段
                </div>
              </div>
            ))}
          </div>

          {/* Load More Button */}
          {currentPage < 64 && (
            <div style={{ textAlign: "center", marginTop: "2rem" }}>
              <button
                onClick={handleLoadMore}
                disabled={isLoadingMore}
                style={{
                  padding: "10px 28px",
                  background: "rgba(255,255,255,0.1)",
                  border: "1px solid rgba(255,255,255,0.25)",
                  color: "#fff",
                  borderRadius: "20px",
                  cursor: isLoadingMore ? "not-allowed" : "pointer",
                  fontSize: "0.95rem",
                  fontWeight: 600,
                  transition: "all 0.2s ease"
                }}
              >
                {isLoadingMore ? "載入中..." : `▼ 載入更多歷史集數 (第 ${currentPage + 1} 頁 / 共 64 頁)`}
              </button>
            </div>
          )}
        </section>
      </main>

      <footer style={{ marginTop: "3rem", paddingTop: "1rem", borderTop: "1px solid rgba(255,255,255,0.1)", fontSize: "0.85rem", color: "#888" }}>
        <span>Video.js v10.4.0 • React 18 / 19 • <a href="https://videojs.org/" target="_blank" rel="noreferrer" style={{ color: "#aaa" }}>videojs.org</a></span>
      </footer>
    </div>
  );
}

const rootEl = document.getElementById("root");
if (rootEl) {
  createRoot(rootEl).render(<App />);
}
