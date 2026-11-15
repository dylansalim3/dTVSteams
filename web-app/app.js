// dTVStream YouTube-Style Web Controller with LocalStorage Playback Resume
let catalog = { updatedAt: "", episodes: [] };
let filteredEpisodes = [];
let activeEpisode = null;
let activePartIndex = 0;
let player = null;
let pendingSeekTime = 0;
let lastSaveTime = 0;
let toastTimeout = null;

const STORAGE_KEY = "dtv_resume_history";

// DOM Elements
const isBrowser = typeof document !== "undefined";
const searchInput = isBrowser ? document.getElementById("q") : null;
const searchClearBtn = isBrowser ? document.getElementById("search-clear-btn") : null;
const catalogStatus = isBrowser ? document.getElementById("catalog-status") : null;
const refreshBtn = isBrowser ? document.getElementById("refresh-btn") : null;

const playerTitle = isBrowser ? document.getElementById("player-title") : null;
const openSourceBtn = isBrowser ? document.getElementById("open-source-btn") : null;
const playerPartBadge = isBrowser ? document.getElementById("player-part-badge") : null;
const playerDateBadge = isBrowser ? document.getElementById("player-date-badge") : null;
const playerStreamStatus = isBrowser ? document.getElementById("player-stream-status") : null;
const playerPartsNav = isBrowser ? document.getElementById("player-parts-nav") : null;
const playerResumeToast = isBrowser ? document.getElementById("player-resume-toast") : null;

const episodesGrid = isBrowser ? document.getElementById("episodes-grid") : null;
const episodeCountBadge = isBrowser ? document.getElementById("episode-count-badge") : null;

// Helper: Format seconds to MM:SS or HH:MM:SS
function formatTime(seconds) {
  if (isNaN(seconds) || seconds < 0) return "00:00";
  const s = Math.floor(seconds);
  const hrs = Math.floor(s / 3600);
  const mins = Math.floor((s % 3600) / 60);
  const secs = s % 60;
  if (hrs > 0) {
    return `${hrs}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  }
  return `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
}

// LocalStorage Persistence Helpers
function getResumeHistory() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch (err) {
    console.warn("Failed to read resume history from localStorage:", err);
    return {};
  }
}

function saveResume(episodeId, partIndex, currentTime, duration) {
  if (!episodeId || !duration || isNaN(currentTime) || currentTime < 3) return;
  const history = getResumeHistory();
  const completed = currentTime >= duration - 15;
  const record = {
    episodeId,
    partIndex,
    currentTime: Math.round(currentTime),
    duration: Math.round(duration),
    percentage: Math.min(100, Math.round((currentTime / duration) * 100)),
    completed,
    updatedAt: Date.now()
  };
  history[episodeId] = record;

  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(history));
  } catch (err) {
    console.warn("Failed to write resume history to localStorage:", err);
  }

  updateCardResume(episodeId, record);
}

function getEpisodeResume(episodeId) {
  if (!episodeId) return null;
  return getResumeHistory()[episodeId] || null;
}

function clearEpisodeResume(episodeId) {
  if (!episodeId) return;
  const history = getResumeHistory();
  delete history[episodeId];
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(history));
  } catch (err) {}
  updateCardResume(episodeId, null);
}

// Show Resume Toast
function showResumeToast(partIndex, seekTime) {
  if (!playerResumeToast) return;
  clearTimeout(toastTimeout);

  playerResumeToast.innerHTML = `
    <span>⏱️ 已為您恢復至上次播放進度：Part ${partIndex + 1} (${formatTime(seekTime)})</span>
    <button id="restart-playback-btn" aria-label="從頭播放">從頭播放</button>
  `;
  playerResumeToast.style.display = "flex";

  const restartBtn = document.getElementById("restart-playback-btn");
  if (restartBtn) {
    restartBtn.onclick = () => {
      if (player) {
        player.currentTime = 0;
        player.play().catch(() => {});
      }
      if (activeEpisode) {
        clearEpisodeResume(activeEpisode.id);
      }
      hideResumeToast();
    };
  }

  toastTimeout = setTimeout(() => {
    hideResumeToast();
  }, 9000);
}

function hideResumeToast() {
  if (playerResumeToast) {
    playerResumeToast.style.display = "none";
  }
}

