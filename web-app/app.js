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
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：播放中 (1080p HD)";
      player.playbackRate = currentSpeed;
    });

    player.addEventListener("seeking", () => {
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：跳轉緩衝中...";
    });

    player.addEventListener("seeked", () => {
      if (playerStreamStatus) playerStreamStatus.textContent = "串流狀態：播放中 (1080p HD)";
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

      if (sleepTimerMode === "end") {
        setSleepTimer("0");
        showSleepToast("睡眠定時已到達（分段播放完畢），播放已暫停");
        return;
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
        <span class="yt-download-item-size">1080p MP4</span>
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

  shareModal.style.display = "flex";
}

function closeShareModal() {
  if (shareModal) shareModal.style.display = "none";
}

function setupShareModal() {
  if (shareBtn) {
    shareBtn.onclick = () => {
      if (activeEpisode) {
        openShareModal(activeEpisode, activePartIndex);
      } else {
        if (playerStreamStatus) playerStreamStatus.textContent = "請先選擇欲分享的集數";
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
    if (modal) modal.style.display = "flex";
  }
  function closeModal() {
    if (modal) modal.style.display = "none";
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
    setupSleepTimerModal();
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
  window.setSleepTimer = setSleepTimer;
  window.setupSleepTimerModal = setupSleepTimerModal;
  window.saveResume = saveResume;
  window.getEpisodeResume = getEpisodeResume;
  window.clearEpisodeResume = clearEpisodeResume;
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
    setSleepTimer,
    setupSleepTimerModal,
    saveResume,
    getEpisodeResume,
    clearEpisodeResume,
    formatTime,
    applyPlaybackSpeed,
    cycleSpeed,
    seekRelative,
    SPEED_STEPS,
    STORAGE_KEY
  };
}
