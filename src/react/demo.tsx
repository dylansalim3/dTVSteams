import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  RiArrowDownSLine,
  RiArrowLeftLine,
  RiCalendarLine,
  RiExternalLinkLine,
  RiFilmLine,
  RiPlayFill,
  RiRefreshLine,
  RiTv2Line,
} from "@remixicon/react";
import { Chip } from "@/components/base/badges/chip";
import { Counter } from "@/components/base/badges/counter";
import { Button } from "@/components/base/buttons/button";
import { LinkButton } from "@/components/base/buttons/link-button";
import { Divider } from "@/components/base/divider/divider";
import { SearchField } from "@/components/base/search-field/search-field";
import {
  SegmentedControl,
  SegmentedControlItem,
} from "@/components/base/segmented-control/segmented-control";
import { Skeleton } from "@/components/base/skeleton/skeleton";
import { DirectionProvider } from "@/components/foundations/direction/direction";
import { cx } from "@/utils/cx";
import { VideoJs10Player } from "./VideoJs10Player.js";

interface EpisodePart {
  label: string;
  streamUrl?: string;
  url?: string;
  duration?: string;
}

interface EpisodeItem {
  id: string;
  title: string;
  date: string;
  url: string;
  duration?: string;
  poster?: string;
  parts: EpisodePart[];
}

const FALLBACK_EPISODES: EpisodeItem[] = [
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
    ],
  },
];

function resolveStreamUrl(part?: EpisodePart) {
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
  return "../media/thumb-default.svg";
}

