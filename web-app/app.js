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
const downloadBtn = isBrowser ? document.getElementById("download-btn") : null;
const downloadMenu = isBrowser ? document.getElementById("download-menu") : null;
const shareBtn = isBrowser ? document.getElementById("share-btn") : null;
const shareModal = isBrowser ? document.getElementById("share-modal") : null;
const shareModalBackdrop = isBrowser ? document.getElementById("share-modal-backdrop") : null;
const shareModalClose = isBrowser ? document.getElementById("share-modal-close") : null;
const shareModalTitle = isBrowser ? document.getElementById("share-modal-title") : null;
const shareModalSubtitle = isBrowser ? document.getElementById("share-modal-subtitle") : null;
const shareQrContainer = isBrowser ? document.getElementById("share-qr-container") : null;
const shareUrlInput = isBrowser ? document.getElementById("share-url-input") : null;
const shareCopyBtn = isBrowser ? document.getElementById("share-copy-btn") : null;
const shareCopyText = isBrowser ? document.getElementById("share-copy-text") : null;
const shareNativeBtn = isBrowser ? document.getElementById("share-native-btn") : null;
const playerPartBadge = isBrowser ? document.getElementById("player-part-badge") : null;
const playerDateBadge = isBrowser ? document.getElementById("player-date-badge") : null;
const playerStreamStatus = isBrowser ? document.getElementById("player-stream-status") : null;
const playerPartsNav = isBrowser ? document.getElementById("player-parts-nav") : null;
const playerResumeToast = isBrowser ? document.getElementById("player-resume-toast") : null;

// Auto-Play Next Part/Episode State
let autoPlayNextEnabled = typeof localStorage !== "undefined" ? localStorage.getItem("dtv_autoplay_next") !== "false" : true;
let autoPlayTimer = null;
let autoPlayCountdown = 5;
let autoPlayDismissed = false;

// Year Filter & Chronological Sort & Search History State (Feature 10)
let selectedYear = "all";
let isSortAscending = false;
const SEARCH_HISTORY_KEY = "dtv_search_history";
const DEFAULT_HOT_TAGS = ['憲哥', 'KID', '澎湖', '飢餓遊戲', '金鐘', '日本', '週年', '黃隊'];

// Audio-Only Radio Mode State (Feature 11)
let isAudioOnlyMode = false;

// Skip Intro & Stall Fallback State (Feature 12)
let skipIntroDismissed = false;
let stallWatchdogTimer = null;
let stallHudVisible = false;

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
  const ep = (activeEpisode && activeEpisode.id === episodeId)
    ? activeEpisode
    : (catalog?.episodes ? catalog.episodes.find(e => e.id === episodeId) : null);
  const partIdx = partIndex || 0;
  const record = {
    episodeId,
    partIndex: partIdx,
    currentTime: Math.round(currentTime),
    duration: Math.round(duration),
    percentage: Math.min(100, Math.round((currentTime / duration) * 100)),
    completed,
    updatedAt: Date.now(),
    title: ep ? ep.title : (history[episodeId]?.title || episodeId),
    thumbnail: ep ? (ep.thumbnail || ep.backdrop || ep.poster || "") : (history[episodeId]?.thumbnail || ""),
    showName: ep ? (ep.showName || "綜藝玩很大") : (history[episodeId]?.showName || "綜藝玩很大"),
    partLabel: (ep && ep.parts && ep.parts[partIdx]) ? ep.parts[partIdx].label : `Part ${partIdx + 1}`
  };
  history[episodeId] = record;

  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(history));
  } catch (err) {
    console.warn("Failed to write resume history to localStorage:", err);
  }

  updateCardResume(episodeId, record);
  updateHistoryBadge();
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
  updateHistoryBadge();
}

function clearAllHistory() {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch (err) {}
  if (catalog && Array.isArray(catalog.episodes)) {
    catalog.episodes.forEach(ep => updateCardResume(ep.id, null));
  }
  updateHistoryBadge();
}

function getHistoryRecords() {
  const history = getResumeHistory();
  const list = Object.values(history);
  list.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
  return list;
}

function updateHistoryBadge() {
  if (typeof document === "undefined") return;
  const badge = document.getElementById("history-badge");
  if (!badge) return;
  const count = getHistoryRecords().length;
  if (count > 0) {
    badge.textContent = count > 99 ? "99+" : count;
    badge.style.display = "flex";
  } else {
    badge.style.display = "none";
  }
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

  const progressBarEl = card.querySelector(".yt-thumb-progress");
  const cardBody = card.querySelector(".yt-card-body");
  if (!cardBody) return;

  let progressBar = progressBarEl;
  let resumeMeta = cardBody.querySelector(".yt-card-resume-meta");

  if (!record || record.percentage <= 0) {
    if (progressBar) progressBar.remove();
    if (resumeMeta) resumeMeta.remove();
    return;
  }

  if (!progressBar) {
    progressBar = document.createElement("div");
    progressBar.className = "yt-thumb-progress";
    card.appendChild(progressBar);
  }
  progressBar.style.width = `${record.percentage}%`;

  if (!resumeMeta) {
    resumeMeta = document.createElement("div");
    resumeMeta.className = "yt-card-resume-meta";
    const metaWrap = cardBody.querySelector(".card-meta-wrap");
    if (metaWrap && metaWrap.nextSibling) {
      cardBody.insertBefore(resumeMeta, metaWrap.nextSibling);
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

// Playback Speed State & Preference
const SPEED_STORAGE_KEY = "dtv_playback_rate";
const SPEED_STEPS = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
let currentSpeed = 1.0;

function initPlaybackSpeed() {
  try {
    const saved = localStorage.getItem(SPEED_STORAGE_KEY);
    if (saved) {
      const parsed = parseFloat(saved);
      if (SPEED_STEPS.includes(parsed) || (parsed >= 0.5 && parsed <= 3.0)) {
        currentSpeed = parsed;
      }
    }
  } catch (_) {}
  applyPlaybackSpeed(currentSpeed, false);
  setupSpeedPicker();
}

function applyPlaybackSpeed(speed, notify = true) {
  currentSpeed = speed;
  try {
    localStorage.setItem(SPEED_STORAGE_KEY, String(speed));
  } catch (_) {}

  if (player) {
    player.playbackRate = speed;
  }

  const speedBadge = document.getElementById("player-speed-badge");
  if (speedBadge) {
    speedBadge.textContent = `⚡ ${speed}x`;
  }

  document.querySelectorAll(".yt-speed-chip").forEach((chip) => {
    const s = parseFloat(chip.getAttribute("data-speed") || "1");
    if (Math.abs(s - speed) < 0.01) {
      chip.classList.add("active");
    } else {
      chip.classList.remove("active");
    }
  });

  if (notify && playerStreamStatus) {
    const prev = playerStreamStatus.textContent;
    playerStreamStatus.textContent = `⚡ 播放速度已切換為 ${speed}x`;
    setTimeout(() => {
      if (playerStreamStatus && playerStreamStatus.textContent.includes("速度")) {
        playerStreamStatus.textContent = prev;
      }
    }, 2500);
  }
}

function cycleSpeed(direction = 1) {
  let idx = SPEED_STEPS.findIndex((s) => Math.abs(s - currentSpeed) < 0.01);
  if (idx === -1) idx = 1;
  let nextIdx = idx + direction;
  if (nextIdx < 0) nextIdx = 0;
  if (nextIdx >= SPEED_STEPS.length) nextIdx = SPEED_STEPS.length - 1;
  applyPlaybackSpeed(SPEED_STEPS[nextIdx], true);
}

function setupSpeedPicker() {
  document.querySelectorAll(".yt-speed-chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      const speed = parseFloat(chip.getAttribute("data-speed") || "1.0");
      applyPlaybackSpeed(speed, true);
    });
  });
}

// In-memory & session direct stream cache for instantaneous 0ms playback buffering
const clientStreamCache = new Map();

