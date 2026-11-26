export interface EpisodePart {
  label: string;
  streamUrl?: string;
  url?: string;
  duration?: string;
}

export interface EpisodeItem {
  id: string;
  title: string;
  date: string;
  url: string;
  showId?: string;
  showName?: string;
  duration?: string;
  poster?: string;
  parts: EpisodePart[];
}

export interface ShowChannelMeta {
  id: string;
  name: string;
  englishName: string;
  emoji: string;
  tagline: string;
  fallbackEpisodes: EpisodeItem[];
}

export const LATEST_APK_RELEASE_URL =
  "https://github.com/dylansalim3/dTVSteams/releases/latest";

export const YEAR_OPTIONS = [
  "全部",
  "2026",
  "2025",
  "2024",
  "2023",
  "2022",
  "經典懷舊",
] as const;

export const SHOW_CHANNELS: ShowChannelMeta[] = [
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
        duration: "1小時 48分",
        parts: [
          { label: "Part 1", streamUrl: "./media/sample-part1.mp4", duration: "35分" },
          { label: "Part 2", streamUrl: "./media/sample-part2.mp4", duration: "35分" },
          { label: "Part 3", streamUrl: "./media/sample-part3.mp4", duration: "38分" },
        ],
      },
    ],
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
        duration: "1小時 50分",
        parts: [
          { label: "Part 1", url: "https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/" },
          { label: "Part 2", url: "https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/2/" },
          { label: "Part 3", url: "https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-22-%e9%a3%a2%e9%a4%93%e6%8c%87%e6%95%b8%e7%89%b9%e5%88%a5%e4%bc%81%e5%8a%83/3/" },
        ],
      },
    ],
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
        duration: "1小時 55分",
        parts: [
          { label: "Part 1", url: "https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/" },
          { label: "Part 2", url: "https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/2/" },
          { label: "Part 3", url: "https://srgoideas.com/%e5%85%a8%e6%98%8e%e6%98%9f%e9%81%8b%e5%8b%95%e6%9c%83-2023-01-08/3/" },
        ],
      },
    ],
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
        duration: "45分",
        parts: [
          { label: "Part 1", url: "https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/" },
          { label: "Part 2", url: "https://srgoideas.com/%e5%b0%8f%e6%98%8e%e6%98%9f%e5%a4%a7%e8%b7%9f%e7%8f%ad-2026-11-20/2/" },
        ],
      },
    ],
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
        duration: "45分",
        parts: [
          { label: "Part 1", url: "https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/" },
          { label: "Part 2", url: "https://srgoideas.com/11%e9%bb%9e%e7%86%b1%e5%90%b5%e5%ba%97-2026-11-19/2/" },
        ],
      },
    ],
  },
];

const KNOWN_LOCATIONS = [
  "台北", "新北", "基隆", "桃園", "新竹", "苗栗", "台中", "彰化", "南投", "雲林",
  "嘉義", "台南", "高雄", "屏東", "宜蘭", "花蓮", "台東", "澎湖", "金門", "馬祖",
  "綠島", "蘭嶼", "小琉球", "日本", "韓國", "泰國", "越南", "馬來西亞", "新加坡",
  "峇里島", "沖繩", "北海道", "東京", "大阪", "京都", "首爾", "曼谷", "關西", "紐西蘭",
];

export function extractLocation(title: string): string {
  for (const loc of KNOWN_LOCATIONS) {
    if (title.includes(loc)) return loc;
  }
  return "";
}

export function detectShowChannel(episode: Partial<EpisodeItem>): ShowChannelMeta {
  if (episode.showId) {
    const byId = SHOW_CHANNELS.find((c) => c.id === episode.showId);
    if (byId) return byId;
  }
  const haystack = `${episode.showName || ""} ${episode.title || ""} ${episode.id || ""}`;
  return (
    SHOW_CHANNELS.find((c) => haystack.includes(c.name)) || SHOW_CHANNELS[0]
  );
}

export function stripShowNameFromTitle(title: string, showName: string): string {
  let clean = (title || "").trim();
  if (!clean) return "";
  if (showName) {
    clean = clean
      .replace(new RegExp(`^[【\\[]?\\s*${showName}\\s*[】\\]]?\\s*[-·|:]?\\s*`), "")
      .trim();
  }
  return clean || title;
}

export function matchesYearFilter(ep: EpisodeItem, year: string): boolean {
  if (!year || year === "全部") return true;
  const date = (ep.date || "").trim();
  const title = (ep.title || "").trim();
  if (year === "經典懷舊") {
    const m = date.match(/(20\d\d)/) || title.match(/(20\d\d)/);
    if (m) return parseInt(m[1], 10) <= 2021;
    return false;
  }
  return date.startsWith(year) || title.includes(year);
}
