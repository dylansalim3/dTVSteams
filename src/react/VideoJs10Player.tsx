import React, { useEffect, useRef, useState, useCallback } from "react";
import "@videojs/react/video/skin.css";
import { VideoPlayer, VideoSkin, Video } from "@videojs/react/video";
import { isIosDevice } from "./download.js";

export interface VideoJs10ResumeRecord {
  episodeId: string;
  partIndex: number;
  currentTime: number;
  duration: number;
  percentage: number;
  completed: boolean;
  updatedAt: number;
}

export interface VideoJs10PlayerProps {
  src: string;
  poster?: string;
  title?: string;
  episodeId?: string;
  partIndex?: number;
  autoPlay?: boolean;
  controls?: boolean;
  className?: string;
  style?: React.CSSProperties;
  onEnded?: () => void;
  onTimeUpdate?: (currentTime: number, duration: number) => void;
  onPlay?: () => void;
  onPause?: () => void;
  onError?: (error: any) => void;
  storageKey?: string;
}

const DEFAULT_STORAGE_KEY = "dtv_resume_history";

export function getStoredResume(episodeId: string, storageKey = DEFAULT_STORAGE_KEY): VideoJs10ResumeRecord | null {
  if (typeof localStorage === "undefined" || !episodeId) return null;
  try {
    const raw = localStorage.getItem(storageKey);
    const data = raw ? JSON.parse(raw) : {};
    return data[episodeId] || null;
  } catch {
    return null;
  }
}

export function saveStoredResume(record: VideoJs10ResumeRecord, storageKey = DEFAULT_STORAGE_KEY): void {
  if (typeof localStorage === "undefined" || !record?.episodeId) return;
  try {
    const raw = localStorage.getItem(storageKey);
    const data = raw ? JSON.parse(raw) : {};
    data[record.episodeId] = record;
    localStorage.setItem(storageKey, JSON.stringify(data));
  } catch {}
}

export function clearStoredResume(episodeId: string, storageKey = DEFAULT_STORAGE_KEY): void {
  if (typeof localStorage === "undefined" || !episodeId) return;
  try {
    const raw = localStorage.getItem(storageKey);
    if (!raw) return;
    const data = JSON.parse(raw);
    delete data[episodeId];
    localStorage.setItem(storageKey, JSON.stringify(data));
  } catch {}
}

/**
 * Official Video.js 10 React Player implementation according to:
 * https://videojs.org/docs/guides/installation/react
 *
 * Implements VideoPlayer, VideoSkin, and Video primitives with localStorage playback
 * resume persistence, responsive styling, and fallback support.
 */