async function resolveDirectStream(pageUrl) {
  if (!pageUrl) return null;
  if (clientStreamCache.has(pageUrl)) {
    return clientStreamCache.get(pageUrl);
  }
  try {
    const sessionVal = sessionStorage.getItem("dtv_stream_" + pageUrl);
    if (sessionVal) {
      clientStreamCache.set(pageUrl, sessionVal);
      return sessionVal;
    }
  } catch (_) {}

  try {
    const res = await fetch(`/api/resolve-stream?url=${encodeURIComponent(pageUrl)}`);
    if (res.ok) {
      const data = await res.json();
      if (data && data.ok && data.streamUrl) {
        clientStreamCache.set(pageUrl, data.streamUrl);
        try { sessionStorage.setItem("dtv_stream_" + pageUrl, data.streamUrl); } catch (_) {}
        return data.streamUrl;
      }
    }
  } catch (_) {}
  return null;
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
      clearTimeout(stallWatchdogTimer);
      hideStallCard();
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：播放中";
      player.playbackRate = currentSpeed;
    });

    player.addEventListener("canplay", () => {
      clearTimeout(stallWatchdogTimer);
      hideStallCard();
    });

    player.addEventListener("seeking", () => {
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：跳轉緩衝中...";
    });

    player.addEventListener("seeked", () => {
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：播放中";
    });

    player.addEventListener("loadedmetadata", () => {
      player.playbackRate = currentSpeed;
      if (pendingSeekTime > 0) {
        const dur = player.duration || (pendingSeekTime + 10);
        const target = Math.min(pendingSeekTime, dur - 2);
        pendingSeekTime = 0;
        if (Math.abs(player.currentTime - target) > 1.5) {
          player.currentTime = target;
        }
        showResumeToast(activePartIndex, target);
      }
    });

    // Save resume position periodically (every 2 seconds) & trigger auto-play countdown
    player.addEventListener("timeupdate", () => {
      const now = Date.now();
      if (now - lastSaveTime > 2000) {
        lastSaveTime = now;
        if (activeEpisode && player && !player.paused) {
          saveResume(activeEpisode.id, activePartIndex, player.currentTime, player.duration);
        }
      }

      // Feature 12: Skip Intro pill display (0 - 60s)
      const skipIntroBtn = document.getElementById("skip-intro-btn");
      if (skipIntroBtn) {
        if (player.currentTime >= 0 && player.currentTime <= 60 && !player.paused && !skipIntroDismissed && !isScreenLocked) {
          skipIntroBtn.style.display = "inline-flex";
        } else {
          skipIntroBtn.style.display = "none";
        }
      }

      // Auto-play next part countdown 5.5s before end
      if (player && player.duration > 8 && !player.paused) {
        const remaining = player.duration - player.currentTime;
        if (remaining <= 5.5 && !autoPlayDismissed && !autoPlayTimer && autoPlayNextEnabled && !isScreenLocked) {
          startAutoPlayCountdown();
        } else if (remaining > 6.5 && autoPlayTimer) {
          cancelAutoPlay(false);
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
      clearTimeout(stallWatchdogTimer);
      stallWatchdogTimer = setTimeout(() => {
        if (player && !player.paused) {
          showStallCard();
        }
      }, 4500);
    });

    // Auto-advance to next part when current part finishes
    player.addEventListener("ended", () => {
      if (activeEpisode) {
        // Mark current part completed
        saveResume(activeEpisode.id, activePartIndex, player.duration, player.duration);
      }

      if (sleepTimerMode === "end") {
        setSleepTimer("0");
        showSleepToast("睡眠定時已到達（分段播放完畢），播放已暫停");
        return;
      }

      if (autoPlayNextEnabled && !isScreenLocked) {
        proceedAutoPlayNext();
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
  cancelAutoPlay(false);
  autoPlayDismissed = false;
  skipIntroDismissed = false;
  hideStallCard();

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
  // Check if we already cached the direct high-speed CDN stream
  const directCdnUrl = clientStreamCache.get(part.url);
  const streamUrl = directCdnUrl || resolveStreamUrl(part);

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

  // Update Audio-Only Radio Mode View (Feature 11)
  updateRadioView();

  // Load Source into Native Player with Speed Preservation and Media Fragment instant seeking
  if (player) {
    const mediaFragment = pendingSeekTime > 0 ? `#t=${Math.floor(pendingSeekTime)}` : "";
    player.src = streamUrl + mediaFragment;
    try { player.load(); } catch (_) {}
    player.playbackRate = currentSpeed;

    if (autoPlay) {
      const playPromise = player.play();
      if (playPromise !== undefined) {
        playPromise.catch((err) => {
          console.log("Autoplay waiting for user tap:", err);
          if (playerStreamStatus) playerStreamStatus.textContent = "串流已就緒，請點擊播放";
        });
      }
    }

    // Cache direct CDN stream in background without mutating active player.src
    if (!directCdnUrl && part.url && window.location.protocol.startsWith("http")) {
      resolveDirectStream(part.url).then((direct) => {
        if (direct) {
          clientStreamCache.set(part.url, direct);
        }
      });
    }

    // Pre-resolve next part in background for instant transition
    if (episode.parts && activePartIndex < episode.parts.length - 1) {
      const nextPart = episode.parts[activePartIndex + 1];
      if (nextPart?.url) resolveDirectStream(nextPart.url);
    }
  }
}

// Download Helper Functions
function getDownloadFilename(episode, partIndex = 0) {
  if (!episode) return "dtvstream_video.mp4";
  const showName = (episode.showName || "綜藝玩很大").replace(/[\/\\:*?"<>|]/g, "").trim();
  const date = (episode.date || "").replace(/[\/\\:*?"<>|]/g, "").trim();
  const rawTitle = (episode.title || "").replace(/[\/\\:*?"<>|]/g, "").trim();
  const part = episode.parts?.[partIndex];
  const partLabel = (part?.label || `Part ${partIndex + 1}`).replace(/[\/\\:*?"<>|]/g, "").trim();

  if (date) {
    return `${showName}_${date}_${partLabel}.mp4`;
  }
  return `${showName}_${rawTitle}_${partLabel}.mp4`;
}

async function downloadEpisodePart(episode, partIndex = 0) {
  if (!episode || !episode.parts || !episode.parts[partIndex]) return;
  const part = episode.parts[partIndex];
  const filename = getDownloadFilename(episode, partIndex);

  if (playerStreamStatus) {
    playerStreamStatus.textContent = `⏳ 正在準備下載 ${part.label || 'Part ' + (partIndex + 1)}...`;
  }

  try {
    let downloadHref = "";
    const directStream = await resolveDirectStream(part.url);
    if (directStream && !directStream.includes("sample-part")) {
      downloadHref = `/api/stream?url=${encodeURIComponent(directStream)}&download=true&filename=${encodeURIComponent(filename)}`;
    } else if (part.url) {
      downloadHref = `/api/stream?pageUrl=${encodeURIComponent(part.url)}&download=true&filename=${encodeURIComponent(filename)}`;
    } else if (part.fallbackStreamUrl) {
      downloadHref = part.fallbackStreamUrl;
    } else {
      downloadHref = "./media/sample-part1.mp4";
    }

    const a = document.createElement("a");
    a.href = downloadHref;
    a.download = filename;
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);

    if (playerStreamStatus) {
      playerStreamStatus.textContent = `✅ 已送出下載：${filename}`;
      setTimeout(() => {
        if (playerStreamStatus && playerStreamStatus.textContent.includes("已送出下載")) {
          playerStreamStatus.textContent = "串流狀態：準備中";
        }
      }, 4000);
    }
  } catch (err) {
    console.error("下載失敗:", err);
    if (playerStreamStatus) {
      playerStreamStatus.textContent = `❌ 下載失敗：${err.message || '無法下載'}`;
    }
  }
}

function renderDownloadMenu() {
  if (!downloadMenu || !activeEpisode) return;
  const parts = activeEpisode.parts || [];
  downloadMenu.innerHTML = "";

  const activePartBtn = document.createElement("button");
  activePartBtn.className = "yt-download-item";
  activePartBtn.setAttribute("role", "menuitem");
  activePartBtn.innerHTML = `
    <span class="yt-download-item-title">
      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
        <polyline points="7 10 12 15 17 10"/>
        <line x1="12" y1="15" x2="12" y2="3"/>
      </svg>
      <strong>下載目前分段 (${parts[activePartIndex]?.label || 'Part ' + (activePartIndex + 1)})</strong>
    </span>
  `;
  activePartBtn.onclick = () => {
    downloadMenu.style.display = "none";
    downloadEpisodePart(activeEpisode, activePartIndex);
  };
  downloadMenu.appendChild(activePartBtn);

  if (parts.length > 1) {
    const divider = document.createElement("div");
    divider.className = "yt-download-divider";
    downloadMenu.appendChild(divider);

    parts.forEach((p, idx) => {
      const itemBtn = document.createElement("button");
      itemBtn.className = "yt-download-item";
      itemBtn.setAttribute("role", "menuitem");
      itemBtn.innerHTML = `
        <span class="yt-download-item-title">
          <span>${idx === activePartIndex ? "▶" : "•"}</span>
          <span>${p.label || 'Part ' + (idx + 1)}</span>
        </span>
        <span class="yt-download-item-size">MP4 下載</span>
      `;
      itemBtn.onclick = () => {
        downloadMenu.style.display = "none";
        downloadEpisodePart(activeEpisode, idx);
      };
      downloadMenu.appendChild(itemBtn);
    });
  }
}

function setupDownloadActions() {
  if (!downloadBtn || !downloadMenu) return;

  downloadBtn.onclick = (e) => {
    e.stopPropagation();
    if (!activeEpisode) {
      if (playerStreamStatus) playerStreamStatus.textContent = "請先選擇欲下載的集數";
      return;
    }

    const parts = activeEpisode.parts || [];
    if (parts.length <= 1) {
      downloadEpisodePart(activeEpisode, 0);
      return;
    }

    const isVisible = downloadMenu.style.display !== "none";
    if (isVisible) {
      downloadMenu.style.display = "none";
      return;
    }

    renderDownloadMenu();
    downloadMenu.style.display = "flex";
  };

  document.addEventListener("click", (e) => {
    if (downloadMenu && downloadMenu.style.display !== "none") {
      if (!e.target.closest("#download-wrapper")) {
        downloadMenu.style.display = "none";
      }
    }
  });
}

// Share Modal & URL Generation
function getShareUrl(episode, partIndex = 0) {
  if (!episode) return "https://dtvsteams.pages.dev";
  const origin = (typeof window !== "undefined" && window.location?.origin && !window.location.origin.startsWith("null"))
    ? window.location.origin
    : "https://dtvsteams.pages.dev";
  const params = new URLSearchParams();
  if (episode.id) params.set("ep", episode.id);
  if (partIndex > 0) params.set("part", String(partIndex + 1));
  return `${origin}/?${params.toString()}`;
}

function setDialogState(el, isOpen, displayValue = "flex") {
  if (!el) return;
  el.style.display = isOpen ? displayValue : "none";
  if (el.tagName === "DIALOG") {
    if (isOpen) {
      el.setAttribute("open", "");
    } else {
      el.removeAttribute("open");
    }
  }
}

function openShareModal(episode, partIndex = 0) {
  if (!shareModal || !episode) return;
  const shareUrl = getShareUrl(episode, partIndex);
  const part = episode.parts?.[partIndex];
  const partLabel = part?.label || `Part ${partIndex + 1}`;

  if (shareModalTitle) shareModalTitle.textContent = episode.title || "分享節目影片";
  if (shareModalSubtitle) shareModalSubtitle.textContent = `${episode.date || "最新"} · ${partLabel} · 掃描或複製即播`;
  if (shareUrlInput) shareUrlInput.value = shareUrl;
  if (shareCopyText) shareCopyText.textContent = "複製連結";

  if (shareQrContainer) {
    const qrLib = (typeof window !== "undefined" && window.QRCode) || (typeof QRCode !== "undefined" ? QRCode : null);
    if (qrLib && typeof qrLib.renderTo === "function") {
      qrLib.renderTo(shareQrContainer, shareUrl);
    } else {
      shareQrContainer.innerHTML = `<div style="padding:40px; text-align:center; color:#fff; font-size:0.9rem;">QR Code 載入中</div>`;
    }
  }

  if (shareNativeBtn) {
    if (typeof navigator !== "undefined" && navigator.share) {
      shareNativeBtn.style.display = "inline-flex";
      shareNativeBtn.onclick = async () => {
        try {
          await navigator.share({
            title: episode.title || "dTVStream 影片分享",
            text: `快來觀看【${episode.title}】(${partLabel})：`,
            url: shareUrl
          });
        } catch (_) {}
      };
    } else {
      shareNativeBtn.style.display = "none";
    }
  }

  setDialogState(shareModal, true, "flex");
}

function closeShareModal() {
  setDialogState(shareModal, false);
}

function setupShareModal() {
  if (shareBtn) {
    shareBtn.onclick = () => {
      const targetEp = activeEpisode || (catalog?.episodes && catalog.episodes[0]) || WEB_SHOW_CHANNELS[0].fallbackEpisodes[0];
      if (targetEp) {
        openShareModal(targetEp, activeEpisode ? activePartIndex : 0);
      }
    };
  }

  if (shareModalBackdrop) shareModalBackdrop.onclick = closeShareModal;
  if (shareModalClose) shareModalClose.onclick = closeShareModal;

  if (shareCopyBtn) {
    shareCopyBtn.onclick = async () => {
      if (!shareUrlInput || !shareUrlInput.value) return;
      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(shareUrlInput.value);
        } else {
          shareUrlInput.select();
          document.execCommand("copy");
        }
        if (shareCopyText) shareCopyText.textContent = "已複製！";
        setTimeout(() => {
          if (shareCopyText) shareCopyText.textContent = "複製連結";
        }, 2500);
      } catch (_) {
        shareUrlInput.select();
        document.execCommand("copy");
        if (shareCopyText) shareCopyText.textContent = "已複製！";
      }
    };
  }

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && shareModal && shareModal.style.display !== "none") {
      closeShareModal();
    }
  });
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

// Show Channels (mirrored from mobile ShowChannels)
const WEB_SHOW_CHANNELS = [
  {
    id: "mr_player",
    name: "綜藝玩很大",
    englishName: "Mr. Player",
    emoji: "🔥",
    tagline: "憲哥領軍・黃黑兩隊命運對決",
    fallbackEpisodes: [
      {
        id: "https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/",
        title: "綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家",
        date: "2026-11-08",
        url: "https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-08-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/",
        showId: "mr_player",
        showName: "綜藝玩很大",
        parts: [
          { label: "Part 1", streamUrl: "./media/sample-part1.mp4", duration: "35分" },
          { label: "Part 2", streamUrl: "./media/sample-part2.mp4", duration: "35分" },
          { label: "Part 3", streamUrl: "./media/sample-part3.mp4", duration: "35分" }
        ]
      }
    ]
  },
  {
    id: "hunger_games",
    name: "飢餓遊戲",
    englishName: "The Hunger Games",
    emoji: "⚡",
    tagline: "飢餓指數對決・爭奪充飢美食與獎金",
    fallbackEpisodes: [
      {
        id: "https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/",
        title: "飢餓遊戲 2026-11-22 飢餓指數特別企劃",
        date: "2026-11-22",
        url: "https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/",
        showId: "hunger_games",
        showName: "飢餓遊戲",
        parts: [
          { label: "Part 1", url: "https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/" },
          { label: "Part 2", url: "https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/2/" },
          { label: "Part 3", url: "https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/3/" }
        ]
      }
    ]
  },
  {
    id: "all_stars",
    name: "全明星運動會",
    englishName: "All Star Sports Day",
    emoji: "🏆",
    tagline: "紅藍巔峰對決・挑戰體育競技極限",
    fallbackEpisodes: [
      {
        id: "https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/",
        title: "全明星運動會 2023-01-08 總冠軍賽殊死戰",
        date: "2023-01-08",
        url: "https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/",
        showId: "all_stars",
        showName: "全明星運動會",
        parts: [
          { label: "Part 1", url: "https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/" },
          { label: "Part 2", url: "https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/2/" },
          { label: "Part 3", url: "https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/3/" }
        ]
      }
    ]
  },
  {
    id: "super_ent",
    name: "小明星大跟班",
    englishName: "Super Ent.",
    emoji: "⭐",
    tagline: "憲哥與Sandy・麻辣爆笑娛樂話題",
    fallbackEpisodes: [
      {
        id: "https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/",
        title: "小明星大跟班 2026-11-20 演藝圈真心話大冒險",
        date: "2026-11-20",
        url: "https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/",
        showId: "super_ent",
        showName: "小明星大跟班",
        parts: [
          { label: "Part 1", url: "https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/" },
          { label: "Part 2", url: "https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/2/" }
        ]
      }
    ]
  },
  {
    id: "hot_shop",
    name: "11點熱吵店",
    englishName: "11 O'Clock Hot Shop",
    emoji: "🌶️",
    tagline: "沈玉琳與Melody・生活辛辣話題爆笑開講",
    fallbackEpisodes: [
      {
        id: "https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/",
        title: "11點熱吵店 2026-11-19 荒謬日常大吐槽",
        date: "2026-11-19",
        url: "https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/",
        showId: "hot_shop",
        showName: "11點熱吵店",
        parts: [
          { label: "Part 1", url: "https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/" },
          { label: "Part 2", url: "https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/2/" }
        ]
      }
    ]
  }
];

let currentChannel = WEB_SHOW_CHANNELS[0];
const channelPageCache = new Map();

const KNOWN_WEB_LOCATIONS = [
  "台北", "新北", "基隆", "桃園", "新竹", "苗栗", "台中", "彰化", "南投", "雲林",
  "嘉義", "台南", "高雄", "屏東", "宜蘭", "花蓮", "台東", "澎湖", "金門", "馬祖",
  "綠島", "蘭嶼", "小琉球", "日本", "韓國", "泰國", "越南", "馬來西亞", "新加坡",
  "峇里島", "沖繩", "北海道", "東京", "大阪", "京都", "首爾", "曼谷", "關西", "紐西蘭"
];

function extractLocationFromTitle(title) {
  for (const loc of KNOWN_WEB_LOCATIONS) {
    if ((title || "").includes(loc)) return loc;
  }
  return "";
}

function detectEpisodeShowMeta(ep) {
  if (ep?.showId) {
    const match = WEB_SHOW_CHANNELS.find(c => c.id === ep.showId);
    if (match) return match;
  }
  const haystack = `${ep?.showName || ""} ${ep?.title || ""} ${ep?.id || ""}`;
  return WEB_SHOW_CHANNELS.find(c => haystack.includes(c.name)) || currentChannel || WEB_SHOW_CHANNELS[0];
}

function stripShowNameFromEpisodeTitle(title, showName) {
  let clean = (title || "").trim();
  if (!clean) return "";
  if (showName) {
    clean = clean.replace(new RegExp(`^[【\\[]?\\s*${showName}\\s*[】\\]]?\\s*[-·|:]?\\s*`), "").trim();
  }
  return clean || title;
}

// Render Episode Feed (1-by-1 Vertical List Matching Mobile YouTubeEpisodeCard)
function renderGrid(list) {
  if (!episodesGrid) return;
  episodesGrid.innerHTML = "";

  if (episodeCountBadge) {
    episodeCountBadge.textContent = `(${list.length} 集)`;
  }

  if (!list.length) {
    episodesGrid.innerHTML = `
      <div style="text-align: center; padding: 3rem 1.5rem; color: var(--yt-text-secondary); background: var(--yt-surface); border: 1px solid var(--yt-border); border-radius: var(--yt-radius-card);">
        <p style="font-size: 15px; font-weight: 600; color: var(--yt-text-primary); margin-bottom: 6px;">找不到符合搜尋或篩選條件的集數</p>
        <p style="font-size: 13px;">請嘗試不同關鍵字或重設年份篩選條件</p>
      </div>
    `;
    renderGooglePagination();
    return;
  }

  list.forEach((ep) => {
    const card = document.createElement("article");
    card.className = "yt-card";
    card.setAttribute("data-id", ep.id);
    card.tabIndex = 0;

    const showMeta = detectEpisodeShowMeta(ep);
    const displayTitle = stripShowNameFromEpisodeTitle(ep.title, showMeta.name);
    const location = extractLocationFromTitle(ep.title || "");
    const resume = getEpisodeResume(ep.id);
    const isCompleted = Boolean(resume && resume.completed);
    const isFav = isFavorite(ep.id);
    const isActiveEp = Boolean(activeEpisode && activeEpisode.id === ep.id);

    const progressBarHtml = resume && resume.percentage > 2
      ? `<div class="yt-thumb-progress" style="width: ${resume.percentage}%;"></div>`
      : "";

    const resumeMetaHtml = resume && resume.percentage > 0 && !isCompleted
      ? `<div class="yt-card-resume-meta"><span class="yt-card-resume-text">上次看至 Part ${resume.partIndex + 1} (${formatTime(resume.currentTime)})</span></div>`
      : "";

    card.innerHTML = `
      <div class="yt-card-top-row">
        <button type="button" class="card-play-btn" aria-label="播放節目">
          <span class="card-play-circle ${isCompleted ? "completed" : ""}">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true">
              <path d="M8 5v14l11-7z"/>
            </svg>
          </span>
        </button>

        <div class="yt-card-body">
          <h3 class="yt-card-title" title="${ep.title}">${displayTitle}</h3>
          <div class="card-meta-wrap">
            ${ep.date ? `<span class="card-date-text">${ep.date}</span>` : ""}
            <span class="card-show-badge">${showMeta.emoji} ${showMeta.name}</span>
            ${location ? `<span class="card-location-badge">📍 ${location}</span>` : ""}
            ${isCompleted ? `<span class="yt-card-watched-badge">✓ 已看完</span>` : ""}
          </div>
          ${resumeMetaHtml}
        </div>

        <div class="card-actions-cluster">
          <button type="button" class="card-circle-btn card-fav-btn ${isFav ? "is-favorite" : ""}" aria-label="${isFav ? "取消收藏" : "加入收藏"}" title="${isFav ? "已收藏" : "加入收藏"}">
            <span class="card-circle-visual">
              <svg viewBox="0 0 24 24" width="17" height="17" fill="${isFav ? "currentColor" : "none"}" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
              </svg>
            </span>
          </button>
          <button type="button" class="card-circle-btn card-dl-btn" aria-label="下載此集" title="下載目前集數">
            <span class="card-circle-visual">
              <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                <polyline points="7 10 12 15 17 10"/>
                <line x1="12" y1="15" x2="12" y2="3"/>
              </svg>
            </span>
          </button>
        </div>
      </div>

      <div class="yt-card-parts" role="group" aria-label="分段播放">
        ${(ep.parts || []).map((part, pIdx) => {
          const playingThisPart = isActiveEp && activePartIndex === pIdx;
          const partDone = isCompleted || (resume && resume.partIndex > pIdx);
          return `
            <button type="button" class="yt-card-part-btn ${playingThisPart ? "is-playing" : (partDone ? "is-watched" : "")}" data-part="${pIdx}" aria-label="播放 ${part.label || 'Part ' + (pIdx + 1)}">
              ▶ ${part.label || "Part " + (pIdx + 1)}${partDone ? " ✓" : ""}
            </button>
          `;
        }).join("")}
      </div>
      ${progressBarHtml}
    `;

    const favAction = card.querySelector(".card-fav-btn");
    if (favAction) {
      favAction.addEventListener("click", (e) => {
        e.stopPropagation();
        toggleFavorite(ep);
        applyFilters();
      });
    }

    const dlAction = card.querySelector(".card-dl-btn");
    if (dlAction) {
      dlAction.addEventListener("click", (e) => {
        e.stopPropagation();
        downloadEpisodePart(ep, 0);
      });
    }

    card.addEventListener("click", (e) => {
      const partBtn = e.target.closest(".yt-card-part-btn");
      if (partBtn) {
        const pIdx = parseInt(partBtn.getAttribute("data-part") || "0", 10);
        playPart(ep, pIdx, true, true);
      } else {
        playPart(ep, 0, true, false);
      }
      expandPlayerCard();
      window.scrollTo({ top: 0, behavior: "smooth" });
    });

    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.target.closest("button")) {
        playPart(ep, 0, true, false);
        expandPlayerCard();
        window.scrollTo({ top: 0, behavior: "smooth" });
      }
    });

    episodesGrid.appendChild(card);
  });

  if (activeEpisode) {
    highlightActiveCard(activeEpisode.id);
  }
  renderGooglePagination();
}

function expandPlayerCard() {
  const body = document.getElementById("player-collapsible-body");
  const btn = document.getElementById("player-collapse-btn");
  if (body) body.style.display = "block";
  if (btn) {
    btn.setAttribute("aria-expanded", "true");
    btn.textContent = "收合播放器";
  }
}

function setupPlayerCollapse() {
  const btn = document.getElementById("player-collapse-btn");
  const body = document.getElementById("player-collapsible-body");
  if (!btn || !body) return;
  btn.addEventListener("click", () => {
    const collapsed = body.style.display === "none";
    body.style.display = collapsed ? "block" : "none";
    btn.setAttribute("aria-expanded", collapsed ? "true" : "false");
    btn.textContent = collapsed ? "收合播放器" : "展開播放器";
  });
}

function renderGooglePagination() {
  const nav = document.getElementById("google-pagination-bar");
  if (!nav) return;

  const effectiveTotal = Math.max(10, TOTAL_SOURCE_PAGES);
  const startPage = Math.max(1, Math.min(currentCatalogPage - 2, effectiveTotal - 4));
  const endPage = Math.min(effectiveTotal, startPage + 4);
  const pages = [];
  for (let p = startPage; p <= endPage; p++) {
    pages.push(p);
  }

  nav.innerHTML = `
    <button type="button" class="gpage-prev-next" id="gpage-prev" ${currentCatalogPage <= 1 ? "disabled" : ""} aria-label="上一頁">
      ‹ 上一頁
    </button>
    ${pages.map((p) => `
      <button type="button" class="gpage-num ${p === currentCatalogPage ? "active" : ""}" data-page="${p}" aria-label="第 ${p} 頁" ${p === currentCatalogPage ? 'aria-current="page"' : ""}>
        ${p}
      </button>
    `).join("")}
    <button type="button" class="gpage-prev-next" id="gpage-next" ${currentCatalogPage >= TOTAL_SOURCE_PAGES ? "disabled" : ""} aria-label="下一頁">
      下一頁 ›
    </button>
  `;

  const prevBtn = nav.querySelector("#gpage-prev");
  if (prevBtn) prevBtn.addEventListener("click", () => goToCatalogPage(currentCatalogPage - 1));
  const nextBtn = nav.querySelector("#gpage-next");
  if (nextBtn) nextBtn.addEventListener("click", () => goToCatalogPage(currentCatalogPage + 1));
  nav.querySelectorAll(".gpage-num").forEach((btn) => {
    btn.addEventListener("click", () => {
      const targetPage = parseInt(btn.getAttribute("data-page") || "1", 10);
      goToCatalogPage(targetPage);
    });
  });
}

async function goToCatalogPage(page) {
  if (page < 1 || page > TOTAL_SOURCE_PAGES || page === currentCatalogPage) return;
  const cacheKey = `${currentChannel.id}:${page}`;
  if (channelPageCache.has(cacheKey)) {
    currentCatalogPage = page;
    catalog.episodes = channelPageCache.get(cacheKey);
    filteredEpisodes = [...catalog.episodes];
    applyFilters();
    window.scrollTo({ top: 0, behavior: "smooth" });
    return;
  }

  if (catalogStatus) catalogStatus.textContent = `載入第 ${page} 頁...`;
  try {
    const res = await fetch(`/api/episodes?page=${page}&show=${encodeURIComponent(currentChannel.id)}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (!data.ok || !Array.isArray(data.episodes) || !data.episodes.length) throw new Error("無集數資料");
    channelPageCache.set(cacheKey, data.episodes);
    currentCatalogPage = page;
    catalog.episodes = data.episodes;
    filteredEpisodes = [...catalog.episodes];
    if (catalogStatus) catalogStatus.textContent = `第 ${page} 頁 (${data.episodes.length} 集)`;
    applyFilters();
    window.scrollTo({ top: 0, behavior: "smooth" });
  } catch (err) {
    if (catalogStatus) catalogStatus.textContent = `載入第 ${page} 頁失敗`;
  }
}

function setupChannelPicker() {
  const pickerBtn = document.getElementById("channel-picker-btn");
  const modal = document.getElementById("channel-modal");
  const backdrop = document.getElementById("channel-modal-backdrop");
  const closeBtn = document.getElementById("channel-modal-close");
  const container = document.getElementById("channel-list-container");
  if (!pickerBtn || !modal || !container) return;

  function renderChannelOptions() {
    container.innerHTML = WEB_SHOW_CHANNELS.map((ch) => {
      const isSelected = ch.id === currentChannel.id;
      return `
        <button type="button" class="channel-option-btn ${isSelected ? "active" : ""}" data-channel-id="${ch.id}">
          <span class="channel-option-emoji">${ch.emoji}</span>
          <span class="channel-option-meta">
            <div class="channel-option-title">${ch.name} <span style="font-size:12px; color:var(--yt-text-secondary); font-weight:400;">${ch.englishName}</span></div>
            <div class="channel-option-sub">${ch.tagline}</div>
          </span>
          ${isSelected ? '<span style="color:var(--yt-red); font-weight:700;">✓</span>' : ""}
        </button>
      `;
    }).join("");

    container.querySelectorAll(".channel-option-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        const id = btn.getAttribute("data-channel-id");
        const ch = WEB_SHOW_CHANNELS.find((c) => c.id === id);
        setDialogState(modal, false);
        pickerBtn.setAttribute("aria-expanded", "false");
        if (ch) switchChannel(ch);
      });
    });
  }

  function closeModal() {
    setDialogState(modal, false);
    pickerBtn.setAttribute("aria-expanded", "false");
  }

  pickerBtn.addEventListener("click", () => {
    renderChannelOptions();
    setDialogState(modal, true, "flex");
    pickerBtn.setAttribute("aria-expanded", "true");
  });
  if (backdrop) backdrop.addEventListener("click", closeModal);
  if (closeBtn) closeBtn.addEventListener("click", closeModal);
}

async function switchChannel(ch) {
  if (!ch || ch.id === currentChannel.id) return;
  currentChannel = ch;
  currentCatalogPage = 1;
  const emojiEl = document.getElementById("channel-emoji");
  const nameEl = document.getElementById("channel-name");
  if (emojiEl) emojiEl.dataset.channelEmoji = ch.emoji;
  if (nameEl) nameEl.textContent = ch.name;

  const cacheKey = `${ch.id}:1`;
  if (channelPageCache.has(cacheKey)) {
    catalog.episodes = channelPageCache.get(cacheKey);
    filteredEpisodes = [...catalog.episodes];
    applyFilters();
    return;
  }

  // Immediate fallback render before async fetch
  catalog.episodes = [...ch.fallbackEpisodes];
  filteredEpisodes = [...catalog.episodes];
  if (catalogStatus) catalogStatus.textContent = `切換至「${ch.name}」...`;
  applyFilters();

  try {
    const res = await fetch(`/api/episodes?page=1&show=${encodeURIComponent(ch.id)}`);
    if (res.ok) {
      const data = await res.json();
      if (data.ok && Array.isArray(data.episodes) && data.episodes.length) {
        channelPageCache.set(cacheKey, data.episodes);
        catalog.episodes = data.episodes;
        filteredEpisodes = [...data.episodes];
        if (catalogStatus) catalogStatus.textContent = `已同步 (${data.episodes.length} 集)`;
        applyFilters();
      }
    }
  } catch (_) {}
}

// Year Filter & Search History & Chronological Sorting (Feature 10)
function getSearchHistory() {
  try {
    const raw = localStorage.getItem(SEARCH_HISTORY_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch (_) {
    return [];
  }
}

function addSearchHistory(query) {
  const trimmed = (query || "").trim();
  if (!trimmed) return;
  let list = getSearchHistory();
  list = list.filter(item => item.toLowerCase() !== trimmed.toLowerCase());
  list.unshift(trimmed);
  if (list.length > 10) list = list.slice(0, 10);
  try {
    localStorage.setItem(SEARCH_HISTORY_KEY, JSON.stringify(list));
  } catch (_) {}
  renderSearchDropdown();
}

function removeSearchHistory(query) {
  let list = getSearchHistory();
  list = list.filter(item => item !== query);
  try {
    localStorage.setItem(SEARCH_HISTORY_KEY, JSON.stringify(list));
  } catch (_) {}
  renderSearchDropdown();
}

function clearSearchHistory() {
  try {
    localStorage.removeItem(SEARCH_HISTORY_KEY);
  } catch (_) {}
  renderSearchDropdown();
}

function matchesYear(ep, year) {
  if (!year || year === "all") return true;
  const date = (ep.date || "").trim();
  const title = (ep.title || "").trim();
  if (year === "classic") {
    const yearMatch = date.match(/(20\d\d)/) || title.match(/(20\d\d)/);
    if (yearMatch) {
      const y = parseInt(yearMatch[1], 10);
      return y <= 2021;
    }
    return false;
  }
  return date.startsWith(year) || title.includes(year);
}

function compareEpisodes(a, b) {
  const dateA = a.date || "";
  const dateB = b.date || "";
  if (isSortAscending) {
    return dateA.localeCompare(dateB);
  } else {
    return dateB.localeCompare(dateA);
  }
}

function applyFilters() {
  const query = (searchInput?.value || "").trim().toLowerCase();
  if (searchClearBtn) {
    searchClearBtn.style.display = query.length > 0 ? "block" : "none";
  }

  const baseEpisodes = isFavoritesOnlyFilter ? getFavorites() : (catalog?.episodes || []);
  let list = [...baseEpisodes];

  if (query) {
    list = list.filter((ep) => {
      const title = (ep.title || "").toLowerCase();
      const date = (ep.date || "").toLowerCase();
      const overview = (ep.overview || "").toLowerCase();
      const tags = (ep.tags || []).join(" ").toLowerCase();
      return title.includes(query) || date.includes(query) || overview.includes(query) || tags.includes(query);
    });
  }

  if (selectedYear !== "all") {
    list = list.filter(ep => matchesYear(ep, selectedYear));
  }

  list.sort(compareEpisodes);
  filteredEpisodes = list;
  renderGrid(filteredEpisodes);
}

function setYearFilter(year) {
  selectedYear = year;
  if (isBrowser) {
    document.querySelectorAll(".yt-year-chip").forEach((btn) => {
      btn.classList.toggle("active", btn.getAttribute("data-year") === year);
    });
  }
  applyFilters();
}

function toggleSortOrder() {
  isSortAscending = !isSortAscending;
  if (isBrowser) {
    const sortBtn = document.getElementById("sort-order-btn");
    const sortIcon = document.getElementById("sort-icon");
    const sortLabel = document.getElementById("sort-label");
    if (sortBtn) sortBtn.classList.toggle("ascending", isSortAscending);
    if (sortIcon) sortIcon.textContent = isSortAscending ? "⬆" : "⬇";
    if (sortLabel) sortLabel.textContent = isSortAscending ? "舊到新" : "新到舊";
  }
  applyFilters();
}

function renderSearchDropdown() {
  if (!isBrowser) return;
  const historyChips = document.getElementById("search-history-chips");
  const historySection = document.getElementById("search-history-section");
  const hotTagsChips = document.getElementById("hot-tags-chips");

  if (historyChips && historySection) {
    const history = getSearchHistory();
    historyChips.innerHTML = "";
    if (history.length === 0) {
      historySection.style.display = "none";
    } else {
      historySection.style.display = "block";
      history.forEach((q) => {
        const chip = document.createElement("span");
        chip.className = "yt-search-chip";
        chip.innerHTML = `
          <span class="yt-chip-text">${q}</span>
          <button type="button" class="yt-chip-del" aria-label="刪除搜尋紀錄 ${q}">✕</button>
        `;
        chip.querySelector(".yt-chip-text").onclick = (e) => {
          e.stopPropagation();
          if (searchInput) searchInput.value = q;
          addSearchHistory(q);
          applyFilters();
          closeSearchDropdown();
        };
        chip.querySelector(".yt-chip-del").onclick = (e) => {
          e.stopPropagation();
          removeSearchHistory(q);
        };
        historyChips.appendChild(chip);
      });
    }
  }

  if (hotTagsChips) {
    hotTagsChips.innerHTML = "";
    DEFAULT_HOT_TAGS.forEach((tag) => {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.className = "yt-hot-chip";
      chip.textContent = tag;
      chip.onclick = (e) => {
        e.stopPropagation();
        if (searchInput) searchInput.value = tag;
        addSearchHistory(tag);
        applyFilters();
        closeSearchDropdown();
      };
      hotTagsChips.appendChild(chip);
    });
  }
}

function openSearchDropdown() {
  const searchDropdown = document.getElementById("search-dropdown");
  if (searchDropdown) {
    renderSearchDropdown();
    searchDropdown.style.display = "flex";
  }
}

function closeSearchDropdown() {
  const searchDropdown = document.getElementById("search-dropdown");
  if (searchDropdown) {
    searchDropdown.style.display = "none";
  }
}

function setupSearchAndFilters() {
  if (!isBrowser) return;

  if (searchInput) {
    searchInput.addEventListener("focus", openSearchDropdown);
    searchInput.addEventListener("click", openSearchDropdown);
    searchInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        const q = searchInput.value.trim();
        if (q) addSearchHistory(q);
        applyFilters();
        closeSearchDropdown();
      }
    });
  }

  const clearAllHistBtn = document.getElementById("clear-all-history-btn");
  if (clearAllHistBtn) {
    clearAllHistBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      clearSearchHistory();
    });
  }

  document.addEventListener("click", (e) => {
    if (!e.target.closest(".yt-search-box")) {
      closeSearchDropdown();
    }
  });

  const sortBtn = document.getElementById("sort-order-btn");
  if (sortBtn) {
    sortBtn.addEventListener("click", toggleSortOrder);
  }

  document.querySelectorAll(".yt-year-chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      const year = chip.getAttribute("data-year") || "all";
      setYearFilter(year);
    });
  });

  renderSearchDropdown();
}

// Live Search Filter
function handleSearch() {
  applyFilters();
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

  applyFilters();

  // Stage episode (with deep-link query parameter support: ?ep=...&part=...)
  let targetEpisode = catalog.episodes[0];
  let targetPartIndex = 0;
  if (typeof window !== "undefined" && window.location && window.location.search) {
    try {
      const urlParams = new URLSearchParams(window.location.search);
      const epParam = urlParams.get("ep");
      const partParam = parseInt(urlParams.get("part") || "1", 10) - 1;
      if (epParam) {
        const found = catalog.episodes.find((e) => e.id === epParam || e.url === epParam || (e.id && e.id.includes(epParam)));
        if (found) {
          targetEpisode = found;
          targetPartIndex = Math.max(0, partParam);
        }
      }
    } catch (_) {}
  }

  if (targetEpisode) {
    playPart(targetEpisode, targetPartIndex, false, false);
  }

  // Bind Load More button
  const loadMoreBtn = document.getElementById("load-more-btn");
  if (loadMoreBtn) {
    loadMoreBtn.onclick = () => loadNextPage();
  }
  if (refreshBtn) {
    refreshBtn.onclick = () => loadCatalog();
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

    applyFilters();

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

// Fast-forward & Rewind with Debounced Seeking and Visual HUD
let seekDebounceTimer = null;
let seekTargetTime = null;
let seekHudTimer = null;

function seekRelative(deltaSeconds) {
  if (!player) return;
  const baseTime = seekTargetTime !== null ? seekTargetTime : (player.currentTime || 0);
  const dur = player.duration || (baseTime + 3600);
  const target = Math.max(0, Math.min(dur - 2, baseTime + deltaSeconds));
  seekTargetTime = target;

  showSeekHud(target, deltaSeconds);

  clearTimeout(seekDebounceTimer);
  seekDebounceTimer = setTimeout(() => {
    if (player && seekTargetTime !== null) {
      player.currentTime = seekTargetTime;
      seekTargetTime = null;
    }
  }, 220);
}

function showSeekHud(targetTime, delta) {
  let hud = document.getElementById("yt-seek-hud");
  if (!hud) {
    hud = document.createElement("div");
    hud.id = "yt-seek-hud";
    hud.className = "yt-seek-hud";
    const container = document.querySelector(".yt-player-container");
    if (container) container.appendChild(hud);
  }
  const sign = delta > 0 ? "+" : "";
  hud.innerHTML = `<span>${delta > 0 ? "⏩" : "⏪"} ${formatTime(targetTime)} (${sign}${delta}s)</span>`;
  hud.classList.add("visible");

  clearTimeout(seekHudTimer);
  seekHudTimer = setTimeout(() => {
    hud.classList.remove("visible");
  }, 1000);
}

function setupQuickSkipButtons() {
  const btnBack10 = document.getElementById("skip-back-10");
  const btnFwd10 = document.getElementById("skip-fwd-10");
  const btnFwd30 = document.getElementById("skip-fwd-30");
  const btnFwd60 = document.getElementById("skip-fwd-60");

  if (btnBack10) btnBack10.addEventListener("click", () => seekRelative(-10));
  if (btnFwd10) btnFwd10.addEventListener("click", () => seekRelative(10));
  if (btnFwd30) btnFwd30.addEventListener("click", () => seekRelative(30));
  if (btnFwd60) btnFwd60.addEventListener("click", () => seekRelative(60));
}

// Global Keyboard Shortcuts (Remote / Desktop friendly)
function setupShortcuts() {
  window.addEventListener("keydown", (e) => {
    // When screen is locked, ignore all shortcuts except Escape which unlocks
    if (isScreenLocked) {
      if (e.key === "Escape") {
        unlockScreen();
      }
      return;
    }

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
        seekRelative(-10);
        break;

      case "ArrowRight":
      case "l":
        e.preventDefault();
        seekRelative(10);
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

      case ">":
      case ".":
      case "]":
        e.preventDefault();
        cycleSpeed(1);
        break;

      case "<":
      case ",":
      case "[":
        e.preventDefault();
        cycleSpeed(-1);
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

// Double-Tap / Double-Click Seek with Accumulation
let seekAccumulated = 0;
let seekFeedbackTimer = null;

function triggerDoubleTapSeek(isForward) {
  if (!player && typeof document !== "undefined") {
    player = document.getElementById("main-player");
  }
  if (!player) return;
  const delta = isForward ? 10 : -10;
  if (seekAccumulated !== 0 && (isForward ? seekAccumulated > 0 : seekAccumulated < 0)) {
    seekAccumulated += delta;
  } else {
    seekAccumulated = delta;
  }

  seekRelative(delta);

  const leftOverlay = document.getElementById("seek-overlay-left");
  const rightOverlay = document.getElementById("seek-overlay-right");
  const textLeft = document.getElementById("seek-text-left");
  const textRight = document.getElementById("seek-text-right");

  if (isForward && rightOverlay && textRight) {
    textRight.textContent = `+${Math.abs(seekAccumulated)}秒`;
    rightOverlay.style.display = "flex";
    if (leftOverlay) leftOverlay.style.display = "none";
  } else if (!isForward && leftOverlay && textLeft) {
    textLeft.textContent = `-${Math.abs(seekAccumulated)}秒`;
    leftOverlay.style.display = "flex";
    if (rightOverlay) rightOverlay.style.display = "none";
  }

  clearTimeout(seekFeedbackTimer);
  seekFeedbackTimer = setTimeout(() => {
    if (leftOverlay) leftOverlay.style.display = "none";
    if (rightOverlay) rightOverlay.style.display = "none";
    seekAccumulated = 0;
  }, 700);
}

function setupDoubleTapSeek() {
  const container = document.getElementById("player-container");
  if (!container) return;

  let lastTapTime = 0;
  let lastTapX = 0;

  container.addEventListener("dblclick", (e) => {
    const rect = container.getBoundingClientRect();
    const x = e.clientX - rect.left;
    if (x < rect.width * 0.45) {
      triggerDoubleTapSeek(false);
    } else if (x > rect.width * 0.55) {
      triggerDoubleTapSeek(true);
    }
  });

  // Touch support for mobile browsers
  container.addEventListener("touchend", (e) => {
    const now = Date.now();
    const touch = e.changedTouches?.[0];
    if (!touch) return;
    const rect = container.getBoundingClientRect();
    const x = touch.clientX - rect.left;

    if (now - lastTapTime < 350 && Math.abs(x - lastTapX) < 100) {
      if (x < rect.width * 0.45) {
        triggerDoubleTapSeek(false);
      } else if (x > rect.width * 0.55) {
        triggerDoubleTapSeek(true);
      }
      lastTapTime = 0;
    } else {
      lastTapTime = now;
      lastTapX = x;
    }
  });
}

// Vertical Swipe HUD & Controls (Brightness & Volume)
let currentBrightness = 1.0;
let hudFadeTimer = null;

function updateBrightness(deltaOrValue, isAbsolute = false) {
  if (isAbsolute) {
    currentBrightness = Math.min(1.0, Math.max(0.1, deltaOrValue));
  } else {
    currentBrightness = Math.min(1.0, Math.max(0.1, currentBrightness + deltaOrValue));
  }

  const player = document.getElementById("main-player");
  if (player) {
    player.style.filter = `brightness(${0.2 + currentBrightness * 0.8})`;
  }

  const hud = document.getElementById("hud-brightness");
  const fill = document.getElementById("hud-brightness-fill");
  const text = document.getElementById("hud-brightness-text");
  const icon = document.getElementById("hud-brightness-icon");

  if (hud && fill && text && icon) {
    const pct = Math.round(currentBrightness * 100);
    text.textContent = `${pct}%`;
    fill.style.height = `${pct}%`;
    icon.textContent = currentBrightness > 0.6 ? "🔆" : (currentBrightness > 0.25 ? "🔅" : "🌑");
    hud.style.opacity = "1";

    clearTimeout(hudFadeTimer);
    hudFadeTimer = setTimeout(() => {
      hud.style.opacity = "0";
      const hudVol = document.getElementById("hud-volume");
      if (hudVol) hudVol.style.opacity = "0";
    }, 800);
  }
}

function updateVolume(deltaOrValue, isAbsolute = false) {
  const player = document.getElementById("main-player");
  let curVol = player ? player.volume : 1.0;
  let newVol = isAbsolute ? deltaOrValue : curVol + deltaOrValue;
  newVol = Math.min(1.0, Math.max(0.0, newVol));

  if (player) {
    player.volume = newVol;
    player.muted = (newVol === 0);
  }

  const hud = document.getElementById("hud-volume");
  const fill = document.getElementById("hud-volume-fill");
  const text = document.getElementById("hud-volume-text");
  const icon = document.getElementById("hud-volume-icon");

  if (hud && fill && text && icon) {
    const pct = Math.round(newVol * 100);
    text.textContent = `${pct}%`;
    fill.style.height = `${pct}%`;
    icon.textContent = newVol === 0 ? "🔇" : (newVol > 0.5 ? "🔊" : "🔉");
    hud.style.opacity = "1";

    clearTimeout(hudFadeTimer);
    hudFadeTimer = setTimeout(() => {
      hud.style.opacity = "0";
      const hudBri = document.getElementById("hud-brightness");
      if (hudBri) hudBri.style.opacity = "0";
    }, 800);
  }
}

function setupVerticalSwipe() {
  const container = document.getElementById("player-container");
  if (!container) return;

  let isSwiping = false;
  let swipeSide = null; // "left" | "right"
  let startX = 0;
  let startY = 0;
  let startVal = 1.0;

  function handleStart(x, y) {
    const rect = container.getBoundingClientRect();
    const relX = x - rect.left;
    if (relX < rect.width * 0.45) {
      swipeSide = "left";
      startVal = currentBrightness;
    } else if (relX > rect.width * 0.55) {
      swipeSide = "right";
      const player = document.getElementById("main-player");
      startVal = player ? player.volume : 1.0;
    } else {
      swipeSide = null;
      return;
    }
    startX = x;
    startY = y;
    isSwiping = false;
  }

  function handleMove(x, y, cancelEvent) {
    if (!swipeSide) return;
    const deltaY = startY - y; // Dragging UP increases value
    const deltaX = Math.abs(x - startX);

    if (!isSwiping && Math.abs(deltaY) > 10 && Math.abs(deltaY) > deltaX) {
      isSwiping = true;
    }

    if (isSwiping) {
      if (cancelEvent && cancelEvent.cancelable) {
        cancelEvent.preventDefault();
      }
      const rect = container.getBoundingClientRect();
      const sensitivity = rect.height > 0 ? rect.height * 0.65 : 200;
      const deltaVal = deltaY / sensitivity;
      const targetVal = Math.min(1.0, Math.max(0.0, startVal + deltaVal));

      if (swipeSide === "left") {
        updateBrightness(targetVal, true);
      } else if (swipeSide === "right") {
        updateVolume(targetVal, true);
      }
    }
  }

  function handleEnd() {
    isSwiping = false;
    swipeSide = null;
  }

  // Pointer / Touch / Mouse bindings
  container.addEventListener("pointerdown", (e) => {
    if (e.button !== 0) return;
    handleStart(e.clientX, e.clientY);
  });

  if (typeof window !== "undefined") {
    window.addEventListener("pointermove", (e) => {
      if (swipeSide) {
        handleMove(e.clientX, e.clientY, e);
      }
    });

    window.addEventListener("pointerup", handleEnd);
    window.addEventListener("pointercancel", handleEnd);
  }

  // Touch fallback
  container.addEventListener("touchstart", (e) => {
    const t = e.touches[0];
    if (t) handleStart(t.clientX, t.clientY);
  }, { passive: true });

  container.addEventListener("touchmove", (e) => {
    const t = e.touches[0];
    if (t) handleMove(t.clientX, t.clientY, e);
  }, { passive: false });

  container.addEventListener("touchend", handleEnd);
  container.addEventListener("touchcancel", handleEnd);
}

// Sleep Timer Controller
let sleepTimerMode = "0"; // "0", "15", "30", "45", "60", "end"
let sleepTimerRemaining = 0;
let sleepTimerInterval = null;

function setSleepTimer(mode) {
  clearInterval(sleepTimerInterval);
  sleepTimerMode = String(mode);

  const badge = document.getElementById("sleep-timer-badge");
  const options = document.querySelectorAll(".yt-timer-opt");
  options.forEach((opt) => {
    opt.classList.toggle("active", opt.dataset.minutes === sleepTimerMode);
  });

  if (sleepTimerMode === "0") {
    sleepTimerRemaining = 0;
    if (badge) badge.style.display = "none";
    return;
  }

  if (sleepTimerMode === "end") {
    sleepTimerRemaining = 0;
    if (badge) {
      badge.textContent = "分段";
      badge.style.display = "inline-block";
    }
    return;
  }

  const mins = parseInt(sleepTimerMode, 10);
  if (isNaN(mins) || mins <= 0) return;

  sleepTimerRemaining = mins * 60;
  updateSleepTimerBadge();

  sleepTimerInterval = setInterval(() => {
    if (sleepTimerRemaining > 1) {
      sleepTimerRemaining--;
      updateSleepTimerBadge();
    } else {
      sleepTimerRemaining = 0;
      triggerSleepTimerExpired();
    }
  }, 1000);
}

function updateSleepTimerBadge() {
  const badge = document.getElementById("sleep-timer-badge");
  if (!badge) return;
  if (sleepTimerRemaining <= 0) {
    badge.style.display = "none";
    return;
  }
  const mins = Math.ceil(sleepTimerRemaining / 60);
  badge.textContent = `${mins}m`;
  badge.style.display = "inline-block";
}

function triggerSleepTimerExpired() {
  clearInterval(sleepTimerInterval);
  sleepTimerMode = "0";
  sleepTimerRemaining = 0;
  const badge = document.getElementById("sleep-timer-badge");
  if (badge) badge.style.display = "none";

  if (player && typeof player.pause === "function") {
    player.pause();
  }

  showSleepToast("睡眠定時已到達，播放已暫停");
}

function showSleepToast(msg) {
  let toast = document.getElementById("yt-sleep-toast");
  if (!toast) {
    toast = document.createElement("div");
    toast.id = "yt-sleep-toast";
    toast.className = "yt-resume-toast";
    const container = document.querySelector(".yt-player-container") || document.body;
    container.appendChild(toast);
  }
  toast.innerHTML = `
    <span>${msg}</span>
    <button id="sleep-extend-btn" class="yt-btn yt-btn-secondary" style="padding: 4px 10px; font-size: 0.75rem; margin-left: 10px; background:#e50914; color:#fff; border:none; border-radius:6px; cursor:pointer;">+15 分鐘</button>
  `;
  toast.classList.add("visible");
  toast.style.display = "flex";

  const extendBtn = document.getElementById("sleep-extend-btn");
  if (extendBtn) {
    extendBtn.addEventListener("click", () => {
      setSleepTimer("15");
      if (player && typeof player.play === "function") {
        player.play().catch(() => {});
      }
      toast.classList.remove("visible");
      toast.style.display = "none";
    });
  }

  setTimeout(() => {
    if (toast) {
      toast.classList.remove("visible");
      toast.style.display = "none";
    }
  }, 8000);
}

function setupSleepTimerModal() {
  const btn = document.getElementById("sleep-timer-btn");
  const modal = document.getElementById("sleep-timer-modal");
  const backdrop = document.getElementById("sleep-timer-modal-backdrop");
  const closeBtn = document.getElementById("sleep-timer-modal-close");
  const options = document.querySelectorAll(".yt-timer-opt");

  function openModal() {
    setDialogState(modal, true, "flex");
  }
  function closeModal() {
    setDialogState(modal, false);
  }

  if (btn) btn.addEventListener("click", openModal);
  if (backdrop) backdrop.addEventListener("click", closeModal);
  if (closeBtn) closeBtn.addEventListener("click", closeModal);

  options.forEach((opt) => {
    opt.addEventListener("click", () => {
      setSleepTimer(opt.dataset.minutes);
      closeModal();
    });
  });
}

// Aspect Ratio Scale Mode (Feature 5)
let currentScaleMode = "contain"; // "contain", "cover", "fill"
const SCALE_MODES = ["contain", "cover", "fill"];
const SCALE_LABELS = {
  contain: "適應 (Fit)",
  cover: "填滿 (Fill)",
  fill: "拉伸 16:9 (Stretch)"
};

function cycleScaleMode() {
  const nextIdx = (SCALE_MODES.indexOf(currentScaleMode) + 1) % SCALE_MODES.length;
  currentScaleMode = SCALE_MODES[nextIdx];
  const video = document.getElementById("player_html5_api") || document.querySelector("#player-container video");
  if (video) {
    video.style.objectFit = currentScaleMode;
  }
  const label = document.getElementById("scale-mode-label");
  if (label) {
    label.textContent = SCALE_LABELS[currentScaleMode];
  }
  showSleepToast(`畫面比例：${SCALE_LABELS[currentScaleMode]}`);
}

function setupScaleMode() {
  const btn = document.getElementById("scale-mode-btn");
  if (btn) {
    btn.addEventListener("click", cycleScaleMode);
  }
}

// Press-and-Hold 2X Speed (Feature 5)
let isHolding2x = false;
let hold2xTimer = null;
let preHoldSpeed = 1.0;

function setupPressAndHold2x() {
  const container = document.getElementById("player-container");
  const hud = document.getElementById("hud-speed-2x");
  if (!container) return;

  function startHold(e) {
    if (isScreenLocked) return;
    if (e.target.closest(".vjs-control-bar") || e.target.closest(".yt-seek-overlay")) return;
    clearTimeout(hold2xTimer);
    hold2xTimer = setTimeout(() => {
      if (!player) return;
      isHolding2x = true;
      preHoldSpeed = typeof player.playbackRate === "function" ? player.playbackRate() : 1.0;
      if (typeof player.playbackRate === "function") {
        player.playbackRate(2.0);
      }
      if (hud) hud.style.display = "flex";
    }, 350);
  }

  function endHold() {
    clearTimeout(hold2xTimer);
    if (isHolding2x) {
      isHolding2x = false;
      if (player && typeof player.playbackRate === "function") {
        player.playbackRate(preHoldSpeed);
      }
      if (hud) hud.style.display = "none";
    }
  }

  container.addEventListener("mousedown", startHold);
  window.addEventListener("mouseup", endHold);
  container.addEventListener("touchstart", (e) => startHold(e), { passive: true });
  window.addEventListener("touchend", endHold);
}

// Favorites (Watch Later & Bookmarks - Feature 6)
const FAVORITES_STORAGE_KEY = "dtv_favorites";
let isFavoritesOnlyFilter = false;

function getFavorites() {
  try {
    const raw = localStorage.getItem(FAVORITES_STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch (err) {
    return [];
  }
}

function isFavorite(episodeId) {
  if (!episodeId) return false;
  return getFavorites().some(ep => ep.id === episodeId);
}

function toggleFavorite(episode) {
  if (!episode || !episode.id) return false;
  const favs = getFavorites();
  const idx = favs.findIndex(ep => ep.id === episode.id);
  let added = false;
  if (idx >= 0) {
    favs.splice(idx, 1);
    added = false;
  } else {
    favs.unshift(episode);
    added = true;
  }
  try {
    localStorage.setItem(FAVORITES_STORAGE_KEY, JSON.stringify(favs));
  } catch (err) {}

  updateFavoritesUI();
  showSleepToast(added ? "❤️ 已加入收藏清單" : "已從收藏清單移除");
  return added;
}

function updateFavoritesUI() {
  if (typeof document === "undefined") return;
  const favs = getFavorites();
  const badge = document.getElementById("fav-badge");
  if (badge) {
    if (favs.length > 0) {
      badge.textContent = favs.length > 99 ? "99+" : favs.length;
      badge.style.display = "inline-block";
    } else {
      badge.style.display = "none";
    }
  }

  const favBtn = document.getElementById("fav-btn");
  const favBtnIcon = document.getElementById("fav-btn-icon");
  const favBtnText = document.getElementById("fav-btn-text");
  if (favBtn && activeEpisode) {
    const isFav = isFavorite(activeEpisode.id);
    if (favBtnIcon) favBtnIcon.textContent = isFav ? "❤️" : "🤍";
    if (favBtnText) favBtnText.textContent = isFav ? "已收藏" : "收藏";
    favBtn.classList.toggle("active", isFav);
  }

  if (isFavoritesOnlyFilter) {
    renderFavoritesGrid();
  }
}

function renderFavoritesGrid() {
  const favs = getFavorites();
  renderGrid(favs);
}

function setupFavorites() {
  const filterBtn = document.getElementById("fav-filter-btn");
  if (filterBtn) {
    filterBtn.addEventListener("click", () => {
      isFavoritesOnlyFilter = !isFavoritesOnlyFilter;
      filterBtn.classList.toggle("active", isFavoritesOnlyFilter);
      if (isFavoritesOnlyFilter) {
        showSleepToast("篩選模式：我的收藏");
        applyFilters();
      } else {
        showSleepToast("已切換回完整集數清單");
        applyFilters();
      }
    });
  }

  const favBtn = document.getElementById("fav-btn");
  if (favBtn) {
    favBtn.addEventListener("click", () => {
      if (activeEpisode) {
        toggleFavorite(activeEpisode);
      }
    });
  }

  updateFavoritesUI();
}

// Watch History Modal Controller (Feature 7)
function openHistoryModal() {
  if (typeof document === "undefined") return;
  const modal = document.getElementById("history-modal");
  if (!modal) return;
  renderHistoryModal();
  setDialogState(modal, true, "flex");
  modal.setAttribute("aria-hidden", "false");
}

function closeHistoryModal() {
  if (typeof document === "undefined") return;
  const modal = document.getElementById("history-modal");
  if (!modal) return;
  setDialogState(modal, false);
  modal.setAttribute("aria-hidden", "true");
}

function renderHistoryModal() {
  if (typeof document === "undefined") return;
  const container = document.getElementById("history-list-container");
  if (!container) return;
  const records = getHistoryRecords();
  const countBadge = document.getElementById("history-count-badge");
  if (countBadge) {
    countBadge.textContent = `${records.length} 部`;
  }

  if (records.length === 0) {
    container.innerHTML = `
      <div class="yt-history-empty">
        <svg viewBox="0 0 24 24" width="48" height="48" fill="none" stroke="currentColor" stroke-width="1.5">
          <circle cx="12" cy="12" r="10"/>
          <polyline points="12 6 12 12 16 14"/>
        </svg>
        <p style="font-size:1rem; font-weight:600; color:#fff; margin-bottom:4px;">尚無觀看歷史紀錄</p>
        <p style="font-size:0.85rem; color:#888;">播放任何精彩節目，將在此紀錄中斷點與進度。</p>
      </div>
    `;
    return;
  }

  container.innerHTML = records.map(rec => {
    const title = rec.title || rec.episodeId;
    const thumb = rec.thumbnail || "./placeholder.jpg";
    const partLabel = rec.partLabel || `Part ${(rec.partIndex || 0) + 1}`;
    const progress = rec.percentage || 0;
    const timeText = `${formatTime(rec.currentTime)} / ${formatTime(rec.duration)} (${progress}%)`;
    const dateStr = rec.updatedAt ? new Date(rec.updatedAt).toLocaleDateString("zh-TW", { month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" }) : "";
    const showName = rec.showName || "綜藝玩很大";

    return `
      <div class="yt-history-item" data-episode-id="${rec.episodeId}" data-part-index="${rec.partIndex || 0}">
        <div class="yt-history-thumb-wrapper">
          <img src="${thumb}" alt="${title}" width="112" height="63" loading="lazy" onerror="this.src='./placeholder.jpg'">
          <div class="yt-history-progress-fill" style="width: ${progress}%;"></div>
        </div>
        <div class="yt-history-info">
          <div class="yt-history-show-badge">${showName}</div>
          <div class="yt-history-title" title="${title}">${title}</div>
          <div class="yt-history-meta">
            <span class="yt-history-part-pill">${partLabel}</span>
            <span>${timeText}</span>
            <span style="margin-left:auto; font-size:0.7rem; color:#666;">${dateStr}</span>
          </div>
        </div>
        <button class="yt-history-delete-btn" data-del-id="${rec.episodeId}" aria-label="刪除歷史紀錄" title="刪除紀錄">✕</button>
      </div>
    `;
  }).join("");

  // Attach click listeners to resume episode
  container.querySelectorAll(".yt-history-item").forEach(item => {
    item.addEventListener("click", (e) => {
      if (e.target.closest(".yt-history-delete-btn")) return;
      const epId = item.getAttribute("data-episode-id");
      const partIdx = parseInt(item.getAttribute("data-part-index") || "0", 10);
      closeHistoryModal();
      const targetEp = (catalog && Array.isArray(catalog.episodes))
        ? catalog.episodes.find(ep => ep.id === epId)
        : null;
      if (targetEp) {
        selectEpisode(targetEp, partIdx);
      }
    });
  });

  // Attach delete buttons
  container.querySelectorAll(".yt-history-delete-btn").forEach(btn => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const epId = btn.getAttribute("data-del-id");
      clearEpisodeResume(epId);
      renderHistoryModal();
    });
  });
}

function setupHistory() {
  if (typeof document === "undefined") return;
  const historyBtn = document.getElementById("history-btn");
  if (historyBtn) {
    historyBtn.addEventListener("click", openHistoryModal);
  }

  const closeBtn = document.getElementById("history-modal-close");
  if (closeBtn) {
    closeBtn.addEventListener("click", closeHistoryModal);
  }

  const backdrop = document.getElementById("history-modal-backdrop");
  if (backdrop) {
    backdrop.addEventListener("click", closeHistoryModal);
  }

  const clearAllBtn = document.getElementById("history-clear-all-btn");
  if (clearAllBtn) {
    clearAllBtn.addEventListener("click", () => {
      if (confirm("確定要清空所有觀看歷史紀錄嗎？此操作將清除所有集數的播放進度。")) {
        clearAllHistory();
        renderHistoryModal();
      }
    });
  }

  updateHistoryBadge();
}

// Screen Lock & Anti-Touch Controller (Feature 8)
let isScreenLocked = false;
let unlockOverlayTimer = null;

function toggleScreenLock() {
  if (isScreenLocked) {
    unlockScreen();
  } else {
    lockScreen();
  }
}

function lockScreen() {
  isScreenLocked = true;
  const playerContainer = document.getElementById("player-container");
  if (playerContainer) {
    playerContainer.classList.add("player-screen-locked");
  }
  const label = document.getElementById("screen-lock-label");
  if (label) label.textContent = "已鎖定";
  const icon = document.getElementById("screen-lock-icon");
  if (icon) icon.textContent = "🔒";
  const lockBtn = document.getElementById("screen-lock-btn");
  if (lockBtn) lockBtn.classList.add("active");

  showUnlockOverlay();
  showSleepToast("🔒 螢幕已鎖定防誤觸");
}

function unlockScreen() {
  isScreenLocked = false;
  clearTimeout(unlockOverlayTimer);
  const playerContainer = document.getElementById("player-container");
  if (playerContainer) {
    playerContainer.classList.remove("player-screen-locked");
  }
  const overlay = document.getElementById("screen-unlock-overlay");
  if (overlay) overlay.style.display = "none";
  const label = document.getElementById("screen-lock-label");
  if (label) label.textContent = "鎖定";
  const icon = document.getElementById("screen-lock-icon");
  if (icon) icon.textContent = "🔒";
  const lockBtn = document.getElementById("screen-lock-btn");
  if (lockBtn) lockBtn.classList.remove("active");

  showSleepToast("🔓 螢幕已解鎖");
}

function showUnlockOverlay() {
  if (typeof document === "undefined") return;
  const overlay = document.getElementById("screen-unlock-overlay");
  if (!overlay) return;
  clearTimeout(unlockOverlayTimer);
  overlay.style.display = "flex";
  unlockOverlayTimer = setTimeout(() => {
    if (isScreenLocked && overlay) {
      overlay.style.display = "none";
    }
  }, 3000);
}

function setupScreenLock() {
  if (typeof document === "undefined") return;
  const lockBtn = document.getElementById("screen-lock-btn");
  if (lockBtn) {
    lockBtn.addEventListener("click", () => {
      toggleScreenLock();
    });
  }

  const unlockBtn = document.getElementById("screen-unlock-btn");
  if (unlockBtn) {
    unlockBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      unlockScreen();
    });
  }

  const playerContainer = document.getElementById("player-container");
  if (playerContainer) {
    playerContainer.addEventListener("click", (e) => {
      if (isScreenLocked && !e.target.closest("#screen-unlock-btn")) {
        showUnlockOverlay();
      }
    });
  }
}

// Auto-Play Next Part/Episode State Machine & HUD
function getNextPlayTarget() {
  if (!activeEpisode) return null;
  if (activeEpisode.parts && activePartIndex < activeEpisode.parts.length - 1) {
    const nextPart = activeEpisode.parts[activePartIndex + 1];
    return {
      type: "part",
      title: `下一段：${nextPart.label || `Part ${activePartIndex + 2}`}`,
      episode: activeEpisode,
      partIndex: activePartIndex + 1,
    };
  }
  // Check next episode in catalog
  const eps = catalog?.episodes || [];
  const curIdx = eps.findIndex(e => e.id === activeEpisode.id);
  if (curIdx >= 0 && curIdx + 1 < eps.length) {
    const nextEp = eps[curIdx + 1];
    return {
      type: "episode",
      title: `下一集：${nextEp.title}`,
      episode: nextEp,
      partIndex: 0,
    };
  }
  return null;
}

function startAutoPlayCountdown() {
  if (!autoPlayNextEnabled || isScreenLocked || autoPlayDismissed || autoPlayTimer) return;
  const target = getNextPlayTarget();
  if (!target) return;

  const card = document.getElementById("autoplay-next-card");
  const numEl = document.getElementById("ap-countdown-num");
  const titleEl = document.getElementById("ap-next-title");
  const circleEl = document.getElementById("ap-circle-progress");
  if (!card) return;

  if (titleEl) titleEl.textContent = target.title;
  autoPlayCountdown = 5;
  if (numEl) numEl.textContent = "5";
  if (circleEl) circleEl.setAttribute("stroke-dasharray", "100, 100");
  setDialogState(card, true, "flex");

  if (autoPlayTimer) clearInterval(autoPlayTimer);
  autoPlayTimer = setInterval(() => {
    autoPlayCountdown--;
    if (numEl) numEl.textContent = String(Math.max(0, autoPlayCountdown));
    if (circleEl) {
      const pct = Math.max(0, (autoPlayCountdown / 5) * 100);
      circleEl.setAttribute("stroke-dasharray", `${pct}, 100`);
    }

    if (autoPlayCountdown <= 0) {
      clearInterval(autoPlayTimer);
      autoPlayTimer = null;
      proceedAutoPlayNext();
    }
  }, 1000);
}

function cancelAutoPlay(permanent = true) {
  if (autoPlayTimer) {
    clearInterval(autoPlayTimer);
    autoPlayTimer = null;
  }
  const card = document.getElementById("autoplay-next-card");
  setDialogState(card, false);
  if (permanent) {
    autoPlayDismissed = true;
  }
}

function proceedAutoPlayNext() {
  const target = getNextPlayTarget();
  cancelAutoPlay(false);
  if (target) {
    if (playerStreamStatus) playerStreamStatus.textContent = `自動為您播放：${target.title}...`;
    playPart(target.episode, target.partIndex, true, true);
  } else {
    if (playerStreamStatus) playerStreamStatus.textContent = "全集播放完畢";
  }
}

function toggleAutoPlay() {
  autoPlayNextEnabled = !autoPlayNextEnabled;
  try {
    localStorage.setItem("dtv_autoplay_next", autoPlayNextEnabled ? "true" : "false");
  } catch (_) {}
  updateAutoPlayBtn();
  if (!autoPlayNextEnabled) {
    cancelAutoPlay(true);
  }
}

function updateAutoPlayBtn() {
  const labelEl = document.getElementById("autoplay-toggle-label");
  const iconEl = document.getElementById("autoplay-toggle-icon");
  const btn = document.getElementById("autoplay-toggle-btn");
  if (labelEl) {
    labelEl.textContent = autoPlayNextEnabled ? "連播: 開" : "連播: 關";
  }
  if (iconEl) {
    iconEl.textContent = autoPlayNextEnabled ? "⚡" : "⏸";
  }
  if (btn) {
    btn.style.color = autoPlayNextEnabled ? "#e50914" : "#ffffff";
  }
}

function setupAutoPlay() {
  updateAutoPlayBtn();
  const toggleBtn = document.getElementById("autoplay-toggle-btn");
  if (toggleBtn) {
    toggleBtn.addEventListener("click", () => toggleAutoPlay());
  }
  const playBtn = document.getElementById("ap-play-btn");
  if (playBtn) {
    playBtn.addEventListener("click", () => proceedAutoPlayNext());
  }
  const cancelBtn = document.getElementById("ap-cancel-btn");
  if (cancelBtn) {
    cancelBtn.addEventListener("click", () => cancelAutoPlay(true));
  }
}

// Audio-Only Radio Mode Controller (Feature 11)
function updateRadioView() {
  if (!isBrowser) return;
  const overlay = document.getElementById("radio-mode-overlay");
  const coverImg = document.getElementById("radio-cover-img");
  const titleEl = document.getElementById("radio-ep-title");
  const subEl = document.getElementById("radio-ep-sub");
  const vinyl = document.getElementById("radio-vinyl-disc");
  const wave = document.getElementById("radio-waveform-bars");
  const playBtn = document.getElementById("radio-play-btn");
  const labelEl = document.getElementById("radio-mode-label");
  const iconEl = document.getElementById("radio-mode-icon");
  const radioBtn = document.getElementById("radio-mode-btn");

  if (overlay) {
    overlay.style.display = isAudioOnlyMode ? "flex" : "none";
  }

  if (labelEl) {
    labelEl.textContent = isAudioOnlyMode ? "聽劇中" : "聽劇模式";
  }
  if (iconEl) {
    iconEl.textContent = "🎧";
  }
  if (radioBtn) {
    radioBtn.style.color = isAudioOnlyMode ? "#e50914" : "";
    radioBtn.classList.toggle("active", isAudioOnlyMode);
  }

  if (activeEpisode) {
    if (titleEl) titleEl.textContent = activeEpisode.title || "綜藝玩很大";
    const part = activeEpisode.parts?.[activePartIndex];
    const partLabel = part?.label || `Part ${activePartIndex + 1}`;
    if (subEl) subEl.textContent = `${activeEpisode.date || "最新"} · ${partLabel} · 綜藝玩很大`;
    if (coverImg) {
      coverImg.src = resolveEpisodeThumb(activeEpisode);
    }
  }

  const isPlaying = player && !player.paused;
  if (vinyl) vinyl.classList.toggle("playing", isPlaying && isAudioOnlyMode);
  if (wave) wave.classList.toggle("playing", isPlaying && isAudioOnlyMode);
  if (playBtn) playBtn.textContent = isPlaying ? "⏸" : "▶";
}

function toggleAudioOnlyMode() {
  isAudioOnlyMode = !isAudioOnlyMode;
  updateRadioView();
  showSleepToast(isAudioOnlyMode ? "🎧 已開啟純音頻聽劇模式 (70%+ 極致省電)" : "📺 已返回視訊播放模式");
}

function setupRadioMode() {
  const radioBtn = document.getElementById("radio-mode-btn");
  if (radioBtn) {
    radioBtn.addEventListener("click", () => toggleAudioOnlyMode());
  }

  const returnBtn = document.getElementById("radio-return-btn");
  if (returnBtn) {
    returnBtn.addEventListener("click", () => toggleAudioOnlyMode());
  }

  const back15 = document.getElementById("radio-back-15");
  if (back15) {
    back15.addEventListener("click", () => {
      if (player) {
        player.currentTime = Math.max(0, player.currentTime - 15);
      }
    });
  }

  const fwd15 = document.getElementById("radio-fwd-15");
  if (fwd15) {
    fwd15.addEventListener("click", () => {
      if (player) {
        player.currentTime = Math.min(player.duration || 0, player.currentTime + 15);
      }
    });
  }

  const playBtn = document.getElementById("radio-play-btn");
  if (playBtn) {
    playBtn.addEventListener("click", () => {
      if (!player) return;
      if (player.paused) {
        player.play().catch(() => {});
      } else {
        player.pause();
      }
      updateRadioView();
    });
  }

  if (player) {
    player.addEventListener("play", () => updateRadioView());
    player.addEventListener("pause", () => updateRadioView());
  }
}

// Skip Intro & Stall Fallback Controller (Feature 12)
function showStallCard() {
  if (!isBrowser) return;
  const card = document.getElementById("stall-fallback-card");
  if (card && !isScreenLocked) {
    card.style.display = "flex";
    stallHudVisible = true;
  }
}

function hideStallCard() {
  if (!isBrowser) return;
  clearTimeout(stallWatchdogTimer);
  const card = document.getElementById("stall-fallback-card");
  if (card) {
    card.style.display = "none";
    stallHudVisible = false;
  }
}

function skipIntro() {
  if (!player) return;
  const dur = player.duration || 999999;
  player.currentTime = Math.min(dur, player.currentTime + 30);
  skipIntroDismissed = true;
  const skipIntroBtn = document.getElementById("skip-intro-btn");
  if (skipIntroBtn) skipIntroBtn.style.display = "none";
  showSleepToast("⏩ 已為您跳過片頭 30 秒");
}

function reloadStallFallback() {
  hideStallCard();
  const currentPart = activeEpisode?.parts?.[activePartIndex];
  if (currentPart?.url && player && window.location.protocol.startsWith("http")) {
    const freshStream = `/api/stream?pageUrl=${encodeURIComponent(currentPart.url)}&refresh=true`;
    player.src = freshStream;
    try { player.load(); } catch (_) {}
    player.play().catch(() => {});
    showSleepToast("⚡ 正在為您切換備用播放線路...");
    return;
  }
  if (player && activeEpisode) {
    playPart(activeEpisode, activePartIndex, true, true);
    showSleepToast("⚡ 重新整理目前串流線路...");
  }
}

function setupSkipIntroAndStall() {
  const skipBtn = document.getElementById("skip-intro-btn");
  if (skipBtn) {
    skipBtn.addEventListener("click", () => skipIntro());
  }

  const reloadBtn = document.getElementById("stall-reload-btn");
  if (reloadBtn) {
    reloadBtn.addEventListener("click", () => reloadStallFallback());
  }

  const closeBtn = document.getElementById("stall-close-btn");
  if (closeBtn) {
    closeBtn.addEventListener("click", () => hideStallCard());
  }
}

// Initialization on DOMContentLoaded
if (typeof window !== "undefined") {
  window.addEventListener("DOMContentLoaded", () => {
    initPlayer();
    initPlaybackSpeed();
    setupQuickSkipButtons();
    setupShortcuts();
    setupDownloadActions();
    setupShareModal();
    setupDoubleTapSeek();
    setupVerticalSwipe();
    setupScaleMode();
    setupPressAndHold2x();
    setupFavorites();
    setupHistory();
    setupScreenLock();
    setupAutoPlay();
    setupSleepTimerModal();
    setupSearchAndFilters();
    setupRadioMode();
    setupSkipIntroAndStall();
    setupChannelPicker();
    setupPlayerCollapse();
    loadCatalog();
  });
}

// Exports for testing & window exposure
if (typeof window !== "undefined") {
  window.initPlayer = initPlayer;
  window.loadCatalog = loadCatalog;
  window.playPart = playPart;
  window.renderGrid = renderGrid;
  window.handleSearch = handleSearch;
  window.applyFilters = applyFilters;
  window.matchesYear = matchesYear;
  window.compareEpisodes = compareEpisodes;
  window.setYearFilter = setYearFilter;
  window.toggleSortOrder = toggleSortOrder;
  window.getSearchHistory = getSearchHistory;
  window.addSearchHistory = addSearchHistory;
  window.removeSearchHistory = removeSearchHistory;
  window.clearSearchHistory = clearSearchHistory;
  window.setupSearchAndFilters = setupSearchAndFilters;
  window.DEFAULT_HOT_TAGS = DEFAULT_HOT_TAGS;
  window.SEARCH_HISTORY_KEY = SEARCH_HISTORY_KEY;
  window.resolveStreamUrl = resolveStreamUrl;
  window.resolveDirectStream = resolveDirectStream;
  window.getDownloadFilename = getDownloadFilename;
  window.downloadEpisodePart = downloadEpisodePart;
  window.setupDownloadActions = setupDownloadActions;
  window.getShareUrl = getShareUrl;
  window.openShareModal = openShareModal;
  window.closeShareModal = closeShareModal;
  window.setupShareModal = setupShareModal;
  window.triggerDoubleTapSeek = triggerDoubleTapSeek;
  window.setupDoubleTapSeek = setupDoubleTapSeek;
  window.updateBrightness = updateBrightness;
  window.updateVolume = updateVolume;
  window.setupVerticalSwipe = setupVerticalSwipe;
  window.cycleScaleMode = cycleScaleMode;
  window.setupScaleMode = setupScaleMode;
  window.setupPressAndHold2x = setupPressAndHold2x;
  window.getFavorites = getFavorites;
  window.isFavorite = isFavorite;
  window.toggleFavorite = toggleFavorite;
  window.setupFavorites = setupFavorites;
  window.getHistoryRecords = getHistoryRecords;
  window.openHistoryModal = openHistoryModal;
  window.closeHistoryModal = closeHistoryModal;
  window.renderHistoryModal = renderHistoryModal;
  window.clearAllHistory = clearAllHistory;
  window.setupHistory = setupHistory;
  window.toggleScreenLock = toggleScreenLock;
  window.lockScreen = lockScreen;
  window.unlockScreen = unlockScreen;
  window.setupScreenLock = setupScreenLock;
  window.getNextPlayTarget = getNextPlayTarget;
  window.startAutoPlayCountdown = startAutoPlayCountdown;
  window.cancelAutoPlay = cancelAutoPlay;
  window.proceedAutoPlayNext = proceedAutoPlayNext;
  window.toggleAutoPlay = toggleAutoPlay;
  window.setupAutoPlay = setupAutoPlay;
  window.setSleepTimer = setSleepTimer;
  window.setupSleepTimerModal = setupSleepTimerModal;
  window.saveResume = saveResume;
  window.getEpisodeResume = getEpisodeResume;
  window.clearEpisodeResume = clearEpisodeResume;
  window.toggleAudioOnlyMode = toggleAudioOnlyMode;
  window.setupRadioMode = setupRadioMode;
  window.updateRadioView = updateRadioView;
  window.skipIntro = skipIntro;
  window.showStallCard = showStallCard;
  window.hideStallCard = hideStallCard;
  window.reloadStallFallback = reloadStallFallback;
  window.setupSkipIntroAndStall = setupSkipIntroAndStall;
  window.formatTime = formatTime;
  window.loadNextPage = loadNextPage;
  window.applyPlaybackSpeed = applyPlaybackSpeed;
  window.cycleSpeed = cycleSpeed;
  window.seekRelative = seekRelative;
  window.SPEED_STEPS = SPEED_STEPS;
  window.STORAGE_KEY = STORAGE_KEY;
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    loadCatalog,
    loadNextPage,
    playPart,
    renderGrid,
    handleSearch,
    applyFilters,
    matchesYear,
    compareEpisodes,
    setYearFilter,
    toggleSortOrder,
    getSearchHistory,
    addSearchHistory,
    removeSearchHistory,
    clearSearchHistory,
    setupSearchAndFilters,
    DEFAULT_HOT_TAGS,
    SEARCH_HISTORY_KEY,
    resolveStreamUrl,
    resolveDirectStream,
    getDownloadFilename,
    downloadEpisodePart,
    setupDownloadActions,
    getShareUrl,
    openShareModal,
    closeShareModal,
    setupShareModal,
    triggerDoubleTapSeek,
    setupDoubleTapSeek,
    updateBrightness,
    updateVolume,
    setupVerticalSwipe,
    cycleScaleMode,
    setupScaleMode,
    setupPressAndHold2x,
    getFavorites,
    isFavorite,
    toggleFavorite,
    setupFavorites,
    getHistoryRecords,
    openHistoryModal,
    closeHistoryModal,
    renderHistoryModal,
    clearAllHistory,
    setupHistory,
    toggleScreenLock,
    lockScreen,
    unlockScreen,
    setupScreenLock,
    getNextPlayTarget,
    startAutoPlayCountdown,
    cancelAutoPlay,
    proceedAutoPlayNext,
    toggleAutoPlay,
    setupAutoPlay,
    setSleepTimer,
    setupSleepTimerModal,
    saveResume,
    getEpisodeResume,
    clearEpisodeResume,
    toggleAudioOnlyMode,
    setupRadioMode,
    updateRadioView,
    skipIntro,
    showStallCard,
    hideStallCard,
    reloadStallFallback,
    setupSkipIntroAndStall,
    formatTime,
    applyPlaybackSpeed,
    cycleSpeed,
    seekRelative,
    SPEED_STEPS,
    STORAGE_KEY
  };
}