// Update card thumbnail progress bar and resume label
function updateCardResume(episodeId, record) {
  const card = document.querySelector(`.yt-card[data-id="${episodeId}"]`);
  if (!card) return;

  const thumbWrapper = card.querySelector(".yt-thumb-wrapper");
  const cardBody = card.querySelector(".yt-card-body");
  if (!thumbWrapper || !cardBody) return;

  let progressBar = thumbWrapper.querySelector(".yt-thumb-progress");
  let resumeMeta = cardBody.querySelector(".yt-card-resume-meta");

  if (!record || record.percentage <= 0) {
    if (progressBar) progressBar.remove();
    if (resumeMeta) resumeMeta.remove();
    return;
  }

  if (!progressBar) {
    progressBar = document.createElement("div");
    progressBar.className = "yt-thumb-progress";
    thumbWrapper.appendChild(progressBar);
  }
  progressBar.style.width = `${record.percentage}%`;

  if (!resumeMeta) {
    resumeMeta = document.createElement("div");
    resumeMeta.className = "yt-card-resume-meta";
    const titleEl = cardBody.querySelector(".yt-card-title");
    if (titleEl && titleEl.nextSibling) {
      cardBody.insertBefore(resumeMeta, titleEl.nextSibling);
    } else {
      cardBody.appendChild(resumeMeta);
    }
  }

  if (record.completed) {
    resumeMeta.innerHTML = `<span class="yt-card-watched-badge">✓ 已看完</span>`;
  } else {
    resumeMeta.innerHTML = `<span class="yt-card-resume-text">上次看至 Part ${record.partIndex + 1} (${formatTime(record.currentTime)})</span>`;
  }
}

// Initialize Native HTML5 Video Player with Resume Tracking & Auto-advance
function initPlayer() {
  const el = document.getElementById("main-player");
  if (!el) {
    console.warn("Main player element not found");
    return;
  }
  player = el;

  try {
    player.addEventListener("playing", () => {
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：播放中 (1080p HD)";
      // Check if we need to apply pending seek from localStorage resume
      if (pendingSeekTime > 0) {
        const target = pendingSeekTime;
        pendingSeekTime = 0;
        player.currentTime = target;
        showResumeToast(activePartIndex, target);
      }
    });

    player.addEventListener("loadedmetadata", () => {
      if (pendingSeekTime > 0 && player.duration > 0) {
        const target = Math.min(pendingSeekTime, player.duration - 2);
        pendingSeekTime = 0;
        player.currentTime = target;
        showResumeToast(activePartIndex, target);
      }
    });

    // Save resume position periodically (every 2 seconds)
    player.addEventListener("timeupdate", () => {
      const now = Date.now();
      if (now - lastSaveTime > 2000) {
        lastSaveTime = now;
        if (activeEpisode && player && !player.paused) {
          saveResume(activeEpisode.id, activePartIndex, player.currentTime, player.duration);
        }
      }
    });

    player.addEventListener("pause", () => {
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：已暫停";
      if (activeEpisode && player) {
        saveResume(activeEpisode.id, activePartIndex, player.currentTime, player.duration);
      }
    });

    player.addEventListener("waiting", () => {
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：緩衝載入中...";
    });

    // Auto-advance to next part when current part finishes
    player.addEventListener("ended", () => {
      if (activeEpisode) {
        // Mark current part completed
        saveResume(activeEpisode.id, activePartIndex, player.duration, player.duration);
      }

      if (activeEpisode && activeEpisode.parts && activePartIndex < activeEpisode.parts.length - 1) {
        if (playerStreamStatus) playerStreamStatus.textContent = `播放完成，即將自動播放 Part ${activePartIndex + 2}...`;
        setTimeout(() => {
          playPart(activeEpisode, activePartIndex + 1, true, true);
        }, 1200);
      } else {
        if (playerStreamStatus) playerStreamStatus.textContent = "全集播放完畢";
      }
    });

    // Handle stream playback error with automatic fresh token retry
    player.addEventListener("error", () => {
      console.warn("Video playback error:", player.error);
      const currentPart = activeEpisode?.parts?.[activePartIndex];
      if (currentPart?.url && window.location.protocol.startsWith("http")) {
        if (playerStreamStatus) playerStreamStatus.textContent = "串流重新獲取最新線路...";
        const freshStream = `/api/stream?pageUrl=${encodeURIComponent(currentPart.url)}&refresh=true`;
        player.src = freshStream;
        try { player.load(); } catch (_) {}
        player.play().catch(() => {});
        return;
      }
      if (playerStreamStatus) playerStreamStatus.textContent = "串流線路異常，請重新選擇集數";
    });

    // Save on tab close
    window.addEventListener("beforeunload", () => {
      if (activeEpisode && player) {
        saveResume(activeEpisode.id, activePartIndex, player.currentTime, player.duration);
      }
    });
  } catch (e) {
    console.error("Failed to initialize player:", e);
  }
}