function App() {
  const [episodes, setEpisodes] = useState<EpisodeItem[]>([]);
  const [selectedEpId, setSelectedEpId] = useState<string>("");
  const [partIndex, setPartIndex] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [searchQuery, setSearchQuery] = useState("");
  const [isInitialLoading, setIsInitialLoading] = useState(true);
  const [catalogError, setCatalogError] = useState<string | null>(null);
  const [loadMoreError, setLoadMoreError] = useState<string | null>(null);
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  const loadCatalog = async () => {
    setIsInitialLoading(true);
    setCatalogError(null);
    try {
      const res = await fetch("../catalog.json");
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const loaded: EpisodeItem[] =
        data.episodes && data.episodes.length > 0 ? data.episodes : FALLBACK_EPISODES;
      setEpisodes(loaded);
      setSelectedEpId((prev) => prev || loaded[0]?.id || "");
    } catch {
      setEpisodes(FALLBACK_EPISODES);
      setSelectedEpId((prev) => prev || FALLBACK_EPISODES[0].id);
      setCatalogError("無法載入完整遠端目錄，已切換為離線精選集數。");
    } finally {
      setIsInitialLoading(false);
    }
  };

  useEffect(() => {
    void loadCatalog();
  }, []);

  const filteredEpisodes = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return episodes;
    return episodes.filter(
      (ep) =>
        ep.title.toLowerCase().includes(q) ||
        (ep.date && ep.date.toLowerCase().includes(q)),
    );
  }, [episodes, searchQuery]);

  const activeEp = useMemo(
    () =>
      episodes.find((ep) => ep.id === selectedEpId) ||
      episodes[0] ||
      FALLBACK_EPISODES[0],
    [episodes, selectedEpId],
  );

  const parts = activeEp.parts?.length ? activeEp.parts : FALLBACK_EPISODES[0].parts;
  const safePartIndex = partIndex < parts.length ? partIndex : 0;
  const activePart = parts[safePartIndex] || parts[0];

  const handleLoadMore = async () => {
    if (isLoadingMore || currentPage >= 64) return;
    setIsLoadingMore(true);
    setLoadMoreError(null);
    const nextPage = currentPage + 1;
    try {
      const res = await fetch(`/api/episodes?page=${nextPage}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      if (data.ok && data.episodes) {
        setEpisodes((prev) => {
          const seen = new Set(prev.map((e) => e.id));
          const newItems = (data.episodes as EpisodeItem[]).filter((e) => !seen.has(e.id));
          return [...prev, ...newItems];
        });
        setCurrentPage(nextPage);
      }
    } catch {
      setLoadMoreError(`第 ${nextPage} 頁集數載入失敗，請檢查連線後重試。`);
    } finally {
      setIsLoadingMore(false);
    }
  };

  return (
    <DirectionProvider locale="zh-Hant">
      <div className="min-h-screen bg-background-full text-text-primary">
        {/* Top Application Header */}
        <header className="sticky top-0 z-30 border-b border-separator-border bg-background-secondary-default/90 backdrop-blur-md">
          <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-3.5 sm:px-6">
            <div className="flex items-center gap-3">
              <div className="flex size-9 items-center justify-center rounded-2lg bg-accent-500 text-white shadow-card">
                <RiTv2Line className="size-5" aria-hidden="true" />
              </div>
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <h1 className="text-title-3-semibold tracking-tight text-text-primary">
                    dTVSteams Studio
                  </h1>
                  <Counter color="primary" className="tabular-nums">
                    v10
                  </Counter>
                </div>
                <p className="text-caption-1-regular text-text-secondary">
                  Video.js 10 React 播放工作台與多段劇集瀏覽
                </p>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <LinkButton
                href="../index.html"
                variant="secondary"
                size="small"
                leadingIcon={RiArrowLeftLine}
              >
                返回一般網頁版
              </LinkButton>
            </div>
          </div>
        </header>

        <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          {catalogError ? (
            <div className="mb-5 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default px-4 py-3">
              <span className="text-body-2-regular text-text-secondary">{catalogError}</span>
              <Button
                variant="secondary"
                size="small"
                leadingIcon={RiRefreshLine}
                onClick={() => void loadCatalog()}
              >
                重新連線目錄
              </Button>
            </div>
          ) : null}

          {/* Hero Theater Workspace */}
          <section className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
            <div className="overflow-hidden rounded-3xl border border-separator-border bg-background-secondary-default p-2 shadow-card">
              <div className="overflow-hidden rounded-2xl bg-black">
                <VideoJs10Player
                  src={resolveStreamUrl(activePart)}
                  poster="../preview.png"
                  title={`${activeEp.title} · ${activePart.label}`}
                  episodeId={activeEp.id}
                  partIndex={safePartIndex}
                  autoPlay={false}
                  onEnded={() => {
                    if (safePartIndex < parts.length - 1) {
                      setPartIndex(safePartIndex + 1);
                    }
                  }}
                />
              </div>
            </div>

            {/* Active Episode Inspector & Part Switcher Panel */}
            <aside className="flex flex-col justify-between gap-4 rounded-3xl border border-separator-border bg-background-secondary-default p-5 shadow-card">
              <div className="flex flex-col gap-3">
                <div className="flex items-center justify-between gap-2">
                  <Chip variant="caption" color="rose">
                    正在播放
                  </Chip>
                  <span className="inline-flex items-center gap-1 text-caption-1-medium tabular-nums text-text-secondary">
                    <RiCalendarLine className="size-3.5 text-foreground-icon-secondary" aria-hidden="true" />
                    {activeEp.date || "最新集數"}
                  </span>
                </div>

                <h2 className="text-title-2-medium text-balance tracking-tight text-text-primary">
                  {activeEp.title}
                </h2>

                <div className="flex flex-wrap items-center gap-2">
                  <Chip variant="caption" color="soft" className="tabular-nums">
                    {activeEp.duration || "1小時 48分"}
                  </Chip>
                  <Chip variant="caption" color="neutral" className="tabular-nums">
                    {parts.length} 個分段
                  </Chip>
                </div>

                <Divider className="my-1" />

                <div className="flex flex-col gap-2">
                  <div className="flex items-center justify-between">
                    <span className="text-caption-1-semibold text-text-secondary">
                      分段切換
                    </span>
                    <span className="text-caption-1-medium tabular-nums text-text-tertiary">
                      {activePart.label} / {parts.length}
                    </span>
                  </div>

                  <SegmentedControl
                    aria-label="播放分段切換"
                    selectedKeys={[String(safePartIndex)]}
                    onSelectionChange={(keys) => {
                      const next = Number(Array.from(keys)[0] ?? 0);
                      if (!Number.isNaN(next)) setPartIndex(next);
                    }}
                    className="w-full"
                  >
                    {parts.map((part, idx) => (
                      <SegmentedControlItem
                        key={part.label + idx}
                        id={String(idx)}
                        className="flex-1"
                      >
                        {part.label}
                      </SegmentedControlItem>
                    ))}
                  </SegmentedControl>
                </div>
              </div>

              <div className="flex flex-col gap-2 pt-2">
                <Button
                  variant="primary"
                  size="medium"
                  leadingIcon={RiPlayFill}
                  onClick={() => {
                    const nextIdx = (safePartIndex + 1) % parts.length;
                    setPartIndex(nextIdx);
                  }}
                >
                  切換下一段 ({parts[(safePartIndex + 1) % parts.length]?.label || "Part 1"})
                </Button>
                <span className="text-caption-1-regular text-text-tertiary">
                  支援自動續播與瀏覽器本機斷點紀錄
                </span>
              </div>
            </aside>
          </section>

          {/* Catalog Controls & Grid */}
          <section className="mt-8 flex flex-col gap-5">
            <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
              <div className="flex items-center gap-2.5">
                <h2 className="text-title-2-medium tracking-tight text-text-primary">
                  集數目錄
                </h2>
                <Counter color="neutral" className="tabular-nums">
                  {filteredEpisodes.length}
                </Counter>
              </div>

              <div className="flex w-full items-center gap-3 sm:w-80">
                <SearchField
                  aria-label="搜尋集數或日期"
                  placeholder="搜尋集數標題、地點或日期..."
                  shape="rounded"
                  size="medium"
                  value={searchQuery}
                  onChange={setSearchQuery}
                />
              </div>
            </div>

            {isInitialLoading ? (
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {Array.from({ length: 8 }).map((_, idx) => (
                  <div
                    key={idx}
                    className="flex flex-col gap-3 rounded-2xl border border-separator-border bg-background-secondary-default p-3"
                  >
                    <Skeleton className="aspect-video w-full" />
                    <Skeleton shape="text" className="h-4 w-4/5" />
                    <Skeleton shape="text" className="h-3.5 w-1/2" />
                  </div>
                ))}
              </div>
            ) : filteredEpisodes.length === 0 ? (
              <div className="flex flex-col items-center justify-center gap-3 rounded-3xl border border-separator-border bg-background-secondary-default px-6 py-12 text-center">
                <div className="flex size-12 items-center justify-center rounded-2xl bg-background-tertiary-default text-foreground-icon-secondary">
                  <RiFilmLine className="size-6" aria-hidden="true" />
                </div>
                <div className="flex flex-col gap-1">
                  <h3 className="text-headline-medium text-text-primary">
                    找不到符合條件的集數
                  </h3>
                  <p className="text-body-regular text-text-secondary">
                    請嘗試清除搜尋關鍵字或載入更多歷史集數。
                  </p>
                </div>
                <Button variant="secondary" size="small" onClick={() => setSearchQuery("")}>
                  清除搜尋
                </Button>
              </div>
            ) : (
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {filteredEpisodes.map((ep, idx) => {
                  const isSelected = ep.id === activeEp.id;
                  return (
                    <button
                      key={ep.id + idx}
                      type="button"
                      onClick={() => {
                        setSelectedEpId(ep.id);
                        setPartIndex(0);
                      }}
                      className={cx(
                        "group flex cursor-pointer flex-col gap-3 rounded-2xl border p-3 text-left transition-[background-color,border-color,box-shadow] duration-150 ease-out",
                        "outline-none focus-visible:ring-2 focus-visible:ring-border-focus-ring",
                        isSelected
                          ? "border-accent-500 bg-background-primary-default shadow-card"
                          : "border-separator-border bg-background-secondary-default hover:border-border-button-hover hover:bg-background-primary-default",
                      )}
                    >
                      <div className="relative aspect-video w-full overflow-hidden rounded-xl bg-black">
                        <img
                          src={resolveEpisodeThumb(ep)}
                          alt={ep.title}
                          loading="lazy"
                          onError={(e) => {
                            (e.currentTarget as HTMLImageElement).src = "../media/thumb-default.svg";
                          }}
                          className="size-full object-cover transition-transform duration-300 ease-out group-hover:scale-[1.02]"
                        />
                        <Chip
                          variant="caption"
                          color="gray"
                          className="absolute right-2 bottom-2 bg-black/75 tabular-nums text-white"
                        >
                          {ep.duration || "1小時 48分"}
                        </Chip>
                      </div>

                      <div className="flex min-w-0 flex-1 flex-col justify-between gap-2 px-0.5">
                        <h3 className="line-clamp-2 text-body-medium text-text-primary">
                          {ep.title}
                        </h3>
                        <div className="flex items-center justify-between gap-2 text-caption-1-regular tabular-nums text-text-secondary">
                          <span>{ep.date || "最新"}</span>
                          <span>{ep.parts?.length || 3} 個分段</span>
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            )}

            {loadMoreError ? (
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-error-default bg-background-tertiary-error px-4 py-3">
                <span className="text-body-2-regular text-text-error-primary">{loadMoreError}</span>
                <Button
                  variant="secondary"
                  size="small"
                  leadingIcon={RiRefreshLine}
                  onClick={() => void handleLoadMore()}
                >
                  重試載入
                </Button>
              </div>
            ) : null}

            {currentPage < 64 && !searchQuery.trim() ? (
              <div className="flex justify-center pt-2">
                <Button
                  variant="secondary"
                  size="medium"
                  leadingIcon={RiArrowDownSLine}
                  disabled={isLoadingMore}
                  onClick={() => void handleLoadMore()}
                >
                  {isLoadingMore
                    ? "正在載入歷史集數..."
                    : `載入更多集數 (第 ${currentPage + 1} / 64 頁)`}
                </Button>
              </div>
            ) : null}
          </section>
        </main>

        <footer className="mt-10 border-t border-separator-border bg-background-secondary-default/40">
          <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-5 text-caption-1-regular text-text-secondary sm:px-6">
            <span>dTVSteams • Video.js 10 + BoardUI Design System</span>
            <LinkButton
              href="https://videojs.org/"
              target="_blank"
              rel="noreferrer"
              variant="secondary"
              size="xs"
              trailingIcon={RiExternalLinkLine}
            >
              videojs.org
            </LinkButton>
          </div>
        </footer>
      </div>
    </DirectionProvider>
  );
}

const rootEl = document.getElementById("root");
if (rootEl) {
  createRoot(rootEl).render(<App />);
}
