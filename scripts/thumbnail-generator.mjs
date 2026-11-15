export function generateEpisodeThumbnailSvg({ title = "綜藝玩很大", date = "最新", id = "" } = {}) {
  // Extract location/theme from title: e.g. "綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家" -> "台北 搗蛋鬼到你家"
  let cleanTheme = title.replace(/綜藝玩很大/g, "").replace(/\d{4}-\d{2}-\d{2}/g, "").trim();
  if (!cleanTheme) cleanTheme = "精采對抗賽";

  // Deterministic accent hue based on date or id string for visual variety
  let hash = 0;
  const str = date + cleanTheme;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.charCodeAt(i);
    hash |= 0;
  }
  const colorSchemes = [
    { primary: "#ff0000", secondary: "#ffbb00", bgGrad1: "#2b0a0a", bgGrad2: "#141414", team: "黃隊 VS 黑隊" },
    { primary: "#ffbb00", secondary: "#ff4400", bgGrad1: "#261d05", bgGrad2: "#141414", team: "命運奪壘戰" },
    { primary: "#e50914", secondary: "#ffd700", bgGrad1: "#1f0507", bgGrad2: "#121212", team: "玩很大特輯" },
    { primary: "#ff5500", secondary: "#ffcc00", bgGrad1: "#261205", bgGrad2: "#141414", team: "極限對抗賽" },
    { primary: "#d32f2f", secondary: "#fbc02d", bgGrad1: "#210808", bgGrad2: "#141414", team: "台北搗蛋鬼" }
  ];
  const scheme = colorSchemes[Math.abs(hash) % colorSchemes.length];

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 360" width="640" height="360">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="${scheme.bgGrad1}" />
      <stop offset="60%" stop-color="${scheme.bgGrad2}" />
      <stop offset="100%" stop-color="#0a0a0a" />
    </linearGradient>
    <radialGradient id="glow" cx="20%" cy="30%" r="70%">
      <stop offset="0%" stop-color="${scheme.primary}" stop-opacity="0.35" />
      <stop offset="100%" stop-color="#000000" stop-opacity="0" />
    </radialGradient>
    <linearGradient id="badgeGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="${scheme.primary}" />
      <stop offset="100%" stop-color="${scheme.secondary}" />
    </linearGradient>
    <linearGradient id="textGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ffffff" />
      <stop offset="100%" stop-color="${scheme.secondary}" />
    </linearGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="#000" flood-opacity="0.8"/>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="640" height="360" fill="url(#bgGrad)" />
  <rect width="640" height="360" fill="url(#glow)" />

  <!-- Diagonal Design Accents -->
  <path d="M-50,360 L240,0 L300,0 L10,360 Z" fill="${scheme.primary}" opacity="0.08" />
  <path d="M400,360 L640,60 L640,120 L440,360 Z" fill="${scheme.secondary}" opacity="0.05" />

  <!-- Top Bar: Show Brand & Season Tag -->
  <g transform="translate(28, 28)">
    <!-- Red Logo Box -->
    <rect width="36" height="26" rx="6" fill="#ff0000" filter="url(#shadow)" />
    <polygon points="14,8 14,18 24,13" fill="#ffffff" />
    <!-- Show Name -->
    <text x="46" y="19" font-family="'Noto Sans TC', 'Microsoft JhengHei', sans-serif" font-weight="900" font-size="16" fill="#ffffff" letter-spacing="1">綜藝玩很大</text>
    <text x="142" y="19" font-family="sans-serif" font-weight="700" font-size="12" fill="${scheme.secondary}" letter-spacing="0.5">MR. PLAYER</text>
    
    <!-- Team Tag -->
    <rect x="490" y="2" width="94" height="22" rx="4" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.2)" stroke-width="1" />
    <text x="537" y="17" font-family="'Noto Sans TC', sans-serif" font-weight="700" font-size="11" fill="#ffdd66" text-anchor="middle">${scheme.team}</text>
  </g>

  <!-- Center Decorative Graphics -->
  <g transform="translate(320, 150)" text-anchor="middle">
    <!-- Big Watermark "PLAY" -->
    <text x="0" y="40" font-family="sans-serif" font-weight="900" font-size="96" fill="#ffffff" opacity="0.04" letter-spacing="6">MR.PLAY</text>
  </g>

  <!-- Bottom Details Overlay -->
  <g transform="translate(28, 220)">
    <!-- Date Pill Badge -->
    <rect width="112" height="26" rx="6" fill="url(#badgeGrad)" filter="url(#shadow)" />
    <text x="56" y="18" font-family="sans-serif" font-weight="800" font-size="13" fill="#000000" text-anchor="middle">${date}</text>

    <!-- Location / Episode Theme -->
    <text x="0" y="66" font-family="'Noto Sans TC', 'PingFang TC', 'Microsoft JhengHei', sans-serif" font-weight="900" font-size="28" fill="url(#textGrad)" filter="url(#shadow)">${cleanTheme}</text>

    <!-- Subtitle / Meta Bar -->
    <text x="0" y="96" font-family="'Noto Sans TC', sans-serif" font-weight="600" font-size="13" fill="#aaaaaa">全集 3 分段完整播出 · 1080P 超高畫質</text>
  </g>

  <!-- Right Badges -->
  <g transform="translate(540, 305)">
    <rect width="68" height="24" rx="4" fill="#ff0000" />
    <text x="34" y="16" font-family="sans-serif" font-weight="800" font-size="11" fill="#ffffff" text-anchor="middle">1080P HD</text>
  </g>
</svg>`;
}