// Format stream URL through range proxy for reliable CORS & Byte-Range delivery with live token resolution
function resolveStreamUrl(part) {
  if (!part) return "./media/sample-part1.mp4";
  const pageUrl = part.url || "";
  let streamUrl = part.streamUrl || "";
  if (streamUrl.includes("sample-part")) {
    streamUrl = "";
  }
  if (window.location.protocol.startsWith("http")) {
    const params = new URLSearchParams();
    if (streamUrl) params.set("url", streamUrl);
    if (pageUrl) params.set("pageUrl", pageUrl);
    return `/api/stream?${params.toString()}`;
  }
  return streamUrl || part.fallbackStreamUrl || "./media/sample-part1.mp4";
}

// Play a specific episode part, supporting localStorage resume
function playPart(episode, partIndex = 0, autoPlay = true, fromExplicitPartClick = false) {
  if (!episode || !episode.parts || !episode.parts.length) return;
  activeEpisode = episode;
  hideResumeToast();

  // If clicked episode card without specifying a part, check localStorage resume point
  if (!fromExplicitPartClick) {
    const saved = getEpisodeResume(episode.id);
    if (saved && saved.currentTime > 5 && !saved.completed) {
      if (saved.partIndex >= 0 && saved.partIndex < episode.parts.length) {
        partIndex = saved.partIndex;
        pendingSeekTime = saved.currentTime;
      }
    } else {
      pendingSeekTime = 0;
    }
  } else {
    // If clicked a specific part button, check if that specific part was played
    const saved = getEpisodeResume(episode.id);
    if (saved && saved.partIndex === partIndex && saved.currentTime > 5 && !saved.completed) {
      pendingSeekTime = saved.currentTime;
    } else {
      pendingSeekTime = 0;
    }
  }

  activePartIndex = Math.max(0, Math.min(partIndex, episode.parts.length - 1));
  const part = episode.parts[activePartIndex];
  const streamUrl = resolveStreamUrl(part);

  // Update Player Header & Details
  if (playerTitle) playerTitle.textContent = episode.title || "綜藝玩很大";
  if (playerPartBadge) playerPartBadge.textContent = part.label || `Part ${activePartIndex + 1}`;
  if (playerDateBadge) playerDateBadge.textContent = episode.date || "最新";
  if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：連線中...";

  if (openSourceBtn) {
    openSourceBtn.onclick = () => {
      window.open(part.url || episode.url, "_blank", "noopener,noreferrer");
    };
  }

  // Render Part Selector Chips Under Player
  renderPlayerParts(episode, activePartIndex);

  // Update Active Card in Grid
  highlightActiveCard(episode.id);

  // Load Source into Native Player
  if (player) {
    player.src = streamUrl;
    try { player.load(); } catch (_) {}

    if (autoPlay) {
      const playPromise = player.play();
      if (playPromise !== undefined) {
        playPromise.catch((err) => {
          console.log("Autoplay waiting for user tap:", err);
          if (playerStreamStatus) playerStreamStatus.textContent = "串流已就緒，請點擊播放";
        });
      }
    }
  }
}

// Render Part Selector Chips Under Player
function renderPlayerParts(episode, activeIdx) {
  if (!playerPartsNav) return;
  playerPartsNav.innerHTML = "";

  (episode.parts || []).forEach((part, idx) => {
    const chip = document.createElement("button");
    chip.className = `yt-part-chip ${idx === activeIdx ? "active" : ""}`;
    chip.textContent = `${part.label || "Part " + (idx + 1)} · ${part.duration || "35分"}`;
    chip.setAttribute("aria-label", `播放 ${part.label || "Part " + (idx + 1)}`);
    chip.onclick = () => playPart(episode, idx, true, true);
    playerPartsNav.appendChild(chip);
  });
}

