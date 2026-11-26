import fs from "node:fs";
import path from "node:path";
import { generateEpisodeThumbnailSvg } from "./thumbnail-generator.mjs";

const catalog = JSON.parse(fs.readFileSync("tv-web/catalog.json", "utf-8"));

const dirs = [
  "tv-web/media/thumbnails",
  "dist/react/media/thumbnails",
  "dist/tv-web/media/thumbnails"
];

dirs.forEach(d => fs.mkdirSync(d, { recursive: true }));

// 1. Generate default generic thumbnail
const defaultSvg = generateEpisodeThumbnailSvg({
  title: "綜藝玩很大 全新系列",
  date: "最新播出",
  id: "default"
});
fs.writeFileSync("tv-web/media/thumb-default.svg", defaultSvg, "utf-8");

// 2. Generate per-episode SVGs for the 10 catalog episodes
catalog.episodes.forEach((ep) => {
  const dateSlug = ep.date.replace(/-/g, "");
  const filename = `ep-${dateSlug}.svg`;
  const svg = generateEpisodeThumbnailSvg({
    title: ep.title,
    date: ep.date,
    id: ep.id
  });

  dirs.forEach(d => {
    fs.writeFileSync(path.join(d, filename), svg, "utf-8");
  });
  console.log(`Generated thumbnail: ${filename} for ${ep.title}`);
});

console.log("Static thumbnails successfully generated.");
