import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  RiArrowDownLine,
  RiArrowDownSLine,
  RiArrowLeftSLine,
  RiArrowRightSLine,
  RiArrowUpLine,
  RiCheckLine,
  RiCloseLine,
  RiDownloadLine,
  RiErrorWarningLine,
  RiExternalLinkLine,
  RiFileCopyLine,
  RiFilmLine,
  RiFolderMusicLine,
  RiHeartFill,
  RiHeartLine,
  RiHistoryLine,
  RiInformationLine,
  RiMapPinLine,
  RiPlayFill,
  RiRefreshLine,
  RiSettings3Line,
  RiShareForwardLine,
  RiTv2Line,
} from "@remixicon/react";
import { Chip } from "@/components/base/badges/chip";
import { Counter } from "@/components/base/badges/counter";
import { Button } from "@/components/base/buttons/button";
import { CloseButton } from "@/components/base/buttons/close-button";
import { IconButton, IconLinkButton } from "@/components/base/buttons/icon-button";
import { LinkButton } from "@/components/base/buttons/link-button";
import { Divider } from "@/components/base/divider/divider";
import { SearchField } from "@/components/base/search-field/search-field";
import {
  SegmentedControl,
  SegmentedControlItem,
} from "@/components/base/segmented-control/segmented-control";
import { Skeleton } from "@/components/base/skeleton/skeleton";
import { Spinner } from "@/components/base/spinner/spinner";
import { DirectionProvider } from "@/components/foundations/direction/direction";
import { cx } from "@/utils/cx";
import { VideoJs10Player, getStoredResume } from "./VideoJs10Player.js";
import {
  buildPartDownloadHref,
  getDownloadFilename,
  isIosDevice,
  triggerBrowserDownload,
} from "./download.js";
import {
  EpisodeItem,
  EpisodePart,
  LATEST_APK_RELEASE_URL,
  SHOW_CHANNELS,
  ShowChannelMeta,
  YEAR_OPTIONS,
  detectShowChannel,
  extractLocation,
  matchesYearFilter,
  stripShowNameFromTitle,
} from "./channels.js";

const FAVORITES_STORAGE_KEY = "dtv_favorites";
const RESUME_STORAGE_KEY = "dtv_resume_history";

interface HistoryEntry {
  episodeId: string;
  partIndex: number;
  currentTime: number;
  duration: number;
  percentage: number;
  completed: boolean;
  updatedAt: number;
  title?: string;
  showName?: string;
  partLabel?: string;
}