// Highlight currently playing card in grid
function highlightActiveCard(episodeId) {
  document.querySelectorAll(".yt-card").forEach((card) => {
    if (card.getAttribute("data-id") === episodeId) {
      card.classList.add("active-episode");
    } else {
      card.classList.remove("active-episode");
    }
  });
}

// Resolve reliable episode thumbnail, avoiding broken 404s and generic placeholders
function resolveEpisodeThumb(ep) {
  if (ep.poster && !ep.poster.includes("tmdb.org") && !ep.poster.includes("preview.png")) return ep.poster;
  if (ep.backdrop && !ep.backdrop.includes("tmdb.org") && !ep.backdrop.includes("preview.png")) return ep.backdrop;
  const dateSlug = (ep.date || "").replace(/-/g, "");
  if (dateSlug) {
    return `./media/thumbnails/ep-${dateSlug}.svg`;
  }
  return `./media/thumb-default.svg`;
}

// Render Episode Grid (Simple YouTube-style list, No fake recommendations)
function renderGrid(list) {
  if (!episodesGrid) return;
  episodesGrid.innerHTML = "";

  if (episodeCountBadge) {
    episodeCountBadge.textContent = `共 ${list.length} 集`;
  }

  if (!list.length) {
    episodesGrid.innerHTML = `
      <div style="grid-column: 1 / -1; text-align: center; padding: 3rem; color: var(--yt-text-secondary);">
        <p style="font-size: 1.1rem; margin-bottom: 0.5rem;">查無符合的集數</p>
        <p style="font-size: 0.9rem;">請嘗試不同關鍵字或清空搜尋條件</p>
      </div>
    `;
    return;
  }

  list.forEach((ep) => {
    const card = document.createElement("article");
    card.className = "yt-card";
    card.setAttribute("data-id", ep.id);
    card.tabIndex = 0;

    const thumb = resolveEpisodeThumb(ep);
    const totalParts = ep.parts?.length || 3;
    const resume = getEpisodeResume(ep.id);

    const progressBarHtml = resume && resume.percentage > 0
      ? `<div class="yt-thumb-progress" style="width: ${resume.percentage}%;"></div>`
      : "";

    const resumeMetaHtml = resume && resume.percentage > 0
      ? `<div class="yt-card-resume-meta">
           ${resume.completed
             ? `<span class="yt-card-watched-badge">✓ 已看完</span>`
             : `<span class="yt-card-resume-text">上次看至 Part ${resume.partIndex + 1} (${formatTime(resume.currentTime)})</span>`
           }
         </div>`
      : "";

    card.innerHTML = `
      <div class="yt-thumb-wrapper">
        <img class="yt-thumb-img" src="${thumb}" alt="${ep.title}" loading="lazy" onerror="this.src='./media/thumb-default.svg'">
        <span class="yt-thumb-badge">${ep.duration || "1小時 48分"}</span>
        ${progressBarHtml}
      </div>
      <div class="yt-card-body">
        <h3 class="yt-card-title">${ep.title}</h3>
        ${resumeMetaHtml}
        <div class="yt-card-meta">${ep.date} · 綜藝玩很大 · 共 ${totalParts} 個分段</div>
        <div class="yt-card-parts" role="group" aria-label="分段播放">
          ${(ep.parts || []).map((part, pIdx) => `
            <button class="yt-card-part-btn" data-part="${pIdx}" aria-label="播放 ${part.label || 'Part ' + (pIdx + 1)}">
              ▶ ${part.label || 'Part ' + (pIdx + 1)}
            </button>
          `).join("")}
        </div>
      </div>
    `;

    // Replace the poster with the real middle frame of Part 1 when possible.
    const thumbImg = card.querySelector(".yt-thumb-img");
    const partOne = ep.parts?.[0];
    if (thumbImg && partOne && window.DTVFrameThumbs) {
      window.DTVFrameThumbs.attach(ep.id, thumbImg, resolveStreamUrl(partOne));
    }

    // Click whole card to play (uses resume if available) & scroll to player
    card.addEventListener("click", (e) => {
      const partBtn = e.target.closest(".yt-card-part-btn");
      if (partBtn) {
        const pIdx = parseInt(partBtn.getAttribute("data-part") || "0", 10);
        playPart(ep, pIdx, true, true);
      } else {
        playPart(ep, 0, true, false);
      }
      window.scrollTo({ top: 0, behavior: "smooth" });
    });

    // Keyboard Enter on card
    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.target.classList.contains("yt-card-part-btn")) {
        playPart(ep, 0, true, false);
        window.scrollTo({ top: 0, behavior: "smooth" });
      }
    });

    episodesGrid.appendChild(card);
  });

  if (activeEpisode) {
    highlightActiveCard(activeEpisode.id);
  }
}

