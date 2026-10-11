import { describe, it, expect } from "vitest";
import { createCache, serializeCache, deserializeCache, shouldRefresh } from "../src/cache.js";
import type { Episode } from "../src/parser.js";

const eps: Episode[] = [
  { id: "https://srgoideas.com/ep1/", title: "綜藝玩很大 2026-10-04", date: "2026-10-04", url: "https://srgoideas.com/ep1/" },
];

describe("cache roundtrip", () => {
  it("saves and loads episodes with timestamp", () => {
    const json = serializeCache(createCache(eps, "2026-10-11T00:00:00Z"));
    const loaded = deserializeCache(json);
    expect(loaded.episodes).toHaveLength(1);
    expect(loaded.updatedAt).toBe("2026-10-11T00:00:00Z");
    expect(loaded.error).toBeUndefined();
  });

  it("keeps error flag instead of throwing on bad json", () => {
    const loaded = deserializeCache("not-json{{{");
    expect(loaded.episodes).toEqual([]);
    expect(loaded.error).toBeTruthy();
  });
});

describe("shouldRefresh", () => {
  it("requests refresh when TTL expired", () => {
    expect(shouldRefresh("2026-10-11T00:00:00Z", 1000, Date.parse("2026-10-11T00:00:02Z"))).toBe(true);
  });

  it("skips refresh within TTL", () => {
    expect(shouldRefresh("2026-10-11T00:00:00Z", 60_000, Date.parse("2026-10-11T00:00:01Z"))).toBe(false);
  });
});
