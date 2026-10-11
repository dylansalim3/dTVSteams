import type { Episode } from "./parser.js";

export type CachedCatalog = { updatedAt: string; episodes: Episode[]; error?: string };

export function createCache(episodes: Episode[], updatedAt?: string): CachedCatalog {
  return { updatedAt: updatedAt ?? new Date().toISOString(), episodes };
}

export function serializeCache(cache: CachedCatalog): string {
  return JSON.stringify(cache);
}

export function deserializeCache(json: string): CachedCatalog {
  try {
    const raw = JSON.parse(json) as CachedCatalog;
    if (!Array.isArray(raw.episodes)) return { updatedAt: "", episodes: [], error: "bad-cache" };
    return { updatedAt: raw.updatedAt ?? "", episodes: raw.episodes };
  } catch {
    return { updatedAt: "", episodes: [], error: "bad-json" };
  }
}

export function shouldRefresh(updatedAt: string, ttlMs: number, nowMs = Date.now()): boolean {
  const t = Date.parse(updatedAt);
  if (Number.isNaN(t)) return true;
  return nowMs - t > ttlMs;
}