// Live Search Filter
function handleSearch() {
  const query = (searchInput?.value || "").trim().toLowerCase();
  if (searchClearBtn) {
    searchClearBtn.style.display = query.length > 0 ? "block" : "none";
  }

  if (!query) {
    filteredEpisodes = [...catalog.episodes];
  } else {
    filteredEpisodes = catalog.episodes.filter((ep) => {
      const title = (ep.title || "").toLowerCase();
      const date = (ep.date || "").toLowerCase();
      const overview = (ep.overview || "").toLowerCase();
      const tags = (ep.tags || []).join(" ").toLowerCase();
      return title.includes(query) || date.includes(query) || overview.includes(query) || tags.includes(query);
    });
  }

  renderGrid(filteredEpisodes);
}

// Load Catalog Data
async function loadCatalog() {
  if (catalogStatus) catalogStatus.textContent = "更新中...";

  try {
    const res = await fetch(`./catalog.json?_t=${Date.now()}`, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    catalog = await res.json();
    if (!catalog.episodes || !catalog.episodes.length) throw new Error("影片清單為空");
  } catch (err) {
    console.warn("Using offline fallback catalog:", err);
    catalog = {
      updatedAt: new Date().toISOString(),
      episodes: [
        {
          id: "https://srgoideas.com/ep1/",
          title: "綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家",
          date: "2026-11-08",
          url: "https://srgoideas.com/ep1/",
          duration: "1小時 48分",
          overview: "最新台北外景！搗蛋鬼到你家爆笑任務連發！",
          backdrop: "./media/thumbnails/ep-20261108.svg",
          poster: "./media/thumbnails/ep-20261108.svg",
          parts: [
            { label: "Part 1", streamUrl: "./media/sample-part1.mp4", duration: "35分" },
            { label: "Part 2", streamUrl: "./media/sample-part2.mp4", duration: "35分" },
            { label: "Part 3", streamUrl: "./media/sample-part3.mp4", duration: "35分" }
          ]
        }
      ]
    };
  }

  filteredEpisodes = [...catalog.episodes];
  if (catalogStatus) catalogStatus.textContent = `已同步 (${catalog.episodes.length} 集)`;

  renderGrid(filteredEpisodes);

  // Stage first episode (with resume check)
  if (catalog.episodes.length > 0) {
    playPart(catalog.episodes[0], 0, false, false);
  }

  // Bind Load More button
  const loadMoreBtn = document.getElementById("load-more-btn");
  if (loadMoreBtn) {
    loadMoreBtn.onclick = () => loadNextPage();
  }
}

let currentCatalogPage = 1;
const TOTAL_SOURCE_PAGES = 64;

async function loadNextPage() {
  if (currentCatalogPage >= TOTAL_SOURCE_PAGES) return;
  const loadMoreBtn = document.getElementById("load-more-btn");
  const loadMoreText = document.getElementById("load-more-text");
  const paginationInfo = document.getElementById("pagination-info");

  if (loadMoreBtn) loadMoreBtn.disabled = true;
  if (loadMoreText) loadMoreText.textContent = "載入中...";

  const nextPage = currentCatalogPage + 1;
  try {
    const res = await fetch(`/api/episodes?page=${nextPage}`);
    if (!res.ok) throw new Error("HTTP " + res.status);
    const data = await res.json();
    if (!data.ok || !data.episodes || !data.episodes.length) throw new Error("無更多集數");

    const seen = new Set(catalog.episodes.map(e => e.id));
    const newItems = data.episodes.filter(e => !seen.has(e.id));
    catalog.episodes.push(...newItems);
    filteredEpisodes = [...catalog.episodes];
    currentCatalogPage = nextPage;

    renderGrid(filteredEpisodes);

    if (loadMoreText) {
      if (currentCatalogPage >= TOTAL_SOURCE_PAGES) {
        loadMoreText.textContent = "已載入全劇所有集數";
        if (loadMoreBtn) loadMoreBtn.style.display = "none";
      } else {
        loadMoreText.textContent = `載入更多歷史集數 (第 ${currentCatalogPage + 1} 頁 / 共 ${TOTAL_SOURCE_PAGES} 頁)`;
      }
    }
    if (paginationInfo) {
      paginationInfo.textContent = `已顯示 ${catalog.episodes.length} 集 / 全劇 640+ 集`;
    }
  } catch (err) {
    console.error("載入下一頁失敗:", err);
    if (loadMoreText) loadMoreText.textContent = `載入失敗，點擊重試 (第 ${nextPage} 頁)`;
  } finally {
    if (loadMoreBtn) loadMoreBtn.disabled = false;
  }
}

// Global Keyboard Shortcuts (Remote / Desktop friendly)
function setupShortcuts() {
  window.addEventListener("keydown", (e) => {
    // Ignore when typing inside search input
    if (document.activeElement === searchInput) {
      if (e.key === "Escape") {
        searchInput.value = "";
        handleSearch();
        searchInput.blur();
      }
      return;
    }

    if (!player) return;

    switch (e.key) {
      case " ":
      case "k":
        e.preventDefault();
        if (player.paused) player.play().catch(() => {});
        else player.pause();
        break;

      case "ArrowLeft":
      case "j":
        e.preventDefault();
        player.currentTime = Math.max(0, player.currentTime - 10);
        break;

      case "ArrowRight":
      case "l":
        e.preventDefault();
        player.currentTime = Math.min(player.duration || 0, player.currentTime + 10);
        break;

      case "ArrowUp":
        e.preventDefault();
        player.volume = Math.min(1, player.volume + 0.1);
        break;

      case "ArrowDown":
        e.preventDefault();
        player.volume = Math.max(0, player.volume - 0.1);
        break;

      case "1":
        if (activeEpisode?.parts?.[0]) playPart(activeEpisode, 0, true, true);
        break;

      case "2":
        if (activeEpisode?.parts?.[1]) playPart(activeEpisode, 1, true, true);
        break;

      case "3":
        if (activeEpisode?.parts?.[2]) playPart(activeEpisode, 2, true, true);
        break;

      case "f":
      case "F":
        e.preventDefault();
        if (document.fullscreenElement) {
          if (document.exitFullscreen) document.exitFullscreen();
        } else {
          if (player.requestFullscreen) {
            player.requestFullscreen().catch(() => {});
          } else if (player.webkitEnterFullscreen) {
            player.webkitEnterFullscreen();
          }
        }
        break;

      case "m":
      case "M":
        e.preventDefault();
        player.muted = !player.muted;
        break;
    }
  });
}

// Event Bindings
if (searchInput) searchInput.addEventListener("input", handleSearch);

if (searchClearBtn) {
  searchClearBtn.addEventListener("click", () => {
    searchInput.value = "";
    handleSearch();
    searchInput.focus();
  });
}

if (refreshBtn) {
  refreshBtn.addEventListener("click", () => {
    loadCatalog();
  });
}

// Initialization on DOMContentLoaded
if (typeof window !== "undefined") {
  window.addEventListener("DOMContentLoaded", () => {
    initPlayer();
    setupShortcuts();
    loadCatalog();
  });
}

// Exports for testing & window exposure
if (typeof window !== "undefined") {
  window.loadCatalog = loadCatalog;
  window.playPart = playPart;
  window.renderGrid = renderGrid;
  window.handleSearch = handleSearch;
  window.resolveStreamUrl = resolveStreamUrl;
  window.saveResume = saveResume;
  window.getEpisodeResume = getEpisodeResume;
  window.clearEpisodeResume = clearEpisodeResume;
  window.formatTime = formatTime;
  window.loadNextPage = loadNextPage;
  window.STORAGE_KEY = STORAGE_KEY;
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    loadCatalog,
    loadNextPage,
    playPart,
    renderGrid,
    handleSearch,
    resolveStreamUrl,
    saveResume,
    getEpisodeResume,
    clearEpisodeResume,
    formatTime,
    STORAGE_KEY
  };
}