function readFavorites(): EpisodeItem[] {
  try {
    const raw = localStorage.getItem(FAVORITES_STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function writeFavorites(list: EpisodeItem[]): void {
  try {
    localStorage.setItem(FAVORITES_STORAGE_KEY, JSON.stringify(list));
  } catch {}
}

function readHistoryList(): HistoryEntry[] {
  try {
    const raw = localStorage.getItem(RESUME_STORAGE_KEY);
    if (!raw) return [];
    const map = JSON.parse(raw) as Record<string, HistoryEntry>;
    return Object.values(map).sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
  } catch {
    return [];
  }
}

function formatSeconds(sec: number): string {
  if (!sec || Number.isNaN(sec) || sec < 0) return "00:00";
  const s = Math.floor(sec);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
}

function resolveStreamUrl(
  part?: EpisodePart,
  options?: { forceProxy?: boolean; forceRefresh?: boolean },
) {
  if (!part) return "../media/sample-part1.mp4";
  const pageUrl = part.url || "";
  let streamUrl = part.streamUrl || "";
  if (streamUrl.includes("sample-part")) {
    streamUrl = "";
  }
  if (typeof window !== "undefined" && window.location.protocol.startsWith("http")) {
    const params = new URLSearchParams();
    if (streamUrl) params.set("url", streamUrl);
    if (pageUrl) params.set("pageUrl", pageUrl);
    // iOS AVPlayer fails CORS/307 redirects when crossOrigin or Range preflight hits CDN 405 OPTIONS
    if (options?.forceProxy || isIosDevice()) {
      params.set("proxy", "true");
    }
    if (options?.forceRefresh) {
      params.set("refresh", "true");
    }
    return `/api/stream?${params.toString()}`;
  }
  return streamUrl || "../media/sample-part1.mp4";
}

function buildShareUrl(ep: EpisodeItem, partIdx: number): string {
  const origin =
    typeof window !== "undefined" &&
    window.location.origin &&
    !window.location.origin.startsWith("null")
      ? window.location.origin
      : "https://dtvsteams.pages.dev";
  const params = new URLSearchParams();
  if (ep.id) params.set("ep", ep.id);
  if (partIdx > 0) params.set("part", String(partIdx + 1));
  return `${origin}/?${params.toString()}`;
}

function App() {
  const [currentChannel, setCurrentChannel] = useState<ShowChannelMeta>(SHOW_CHANNELS[0]);
  const [episodes, setEpisodes] = useState<EpisodeItem[]>([]);
  const [selectedEpId, setSelectedEpId] = useState<string>("");
  const [partIndex, setPartIndex] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageCache, setPageCache] = useState<Record<string, EpisodeItem[]>>({});

  const [searchQuery, setSearchQuery] = useState("");
  const [selectedYear, setSelectedYear] = useState<string>("全部");
  const [isSortAscending, setIsSortAscending] = useState(false);

  const [isInitialLoading, setIsInitialLoading] = useState(true);
  const [isLoadingPage, setIsLoadingPage] = useState(false);
  const [catalogError, setCatalogError] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);

  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [streamRetryLevel, setStreamRetryLevel] = useState(0);
  const [isChannelModalOpen, setIsChannelModalOpen] = useState(false);
  const [isLibraryModalOpen, setIsLibraryModalOpen] = useState(false);
  const [libraryTab, setLibraryTab] = useState<"favorites" | "history">("favorites");
  const [isShareModalOpen, setIsShareModalOpen] = useState(false);
  const [copiedShareUrl, setCopiedShareUrl] = useState(false);
  const [downloadTargetEp, setDownloadTargetEp] = useState<EpisodeItem | null>(null);
  const [resolvedDownloadUrls, setResolvedDownloadUrls] = useState<Record<number, string>>({});
  const [partResolveStates, setPartResolveStates] = useState<Record<number, "idle" | "resolving" | "ready" | "error">>({});
  const [partDownloadStarted, setPartDownloadStarted] = useState<Record<number, boolean>>({});
  const [downloadBackendUnavailable, setDownloadBackendUnavailable] = useState(false);
  const [downloadModalNotice, setDownloadModalNotice] = useState<string | null>(null);

  const [favorites, setFavorites] = useState<EpisodeItem[]>(() => readFavorites());
  const [historyEntries, setHistoryEntries] = useState<HistoryEntry[]>(() => readHistoryList());

  const loadChannelPage = async (channel: ShowChannelMeta, page = 1) => {
    const cacheKey = `${channel.id}:${page}`;
    if (pageCache[cacheKey]) {
      setEpisodes(pageCache[cacheKey]);
      setCurrentPage(page);
      setIsInitialLoading(false);
      return;
    }

    if (page === 1) setIsInitialLoading(true);
    setIsLoadingPage(true);
    setCatalogError(null);

    try {
      let loaded: EpisodeItem[] = [];
      if (page === 1 && channel.id === "mr_player") {
        try {
          const res = await fetch(`./catalog.json?_t=${Date.now()}`, { cache: "no-store" });
          if (res.ok) {
            const data = await res.json();
            loaded = data.episodes || [];
          }
        } catch {}
      }

      if (!loaded.length) {
        const res = await fetch(
          `/api/episodes?page=${page}&show=${encodeURIComponent(channel.id)}`,
        );
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        loaded = data.episodes || [];
      }

      if (!loaded.length) throw new Error("空集數清單");

      setPageCache((prev) => ({ ...prev, [cacheKey]: loaded }));
      setEpisodes(loaded);
      setCurrentPage(page);
      if (page === 1) {
        setSelectedEpId((prev) => prev || loaded[0]?.id || "");
      }
      setStatusMessage(`已同步 (${loaded.length} 集)`);
    } catch {
      const fallback = page === 1 ? channel.fallbackEpisodes : episodes;
      setEpisodes(fallback);
      if (page === 1) {
        setSelectedEpId(fallback[0]?.id || "");
      }
      setCatalogError("暫時無法連線至遠端目錄，已顯示離線預設清單。");
    } finally {
      setIsInitialLoading(false);
      setIsLoadingPage(false);
    }
  };

  useEffect(() => {
    void loadChannelPage(SHOW_CHANNELS[0], 1);
  }, []);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setIsChannelModalOpen(false);
        setIsLibraryModalOpen(false);
        setIsShareModalOpen(false);
        setDownloadTargetEp(null);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  useEffect(() => {
    if (!downloadTargetEp) return;
    const targetParts = downloadTargetEp.parts?.length ? downloadTargetEp.parts : [];
    const isHttp = typeof window !== "undefined" && window.location.protocol.startsWith("http");
    let cancelled = false;

    setResolvedDownloadUrls({});
    setPartDownloadStarted({});
    setDownloadBackendUnavailable(false);
    setDownloadModalNotice(null);

    if (!isHttp || targetParts.every((p) => !p.url)) {
      const readyMap: Record<number, "ready"> = {};
      targetParts.forEach((_, idx) => {
        readyMap[idx] = "ready";
      });
      setPartResolveStates(readyMap);
      return;
    }

    const initialStates: Record<number, "resolving" | "ready"> = {};
    targetParts.forEach((p, idx) => {
      initialStates[idx] = p.url ? "resolving" : "ready";
    });
    setPartResolveStates(initialStates);

    void Promise.all(
      targetParts.map(async (p, idx) => {
        if (!p.url) return { idx, ok: true, status: 200, streamUrl: p.streamUrl || "" };
        try {
          const res = await fetch(`/api/resolve-stream?url=${encodeURIComponent(p.url)}`);
          if (!res.ok) {
            return { idx, ok: false, status: res.status, streamUrl: "" };
          }
          const data = (await res.json()) as { ok?: boolean; streamUrl?: string };
          return {
            idx,
            ok: Boolean(data?.ok && data?.streamUrl),
            status: res.status,
            streamUrl: data?.streamUrl || "",
          };
        } catch {
          return { idx, ok: false, status: 0, streamUrl: "" };
        }
      }),
    ).then((results) => {
      if (cancelled) return;
      const nextUrls: Record<number, string> = {};
      const nextStates: Record<number, "ready" | "error"> = {};
      let all404 = results.length > 0;
      for (const r of results) {
        if (r.status !== 404) all404 = false;
        if (r.ok && r.streamUrl) {
          nextUrls[r.idx] = r.streamUrl;
          nextStates[r.idx] = "ready";
        } else {
          // Proxy endpoint /api/stream can still resolve pageUrl at download time unless backend is 404
          nextStates[r.idx] = r.status === 404 ? "error" : "ready";
        }
      }
      setResolvedDownloadUrls(nextUrls);
      setPartResolveStates(nextStates);
      if (all404) {
        setDownloadBackendUnavailable(true);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [downloadTargetEp]);

  const filteredEpisodes = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    const list = episodes.filter((ep) => {
      const matchQuery =
        !q ||
        ep.title.toLowerCase().includes(q) ||
        (ep.date && ep.date.toLowerCase().includes(q));
      const matchYear = matchesYearFilter(ep, selectedYear);
      return matchQuery && matchYear;
    });
    return [...list].sort((a, b) => {
      const cmp = (b.date || "").localeCompare(a.date || "");
      return isSortAscending ? -cmp : cmp;
    });
  }, [episodes, searchQuery, selectedYear, isSortAscending]);

  const activeEp = useMemo(
    () =>
      episodes.find((ep) => ep.id === selectedEpId) ||
      episodes[0] ||
      currentChannel.fallbackEpisodes[0],
    [episodes, selectedEpId, currentChannel],
  );

  const parts = activeEp.parts?.length ? activeEp.parts : currentChannel.fallbackEpisodes[0].parts;
  const safePartIndex = partIndex < parts.length ? partIndex : 0;
  const activePart = parts[safePartIndex] || parts[0];

  useEffect(() => {
    setStreamRetryLevel(0);
  }, [activeEp.id, safePartIndex]);

  const handleToggleFavorite = (ep: EpisodeItem) => {
    const exists = favorites.some((f) => f.id === ep.id);
    const next = exists ? favorites.filter((f) => f.id !== ep.id) : [ep, ...favorites];
    setFavorites(next);
    writeFavorites(next);
  };

  const handleSelectChannel = (ch: ShowChannelMeta) => {
    setIsChannelModalOpen(false);
    if (ch.id === currentChannel.id) return;
    setCurrentChannel(ch);
    setSelectedYear("全部");
    setSearchQuery("");
    setSelectedEpId("");
    setPartIndex(0);
    void loadChannelPage(ch, 1);
  };

  const handleDownloadPart = (ep: EpisodeItem, idx = 0): boolean => {
    const p = ep.parts?.[idx] || ep.parts?.[0];
    if (!p) return false;
    const filename = getDownloadFilename(ep, idx);
    const resolved = resolvedDownloadUrls[idx];
    const href = buildPartDownloadHref(p, filename, resolved);
    if (!href) return false;
    triggerBrowserDownload(href, filename, idx);
    setPartDownloadStarted((prev) => ({ ...prev, [idx]: true }));
    return true;
  };

  const handleConfirmDownloadAll = (ep: EpisodeItem) => {
    const epParts = ep.parts?.length ? ep.parts : [];
    if (!epParts.length) return;
    let startedCount = 0;
    epParts.forEach((_, idx) => {
      if (handleDownloadPart(ep, idx)) {
        startedCount += 1;
      }
    });
    if (startedCount > 0) {
      setStatusMessage(`已開始下載 ${startedCount} 個影片分段`);
      setDownloadModalNotice(
        startedCount > 1
          ? `已送出全部 ${startedCount} 個分段下載！若瀏覽器僅開始下載第 1 個檔案，請點選「允許下載多個檔案」，或直接點擊下方各分段按鈕單獨下載。`
          : "已送出影片下載，請查看瀏覽器下載進度。",
      );
    } else {
      setDownloadModalNotice("目前無法取得下載連結，請稍後再試或檢查網路連線。");
    }
  };

  const shareUrl = useMemo(() => buildShareUrl(activeEp, safePartIndex), [activeEp, safePartIndex]);

  const handleCopyShareUrl = async () => {
    try {
      await navigator.clipboard.writeText(shareUrl);
      setCopiedShareUrl(true);
      setTimeout(() => setCopiedShareUrl(false), 2000);
    } catch {}
  };

  // Pagination window matching Flutter GooglePaginationBar
  const totalPages = Math.max(10, currentPage + 4);
  const startPage = Math.max(1, Math.min(currentPage - 2, totalPages - 4));
  const endPage = Math.min(totalPages, startPage + 4);
  const visiblePages = Array.from({ length: endPage - startPage + 1 }, (_, i) => startPage + i);

  return (
    <DirectionProvider locale="zh-Hant">
      <div className="min-h-screen bg-background-full text-text-primary">
        {/* Mobile-Mirrored Top App Bar */}
        <header className="sticky top-0 z-30 border-b border-separator-border bg-background-secondary-default/95 backdrop-blur-md">
          <div className="mx-auto flex h-14 max-w-3xl items-center justify-between gap-2 px-3">
            {/* Left: dTV badge + STEAMS + Channel Switcher Pill */}
            <div className="flex min-w-0 items-center gap-2">
              <a
                href="./"
                className="flex shrink-0 items-center gap-1.5 rounded-md outline-none focus-visible:ring-2 focus-visible:ring-border-focus-ring"
              >
                <span className="rounded-md bg-accent-500 px-1.5 py-0.5 text-sm font-extrabold tracking-wide text-white">
                  dTV
                </span>
                <span className="hidden text-caption-1-semibold tracking-widest text-text-secondary sm:inline">
                  STEAMS
                </span>
              </a>

              <button
                type="button"
                onClick={() => setIsChannelModalOpen(true)}
                aria-label="切換節目頻道"
                className={cx(
                  "flex min-w-0 max-w-[165px] cursor-pointer items-center gap-1 rounded-2lg border border-border-button-default bg-background-tertiary-default px-2.5 py-1.5 shadow-card",
                  "outline-none transition-colors hover:border-border-button-hover focus-visible:ring-2 focus-visible:ring-border-focus-ring",
                )}
              >
                <span className="shrink-0 text-xs" aria-hidden="true">
                  {currentChannel.emoji}
                </span>
                <span className="truncate text-caption-1-semibold text-text-primary">
                  {currentChannel.name}
                </span>
                <RiArrowDownSLine className="size-4 shrink-0 text-foreground-icon-secondary" aria-hidden="true" />
              </button>
            </div>

            {/* Right: Library (Favorites + History), Refresh, Share (moved from card/player), Settings -> GitHub APK */}
            <div className="flex shrink-0 items-center gap-1">
              <IconButton
                size="small"
                icon={RiFolderMusicLine}
                aria-label="我的收藏與觀看紀錄"
                title="收藏與觀看紀錄"
                onClick={() => {
                  setHistoryEntries(readHistoryList());
                  setIsLibraryModalOpen(true);
                }}
              />

              <IconButton
                size="small"
                icon={RiRefreshLine}
                aria-label="刷新集數清單"
                title="刷新集數"
                disabled={isLoadingPage}
                onClick={() => {
                  setPageCache((prev) => {
                    const copy = { ...prev };
                    delete copy[`${currentChannel.id}:${currentPage}`];
                    return copy;
                  });
                  void loadChannelPage(currentChannel, currentPage);
                }}
              />

              {/* Share button placed in Header beside Settings */}
              <IconButton
                size="small"
                icon={RiShareForwardLine}
                aria-label="分享目前集數"
                title="分享集數與連結"
                onClick={() => setIsShareModalOpen(true)}
              />

              {/* Settings gear links directly to GitHub Latest APK page */}
              <IconLinkButton
                href={LATEST_APK_RELEASE_URL}
                target="_blank"
                rel="noopener noreferrer"
                size="small"
                icon={RiSettings3Line}
                aria-label="前往 GitHub 下載最新 Android APK"
                title="下載最新 Android APK (GitHub Releases)"
              />
            </div>
          </div>
        </header>

        {/* Single-Column Mobile-App Shell */}
        <main className="mx-auto flex max-w-3xl flex-col gap-3 px-3 py-3 pb-10">
          {/* BoardUI SearchField */}
          <SearchField
            aria-label="搜尋集數、日期或地點"
            placeholder="搜尋集數、日期 (如 2026-11-08) 或地點 (台北、宜蘭)..."
            shape="rounded"
            size="medium"
            value={searchQuery}
            onChange={setSearchQuery}
          />

          {/* Horizontal Year Filter Chips + Chronological Sort Switch (matching Flutter) */}
          <div className="flex items-center gap-2">
            <div className="flex min-w-0 flex-1 items-center gap-1.5 overflow-x-auto py-0.5 [scrollbar-width:none]">
              {YEAR_OPTIONS.map((year) => {
                const isSelected = selectedYear === year;
                return (
                  <button
                    key={year}
                    type="button"
                    onClick={() => setSelectedYear(year)}
                    className={cx(
                      "shrink-0 cursor-pointer rounded-md border px-3 py-1.5 text-caption-1-medium tabular-nums transition-colors",
                      "outline-none focus-visible:ring-2 focus-visible:ring-border-focus-ring",
                      isSelected
                        ? "border-accent-500 bg-accent-500 font-semibold text-white"
                        : "border-separator-border bg-background-secondary-default text-text-secondary hover:bg-background-tertiary-default hover:text-text-primary",
                    )}
                  >
                    {year}
                  </button>
                );
              })}
            </div>

            <button
              type="button"
              onClick={() => setIsSortAscending((v) => !v)}
              aria-label="切換集數排序"
              className={cx(
                "flex shrink-0 cursor-pointer items-center gap-1 rounded-2lg border px-2.5 py-1.5 text-caption-1-semibold transition-colors",
                "outline-none focus-visible:ring-2 focus-visible:ring-border-focus-ring",
                isSortAscending
                  ? "border-accent-500 bg-accent-500 text-white"
                  : "border-separator-border bg-background-secondary-default text-text-primary hover:bg-background-tertiary-default",
              )}
            >
              {isSortAscending ? (
                <RiArrowUpLine className="size-3.5" aria-hidden="true" />
              ) : (
                <RiArrowDownLine className="size-3.5" aria-hidden="true" />
              )}
              <span>{isSortAscending ? "舊到新" : "新到舊"}</span>
            </button>
          </div>

          {catalogError ? (
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-border-button-default bg-background-secondary-default px-3.5 py-2.5">
              <span className="text-caption-1-regular text-text-secondary">{catalogError}</span>
              <Button
                variant="secondary"
                size="small"
                leadingIcon={RiRefreshLine}
                onClick={() => void loadChannelPage(currentChannel, currentPage)}
              >
                重試連線
              </Button>
            </div>
          ) : null}

          {/* Collapsible Mobile-Styled Video Player Card */}
          <section className="rounded-2xl border border-separator-border bg-background-secondary-default p-3 shadow-card">
            <div className="flex items-center justify-between gap-2">
              <div className="flex min-w-0 flex-wrap items-center gap-2">
                <Chip variant="caption" color="rose" className="tabular-nums">
                  {activePart.label}
                </Chip>
                <span className="truncate text-caption-1-semibold text-text-primary">
                  {activeEp.title}
                </span>
              </div>
              <Button
                variant="secondary"
                size="xs"
                onClick={() => setIsPlayerCollapsed((c) => !c)}
              >
                {isPlayerCollapsed ? "展開播放器" : "收合播放器"}
              </Button>
            </div>

            {!isPlayerCollapsed ? (
              <div className="mt-3 flex flex-col gap-3">
                <div className="overflow-hidden rounded-xl border border-separator-border bg-black">
                  <VideoJs10Player
                    src={resolveStreamUrl(activePart, {
                      forceProxy: streamRetryLevel > 0,
                      forceRefresh: streamRetryLevel > 0,
                    })}
                    poster={activeEp.poster || "./media/thumb-default.svg"}
                    title={`${activeEp.title} · ${activePart.label}`}
                    episodeId={activeEp.id}
                    partIndex={safePartIndex}
                    autoPlay={false}
                    onTimeUpdate={() => setHistoryEntries(readHistoryList())}
                    onError={() => {
                      if (streamRetryLevel === 0 && activePart?.url) {
                        setStreamRetryLevel(1);
                        setStatusMessage("正在切換至相容串流線路...");
                      }
                    }}
                    onEnded={() => {
                      if (safePartIndex < parts.length - 1) {
                        setPartIndex(safePartIndex + 1);
                      }
                    }}
                  />
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
            ) : null}
          </section>

          {/* Section Header Strip (identical to Flutter) */}
          <section className="flex flex-col gap-2.5 pt-1">
            <div className="flex items-center justify-between gap-2 px-0.5">
              <div className="flex items-center gap-2">
                <h1 className="text-headline-medium tracking-tight text-text-primary">
                  最新劇集與節目 (Episodes)
                </h1>
                <Counter color="neutral" className="tabular-nums">
                  {filteredEpisodes.length} 集
                </Counter>
              </div>
              {statusMessage ? (
                <span className="text-caption-1-regular text-text-secondary">
                  {statusMessage}
                </span>
              ) : null}
            </div>

            {/* 1-by-1 Vertical Mobile Feed Cards */}
            {isInitialLoading ? (
              <div className="flex flex-col gap-2.5">
                {Array.from({ length: 5 }).map((_, idx) => (
                  <div
                    key={idx}
                    className="flex flex-col gap-2.5 rounded-2xl border border-separator-border bg-background-secondary-default p-3"
                  >
                    <div className="flex items-start gap-3">
                      <Skeleton className="size-9 rounded-full" />
                      <div className="flex-1 space-y-2">
                        <Skeleton shape="text" className="h-4 w-4/5" />
                        <Skeleton shape="text" className="h-3 w-1/2" />
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Skeleton className="h-7 w-16 rounded-lg" />
                      <Skeleton className="h-7 w-16 rounded-lg" />
                      <Skeleton className="h-7 w-16 rounded-lg" />
                    </div>
                  </div>
                ))}
              </div>
            ) : filteredEpisodes.length === 0 ? (
              <div className="flex flex-col items-center justify-center gap-3 rounded-2xl border border-separator-border bg-background-secondary-default px-6 py-12 text-center">
                <div className="flex size-12 items-center justify-center rounded-2xl bg-background-tertiary-default text-foreground-icon-secondary">
                  <RiFilmLine className="size-6" aria-hidden="true" />
                </div>
                <div className="flex flex-col gap-1">
                  <h2 className="text-headline-medium text-text-primary">
                    找不到符合條件的集數
                  </h2>
                  <p className="text-body-2-regular text-text-secondary">
                    請嘗試重設搜尋關鍵字或切換年份篩選。
                  </p>
                </div>
                <Button
                  variant="secondary"
                  size="small"
                  onClick={() => {
                    setSearchQuery("");
                    setSelectedYear("全部");
                  }}
                >
                  重設篩選條件
                </Button>
              </div>
            ) : (
              <div className="flex flex-col gap-2.5">
                {filteredEpisodes.map((ep, idx) => {
                  const showMeta = detectShowChannel(ep);
                  const displayTitle = stripShowNameFromTitle(ep.title, showMeta.name);
                  const location = extractLocation(ep.title);
                  const resume = getStoredResume(ep.id);
                  const isCompleted = Boolean(resume?.completed);
                  const isFav = favorites.some((f) => f.id === ep.id);
                  const isSelected = ep.id === activeEp.id;

                  return (
                    <article
                      key={ep.id + idx}
                      className={cx(
                        "flex cursor-pointer flex-col gap-2 rounded-2xl border bg-background-secondary-default p-3 shadow-card transition-colors",
                        isSelected
                          ? "border-accent-500"
                          : "border-separator-border hover:border-border-button-hover",
                      )}
                      onClick={() => {
                        setSelectedEpId(ep.id);
                        setPartIndex(0);
                        setIsPlayerCollapsed(false);
                        window.scrollTo({ top: 0, behavior: "smooth" });
                      }}
                    >
                      {/* Top Row: Play Circle + Metadata + Favorite & Download Actions */}
                      <div className="flex items-start gap-2.5">
                        <button
                          type="button"
                          aria-label="播放節目"
                          className="flex size-10 shrink-0 items-center justify-center"
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedEpId(ep.id);
                            setPartIndex(0);
                            setIsPlayerCollapsed(false);
                            window.scrollTo({ top: 0, behavior: "smooth" });
                          }}
                        >
                          <span
                            className={cx(
                              "flex size-9 items-center justify-center rounded-full border",
                              isCompleted
                                ? "border-border-button-default bg-background-tertiary-default text-text-primary"
                                : "border-accent-500/40 bg-accent-500/15 text-accent-500",
                            )}
                          >
                            <RiPlayFill className="size-4.5" aria-hidden="true" />
                          </span>
                        </button>

                        <div className="min-w-0 flex-1">
                          <h3
                            title={ep.title}
                            className="line-clamp-2 text-body-medium font-bold text-text-primary"
                          >
                            {displayTitle}
                          </h3>

                          <div className="mt-1 flex flex-wrap items-center gap-1.5">
                            {ep.date ? (
                              <span className="text-caption-1-medium tabular-nums text-text-secondary">
                                {ep.date}
                              </span>
                            ) : null}
                            <span className="rounded-md border border-accent-500/40 bg-accent-500/15 px-1.5 py-0.5 text-[10px] font-bold text-text-primary">
                              {showMeta.emoji} {showMeta.name}
                            </span>
                            {location ? (
                              <span className="inline-flex items-center gap-0.5 text-[11px] font-semibold text-accent-500">
                                <RiMapPinLine className="size-3" aria-hidden="true" />
                                {location}
                              </span>
                            ) : null}
                            {isCompleted ? (
                              <Chip variant="caption" color="lime">
                                ✓ 已看完
                              </Chip>
                            ) : null}
                          </div>
                        </div>

                        {/* Trailing Action Cluster (Favorite + Download — Share lives in Header!) */}
                        <div className="flex shrink-0 items-center">
                          <button
                            type="button"
                            aria-label={isFav ? "取消收藏" : "加入收藏"}
                            title={isFav ? "已收藏" : "加入收藏"}
                            className="flex size-10 cursor-pointer items-center justify-center rounded-full"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleToggleFavorite(ep);
                            }}
                          >
                            <span className="flex size-9 items-center justify-center rounded-full bg-background-tertiary-default text-foreground-icon-secondary hover:text-text-primary">
                              {isFav ? (
                                <RiHeartFill className="size-4 text-accent-500" aria-hidden="true" />
                              ) : (
                                <RiHeartLine className="size-4" aria-hidden="true" />
                              )}
                            </span>
                          </button>

                          <button
                            type="button"
                            aria-label="下載此集影片"
                            title={`下載此集（共 ${ep.parts?.length || 1} 個分段）`}
                            className="flex size-10 cursor-pointer items-center justify-center rounded-full"
                            onClick={(e) => {
                              e.stopPropagation();
                              setDownloadTargetEp(ep);
                            }}
                          >
                            <span className="flex size-9 items-center justify-center rounded-full bg-background-tertiary-default text-foreground-icon-secondary hover:text-text-primary">
                              <RiDownloadLine className="size-4" aria-hidden="true" />
                            </span>
                          </button>
                        </div>
                      </div>

                      {/* Part Selector Chips (Part 1, Part 2, Part 3) */}
                      <div className="flex flex-wrap gap-2">
                        {(ep.parts || []).map((part, pIdx) => {
                          const isPlayingPart = isSelected && safePartIndex === pIdx;
                          return (
                            <button
                              key={part.label + pIdx}
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                setSelectedEpId(ep.id);
                                setPartIndex(pIdx);
                                setIsPlayerCollapsed(false);
                                window.scrollTo({ top: 0, behavior: "smooth" });
                              }}
                              className={cx(
                                "inline-flex cursor-pointer items-center gap-1 rounded-lg border px-2.5 py-1.5 text-[11px] font-bold tabular-nums transition-colors",
                                isPlayingPart
                                  ? "border-accent-500 bg-accent-500 text-white"
                                  : "border-separator-border bg-background-primary-default text-text-primary hover:border-border-button-hover",
                              )}
                            >
                              <RiPlayFill className="size-3" aria-hidden="true" />
                              <span>{part.label}</span>
                            </button>
                          );
                        })}
                      </div>

                      {/* Bottom Progress Bar */}
                      {resume && resume.percentage > 2 ? (
                        <div className="h-0.5 w-full overflow-hidden rounded-full bg-separator-border">
                          <div
                            className="h-full bg-accent-500"
                            style={{ width: `${resume.percentage}%` }}
                          />
                        </div>
                      ) : null}
                    </article>
                  );
                })}
              </div>
            )}

            {/* Mobile Google-Style Numbered Pagination Bar */}
            <nav aria-label="分頁導覽" className="flex w-full items-center gap-1.5 pt-3">
              <button
                type="button"
                disabled={currentPage <= 1 || isLoadingPage}
                onClick={() => void loadChannelPage(currentChannel, currentPage - 1)}
                className={cx(
                  "flex h-10 flex-[3] items-center justify-center gap-1 rounded-lg border text-caption-1-semibold transition-colors",
                  currentPage > 1
                    ? "cursor-pointer border-border-button-default bg-background-secondary-default text-text-primary hover:bg-background-tertiary-default"
                    : "cursor-not-allowed border-separator-border bg-background-full text-text-tertiary",
                )}
              >
                <RiArrowLeftSLine className="size-3.5" aria-hidden="true" />
                <span>上一頁</span>
              </button>

              {visiblePages.map((p) => {
                const isCurr = p === currentPage;
                return (
                  <button
                    key={p}
                    type="button"
                    disabled={isLoadingPage}
                    onClick={() => void loadChannelPage(currentChannel, p)}
                    className={cx(
                      "flex h-10 flex-[2] cursor-pointer items-center justify-center rounded-lg border text-body-medium tabular-nums transition-colors",
                      isCurr
                        ? "border-accent-500 bg-accent-500 font-bold text-white"
                        : "border-separator-border bg-background-secondary-default text-text-secondary hover:bg-background-tertiary-default hover:text-text-primary",
                    )}
                  >
                    {p}
                  </button>
                );
              })}

              <button
                type="button"
                disabled={isLoadingPage}
                onClick={() => void loadChannelPage(currentChannel, currentPage + 1)}
                className="flex h-10 flex-[3] cursor-pointer items-center justify-center gap-1 rounded-lg border border-border-button-default bg-background-secondary-default text-caption-1-semibold text-text-primary transition-colors hover:bg-background-tertiary-default"
              >
                <span>下一頁</span>
                <RiArrowRightSLine className="size-3.5" aria-hidden="true" />
              </button>
            </nav>
          </section>
        </main>

        {/* Minimal Footer */}
        <footer className="mt-6 border-t border-separator-border bg-background-secondary-default/40">
          <div className="mx-auto flex max-w-3xl flex-wrap items-center justify-between gap-3 px-3 py-4 text-caption-1-regular text-text-secondary">
            <span>dTVSteams • Video.js 10 + BoardUI Design System</span>
            <LinkButton
              href={
                typeof window !== "undefined" && window.location.pathname.includes("/react")
                  ? "../tv-web/index.html"
                  : "https://dtvsteams-tv.pages.dev"
              }
              variant="secondary"
              size="xs"
              leadingIcon={RiTv2Line}
            >
              10-Foot 電視版
            </LinkButton>
          </div>
        </footer>

        {/* Channel Picker Sheet Modal */}
        {isChannelModalOpen ? (
          <dialog
            open
            aria-modal="true"
            aria-label="切換節目頻道"
            className="fixed inset-0 z-50 m-0 flex size-full max-h-none max-w-none items-end justify-center border-0 bg-black/75 p-3 backdrop-blur-xs sm:items-center"
            onClick={() => setIsChannelModalOpen(false)}
          >
            <div
              className="w-full max-w-md rounded-3xl border border-border-button-default bg-background-secondary-default p-5 shadow-xl"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="mb-3 flex items-center justify-between gap-2">
                <div className="flex items-center gap-2.5">
                  <div className="flex size-8 items-center justify-center rounded-lg border border-accent-500/35 bg-accent-500/15 text-accent-500">
                    <RiTv2Line className="size-4.5" aria-hidden="true" />
                  </div>
                  <h2 className="text-title-3-semibold text-text-primary">切換節目頻道 (Channels)</h2>
                </div>
                <CloseButton onClick={() => setIsChannelModalOpen(false)} aria-label="關閉頻道選單" />
              </div>
              <p className="mb-4 text-caption-1-regular text-text-secondary">
                選擇您想觀賞的綜藝節目，各頻道具備獨立集數清單與分頁快取
              </p>
              <div className="flex flex-col gap-2">
                {SHOW_CHANNELS.map((ch) => {
                  const isSelected = ch.id === currentChannel.id;
                  return (
                    <button
                      key={ch.id}
                      type="button"
                      onClick={() => handleSelectChannel(ch)}
                      className={cx(
                        "flex w-full cursor-pointer items-center gap-3 rounded-xl border p-3 text-left transition-colors",
                        isSelected
                          ? "border-accent-500 bg-accent-500/15"
                          : "border-separator-border bg-background-primary-default hover:border-border-button-hover",
                      )}
                    >
                      <span className="flex size-9 shrink-0 items-center justify-center rounded-2lg border border-separator-border bg-background-tertiary-default text-lg">
                        {ch.emoji}
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <span className="text-body-medium font-semibold text-text-primary">
                            {ch.name}
                          </span>
                          <span className="text-caption-1-regular text-text-secondary">
                            {ch.englishName}
                          </span>
                        </div>
                        <p className="truncate text-caption-1-regular text-text-secondary">
                          {ch.tagline}
                        </p>
                      </div>
                      {isSelected ? (
                        <RiCheckLine className="size-5 shrink-0 text-accent-50" aria-hidden="true" />
                      ) : null}
                    </button>
                  );
                })}
              </div>
            </div>
          </dialog>
        ) : null}

        {/* Library Modal (Favorites + Watch History, mirrored from DownloadsScreen) */}
        {isLibraryModalOpen ? (
          <dialog
            open
            aria-modal="true"
            aria-label="我的收藏與觀看紀錄"
            className="fixed inset-0 z-50 m-0 flex size-full max-h-none max-w-none items-end justify-center border-0 bg-black/75 p-3 backdrop-blur-xs sm:items-center"
            onClick={() => setIsLibraryModalOpen(false)}
          >
            <div
              className="flex max-h-[82vh] w-full max-w-lg flex-col rounded-3xl border border-border-button-default bg-background-secondary-default p-5 shadow-xl"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="mb-3 flex items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <RiHistoryLine className="size-5 text-accent-500" aria-hidden="true" />
                  <h2 className="text-title-3-semibold text-text-primary">收藏與觀看紀錄</h2>
                </div>
                <CloseButton onClick={() => setIsLibraryModalOpen(false)} aria-label="關閉收藏與紀錄視窗" />
              </div>

              <SegmentedControl
                aria-label="庫切換"
                selectedKeys={[libraryTab]}
                onSelectionChange={(keys) => {
                  const k = Array.from(keys)[0] as "favorites" | "history";
                  if (k) setLibraryTab(k);
                }}
                className="mb-4 w-full"
              >
                <SegmentedControlItem id="favorites" className="flex-1">
                  我的收藏 ({favorites.length})
                </SegmentedControlItem>
                <SegmentedControlItem id="history" className="flex-1">
                  觀看紀錄 ({historyEntries.length})
                </SegmentedControlItem>
              </SegmentedControl>

              <div className="flex-1 overflow-y-auto pr-1">
                {libraryTab === "favorites" ? (
                  favorites.length === 0 ? (
                    <p className="py-10 text-center text-body-2-regular text-text-secondary">
                      尚未加入任何收藏，點擊節目卡片愛心即可收藏。
                    </p>
                  ) : (
                    <div className="flex flex-col gap-2">
                      {favorites.map((fav) => (
                        <div
                          key={fav.id}
                          className="flex items-center justify-between gap-2 rounded-xl border border-separator-border bg-background-primary-default p-3"
                        >
                          <button
                            type="button"
                            className="min-w-0 flex-1 cursor-pointer text-left"
                            onClick={() => {
                              setSelectedEpId(fav.id);
                              setPartIndex(0);
                              setIsLibraryModalOpen(false);
                              setIsPlayerCollapsed(false);
                            }}
                          >
                            <div className="line-clamp-1 text-body-2-medium text-text-primary">
                              {fav.title}
                            </div>
                            <div className="text-caption-1-regular tabular-nums text-text-secondary">
                              {fav.date}
                            </div>
                          </button>
                          <IconButton
                            size="small"
                            icon={RiCloseLine}
                            aria-label="移除收藏"
                            onClick={() => handleToggleFavorite(fav)}
                          />
                        </div>
                      ))}
                    </div>
                  )
                ) : historyEntries.length === 0 ? (
                  <p className="py-10 text-center text-body-2-regular text-text-secondary">
                    尚無觀看紀錄，開始播放後將自動儲存進度。
                  </p>
                ) : (
                  <div className="flex flex-col gap-2">
                    {historyEntries.map((rec) => (
                      <div
                        key={rec.episodeId + rec.partIndex}
                        className="flex items-center justify-between gap-2 rounded-xl border border-separator-border bg-background-primary-default p-3"
                      >
                        <div className="min-w-0 flex-1">
                          <div className="line-clamp-1 text-body-2-medium text-text-primary">
                            {rec.title || rec.episodeId}
                          </div>
                          <div className="text-caption-1-regular tabular-nums text-text-secondary">
                            {rec.partLabel || `Part ${rec.partIndex + 1}`} · {formatSeconds(rec.currentTime)} / {formatSeconds(rec.duration)} ({rec.percentage}%)
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </dialog>
        ) : null}

        {/* Download Confirmation Modal (prompts multi-part download count & per-part controls) */}
        {downloadTargetEp ? (
          <dialog
            open
            aria-modal="true"
            aria-label="下載集數確認"
            className="fixed inset-0 z-50 m-0 flex size-full max-h-none max-w-none items-end justify-center border-0 bg-black/75 p-3 backdrop-blur-xs sm:items-center"
            onClick={() => setDownloadTargetEp(null)}
          >
            <div
              className="w-full max-w-md rounded-3xl border border-border-button-default bg-background-secondary-default p-5 shadow-xl"
              onClick={(e) => e.stopPropagation()}
            >
              {(() => {
                const targetParts = downloadTargetEp.parts?.length ? downloadTargetEp.parts : [];
                const partCount = targetParts.length;
                const partLabels = targetParts.map((p, i) => p.label || `Part ${i + 1}`).join("、");
                const isAnyResolving = Object.values(partResolveStates).some((s) => s === "resolving");
                const allStarted = partCount > 0 && targetParts.every((_, idx) => partDownloadStarted[idx]);

                return (
                  <>
                    <div className="mb-3 flex items-start justify-between gap-2">
                      <div className="flex items-center gap-2.5">
                        <div className="flex size-9 shrink-0 items-center justify-center rounded-2lg border border-accent-500/35 bg-accent-500/15 text-accent-500">
                          <RiDownloadLine className="size-4.5" aria-hidden="true" />
                        </div>
                        <div className="min-w-0">
                          <h2 className="text-title-3-semibold text-text-primary">
                            下載整集影片（共 {partCount} 個分段）
                          </h2>
                          <p className="line-clamp-1 text-caption-1-regular text-text-secondary">
                            {downloadTargetEp.title}
                          </p>
                        </div>
                      </div>
                      <CloseButton
                        onClick={() => setDownloadTargetEp(null)}
                        aria-label="關閉下載確認視窗"
                      />
                    </div>

                    <div className="mb-3 flex items-start gap-2.5 rounded-2xl border border-accent-500/35 bg-accent-500/10 p-3">
                      <RiInformationLine
                        className="mt-0.5 size-4 shrink-0 text-accent-500"
                        aria-hidden="true"
                      />
                      <div className="flex flex-col gap-1 text-start">
                        <p className="text-body-2-medium text-text-primary">
                          將會下載 {partCount} 個影片分段{partLabels ? `（${partLabels}）` : ""}
                        </p>
                        <p className="text-caption-1-regular text-text-secondary">
                          {partCount > 1
                            ? `點擊下方「確認下載全部」將依序下載這 ${partCount} 個 MP4 影片檔；若瀏覽器提示允許下載多個檔案，請選擇「允許」。`
                            : "點擊下方「確認下載」即可透過串流代理下載完整影片檔。"}
                        </p>
                      </div>
                    </div>

                    {downloadBackendUnavailable ? (
                      <div className="mb-3 flex items-start gap-2 rounded-xl border border-border-error-default bg-background-primary-default p-3 text-start">
                        <RiErrorWarningLine
                          className="mt-0.5 size-4 shrink-0 text-text-error-primary"
                          aria-hidden="true"
                        />
                        <p className="text-caption-1-regular text-text-error-primary">
                          偵測不到 `/api/stream` 下載代理服務（純靜態伺服器環境不支援跨域影片下載代理）。請使用 `npm run dev` 或部署至 Cloudflare Pages。
                        </p>
                      </div>
                    ) : null}

                    {downloadModalNotice ? (
                      <div
                        role="status"
                        className="mb-3 flex items-start gap-2 rounded-xl border border-separator-border bg-background-primary-default p-3 text-start"
                      >
                        <RiCheckLine
                          className="mt-0.5 size-4 shrink-0 text-accent-500"
                          aria-hidden="true"
                        />
                        <p className="text-caption-1-regular text-text-primary">
                          {downloadModalNotice}
                        </p>
                      </div>
                    ) : null}

                    <div className="mb-4 flex max-h-60 flex-col gap-2 overflow-y-auto">
                      {targetParts.map((part, idx) => {
                        const filename = getDownloadFilename(downloadTargetEp, idx);
                        const resolveState = partResolveStates[idx] || "idle";
                        const started = Boolean(partDownloadStarted[idx]);
                        const canDownload = Boolean(
                          buildPartDownloadHref(part, filename, resolvedDownloadUrls[idx]),
                        );

                        return (
                          <div
                            key={(part.label || idx) + String(idx)}
                            className="flex items-center justify-between gap-2.5 rounded-xl border border-separator-border bg-background-primary-default p-3"
                          >
                            <div className="min-w-0 flex-1 text-start">
                              <div className="flex items-center gap-2">
                                <span className="text-body-2-medium font-semibold text-text-primary">
                                  {part.label || `Part ${idx + 1}`}
                                </span>
                                {part.duration ? (
                                  <span className="text-caption-1-regular tabular-nums text-text-secondary">
                                    {part.duration}
                                  </span>
                                ) : null}
                                {started ? (
                                  <Chip variant="caption" color="lime">
                                    已開始下載
                                  </Chip>
                                ) : resolveState === "resolving" ? (
                                  <span className="inline-flex items-center gap-1 text-caption-1-regular text-text-secondary">
                                    <Spinner size="xs" aria-hidden />
                                    準備中
                                  </span>
                                ) : resolveState === "error" ? (
                                  <Chip variant="caption" color="rose">
                                    代理無法使用
                                  </Chip>
                                ) : null}
                              </div>
                              <p
                                title={filename}
                                className="truncate font-mono text-caption-1-regular text-text-secondary"
                              >
                                {filename}
                              </p>
                            </div>

                            <Button
                              variant="secondary"
                              size="xs"
                              leadingIcon={started ? RiCheckLine : RiDownloadLine}
                              disabled={!canDownload}
                              onClick={() => {
                                const ok = handleDownloadPart(downloadTargetEp, idx);
                                if (ok) {
                                  setStatusMessage(`已開始下載 ${part.label || `Part ${idx + 1}`}`);
                                }
                              }}
                            >
                              {started ? "再試" : "下載"}
                            </Button>
                          </div>
                        );
                      })}
                    </div>

                    <Divider className="my-3" />

                    <div className="flex flex-wrap items-center justify-end gap-2">
                      <Button
                        variant="secondary"
                        size="small"
                        onClick={() => setDownloadTargetEp(null)}
                      >
                        {allStarted ? "完成" : "取消"}
                      </Button>
                      <Button
                        variant="primary"
                        size="small"
                        leadingIcon={RiDownloadLine}
                        disabled={partCount === 0 || downloadBackendUnavailable}
                        onClick={() => handleConfirmDownloadAll(downloadTargetEp)}
                      >
                        {isAnyResolving
                          ? `確認下載全部 (${partCount} 個分段)...`
                          : allStarted
                            ? `重新下載全部 (${partCount} 個分段)`
                            : `確認下載全部 (${partCount} 個分段)`}
                      </Button>
                    </div>
                  </>
                );
              })()}
            </div>
          </dialog>
        ) : null}

        {/* Share Dialog Modal (triggered from Top Header Share button) */}
        {isShareModalOpen ? (
          <dialog
            open
            aria-modal="true"
            aria-label="分享節目影片"
            className="fixed inset-0 z-50 m-0 flex size-full max-h-none max-w-none items-end justify-center border-0 bg-black/75 p-3 backdrop-blur-xs sm:items-center"
            onClick={() => setIsShareModalOpen(false)}
          >
            <div
              className="w-full max-w-md rounded-3xl border border-border-button-default bg-background-secondary-default p-5 shadow-xl"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="mb-3 flex items-start justify-between gap-2">
                <div className="flex items-center gap-2.5">
                  <div className="flex size-9 items-center justify-center rounded-2lg border border-accent-500/35 bg-accent-500/15 text-accent-500">
                    <RiShareForwardLine className="size-4.5" aria-hidden="true" />
                  </div>
                  <div className="min-w-0">
                    <h2 className="line-clamp-1 text-title-3-semibold text-text-primary">
                      {activeEp.title}
                    </h2>
                    <p className="text-caption-1-regular text-text-secondary">
                      {activePart.label} · 複製連結即開即播
                    </p>
                  </div>
                </div>
                <CloseButton onClick={() => setIsShareModalOpen(false)} aria-label="關閉分享視窗" />
              </div>

              <Divider className="my-3" />

              <div className="flex items-center gap-2">
                <input
                  type="text"
                  readOnly
                  value={shareUrl}
                  aria-label="分享連結網址"
                  className="min-w-0 flex-1 rounded-2lg border border-border-button-default bg-background-tertiary-default px-3 py-2 font-mono text-caption-1-regular text-text-primary outline-none focus-visible:ring-2 focus-visible:ring-border-focus-ring"
                />
                <Button
                  variant="primary"
                  size="small"
                  leadingIcon={RiFileCopyLine}
                  onClick={() => void handleCopyShareUrl()}
                >
                  {copiedShareUrl ? "已複製！" : "複製"}
                </Button>
              </div>

              <div className="mt-4 flex justify-end">
                <LinkButton
                  href={LATEST_APK_RELEASE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  variant="secondary"
                  size="xs"
                  trailingIcon={RiExternalLinkLine}
                >
                  下載最新 Android APK
                </LinkButton>
              </div>
            </div>
          </dialog>
        ) : null}
      </div>
    </DirectionProvider>
  );
}

export { App };

const rootEl = document.getElementById("root");
if (rootEl) {
  createRoot(rootEl).render(<App />);
}