export const VideoJs10Player: React.FC<VideoJs10PlayerProps> = ({
  src,
  poster = "./media/thumb-default.svg",
  title = "綜藝玩很大",
  episodeId = "",
  partIndex = 0,
  autoPlay = false,
  controls = false,
  className = "",
  style,
  onEnded,
  onTimeUpdate,
  onPlay,
  onPause,
  onError,
  storageKey = DEFAULT_STORAGE_KEY,
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const prevSrcRef = useRef<string>(src);
  const [resumedNotice, setResumedNotice] = useState<string | null>(null);
  const [hasResumed, setHasResumed] = useState<boolean>(false);
  const lastSaveTimeRef = useRef<number>(0);
  const isIos = isIosDevice();

  // Ensure legacy iOS WebKit inline attributes and reload on src changes
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (isIos) {
      video.setAttribute("webkit-playsinline", "true");
      video.setAttribute("x-webkit-airplay", "allow");
      video.removeAttribute("crossorigin");
    }
    if (prevSrcRef.current !== src) {
      prevSrcRef.current = src;
      if (typeof video.load === "function") {
        video.load();
      }
    }
  }, [src, isIos]);

  // Resume playback on media loaded / mount
  useEffect(() => {
    setHasResumed(false);
    if (!episodeId) return;

    const saved = getStoredResume(episodeId, storageKey);
    if (saved && saved.currentTime > 5 && !saved.completed) {
      if (saved.partIndex === partIndex || saved.partIndex === undefined) {
        const video = videoRef.current;
        if (video) {
          const applyResumeSeek = () => {
            if (!Number.isFinite(video.duration) || video.duration <= 2) return;
            if (saved.currentTime >= video.duration - 2) return;
            // iOS AVPlayer may report seekable.length === 0 at loadedmetadata; defer until canplay
            if (isIos && video.seekable && video.seekable.length === 0) {
              video.addEventListener("canplay", applyResumeSeek, { once: true });
              return;
            }
            try {
              video.currentTime = saved.currentTime;
              setResumedNotice(`已為您自動回到上次觀看時間：${Math.floor(saved.currentTime / 60)}分${Math.floor(saved.currentTime % 60)}秒`);
              setTimeout(() => setResumedNotice(null), 5000);
            } catch {}
          };
          if (video.readyState >= 1) {
            applyResumeSeek();
          } else {
            video.addEventListener("loadedmetadata", applyResumeSeek, { once: true });
          }
        }
      }
    }
  }, [src, episodeId, partIndex, storageKey, isIos]);

  // Handle time updates and periodic resume storage
  const handleTimeUpdate = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;

    const currentTime = video.currentTime;
    const duration = video.duration || 0;

    if (onTimeUpdate) {
      onTimeUpdate(currentTime, duration);
    }

    if (!episodeId || duration <= 0 || isNaN(currentTime) || currentTime < 3) return;

    const now = Date.now();
    if (now - lastSaveTimeRef.current >= 2000) {
      lastSaveTimeRef.current = now;
      const completed = currentTime >= duration - 15;
      saveStoredResume(
        {
          episodeId,
          partIndex,
          currentTime: Math.round(currentTime),
          duration: Math.round(duration),
          percentage: Math.min(100, Math.round((currentTime / duration) * 100)),
          completed,
          updatedAt: now,
        },
        storageKey
      );
    }
  }, [episodeId, partIndex, onTimeUpdate, storageKey]);

  const handleEnded = useCallback(() => {
    const video = videoRef.current;
    if (video && episodeId) {
      const dur = video.duration || 0;
      saveStoredResume(
        {
          episodeId,
          partIndex,
          currentTime: Math.round(dur),
          duration: Math.round(dur),
          percentage: 100,
          completed: true,
          updatedAt: Date.now(),
        },
        storageKey
      );
    }
    if (onEnded) onEnded();
  }, [episodeId, partIndex, onEnded, storageKey]);

  const handleRestart = useCallback(() => {
    const video = videoRef.current;
    if (video) {
      video.currentTime = 0;
      video.play().catch(() => {});
    }
    if (episodeId) {
      clearStoredResume(episodeId, storageKey);
    }
    setResumedNotice(null);
  }, [episodeId, storageKey]);

  return (
    <div
      className={`vjs10-player-container ${className}`}
      style={{
        position: "relative",
        width: "100%",
        maxWidth: "100%",
        aspectRatio: "16 / 9",
        background: "#000",
        borderRadius: "8px",
        overflow: "hidden",
        ...style,
      }}
    >
      <VideoPlayer title={title} poster={poster}>
        <VideoSkin style={{ width: "100%", height: "100%", aspectRatio: "16 / 9" }}>
          <Video
            ref={videoRef}
            src={src}
            poster={poster}
            preload="metadata"
            playsInline
            crossOrigin={isIos ? undefined : "anonymous"}
            autoPlay={autoPlay}
            controls={Boolean(controls)}
            onTimeUpdate={handleTimeUpdate}
            onEnded={handleEnded}
            onPlay={onPlay}
            onPause={onPause}
            onError={onError}
          >
            <a href="https://videojs.org/help" target="_blank" rel="noopener noreferrer">
              Video player not working?
            </a>
          </Video>
        </VideoSkin>
      </VideoPlayer>

      {/* Resume playback toast banner */}
      {resumedNotice && (
        <div
          role="status"
          aria-live="polite"
          style={{
            position: "absolute",
            bottom: "70px",
            left: "24px",
            zIndex: 30,
            background: "rgba(20, 20, 20, 0.92)",
            border: "1px solid rgba(255, 255, 255, 0.2)",
            borderRadius: "8px",
            padding: "8px 16px",
            display: "flex",
            alignItems: "center",
            gap: "12px",
            color: "#fff",
            fontSize: "0.9rem",
            boxShadow: "0 6px 16px rgba(0, 0, 0, 0.6)",
          }}
        >
          <span>{resumedNotice}</span>
          <button
            onClick={handleRestart}
            style={{
              background: "#ff0000",
              color: "#fff",
              border: "none",
              padding: "4px 10px",
              borderRadius: "4px",
              cursor: "pointer",
              fontWeight: 600,
              fontSize: "0.85rem",
            }}
          >
            從頭播放
          </button>
        </div>
      )}
    </div>
  );
};

export default VideoJs10Player;
