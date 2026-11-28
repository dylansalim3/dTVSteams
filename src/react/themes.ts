export type ThemeBrightness = "light" | "dark";

export interface WebThemePalette {
  id: string;
  name: string;
  source: string;
  brightness: ThemeBrightness;
  canvas: string;
  surfaceSecondary: string;
  surfacePrimary: string;
  surfaceRaised: string;
  surfaceSunken: string;
  accent: string;
  onAccent: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  borderSeparator: string;
  borderDefault: string;
}

export interface WebThemePair {
  id: string;
  name: string;
  source: string;
  light: WebThemePalette;
  dark: WebThemePalette;
}

export interface WebSettingsState {
  themeId: string;
  brightness: ThemeBrightness;
  autoPlayNext: boolean;
}

export const WEB_SETTINGS_STORAGE_KEY = "dtv_web_settings";
export const DEFAULT_THEME_ID = "boardui";

const DEFAULT_WEB_SETTINGS: WebSettingsState = {
  themeId: DEFAULT_THEME_ID,
  brightness: "dark",
  autoPlayNext: true,
};

function parseHexRgb(hex: string): [number, number, number] {
  const clean = hex.replace("#", "").trim();
  const num = parseInt(clean, 16);
  return [(num >> 16) & 255, (num >> 8) & 255, num & 255];
}

function rgbToHex(r: number, g: number, b: number): string {
  const clamp = (v: number) => Math.max(0, Math.min(255, Math.round(v)));
  return (
    "#" +
    [clamp(r), clamp(g), clamp(b)]
      .map((v) => v.toString(16).padStart(2, "0"))
      .join("")
  );
}

export function mixHex(hexA: string, hexB: string, t: number): string {
  const [r1, g1, b1] = parseHexRgb(hexA);
  const [r2, g2, b2] = parseHexRgb(hexB);
  return rgbToHex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t);
}

export function relativeLuminance(hex: string): number {
  const [r, g, b] = parseHexRgb(hex).map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function contrastRatio(hexA: string, hexB: string): number {
  const la = relativeLuminance(hexA);
  const lb = relativeLuminance(hexB);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

/** Contrast-safe foreground color when accent is rendered as text/icon on app surfaces. */
export function resolveAccentForeground(palette: WebThemePalette): string {
  const passes = (c: string) =>
    contrastRatio(c, palette.canvas) >= 4.5 &&
    contrastRatio(c, palette.surfaceSecondary) >= 4.5 &&
    contrastRatio(c, palette.surfaceRaised) >= 4.5;

  if (passes(palette.accent)) return palette.accent;
  for (let i = 1; i <= 20; i++) {
    const candidate = mixHex(palette.accent, palette.textPrimary, i / 20);
    if (passes(candidate)) return candidate;
  }
  return palette.textPrimary;
}

export const BOARDUI_DARK: WebThemePalette = {
  id: "boardui",
  name: "BoardUI Crimson (預設)",
  source: "BoardUI",
  brightness: "dark",
  canvas: "#121212",
  surfaceSecondary: "#171717",
  surfacePrimary: "#262626",
  surfaceRaised: "#1B1B1B",
  surfaceSunken: "#0E0E0E",
  accent: "#E50914",
  onAccent: "#FFFFFF",
  textPrimary: "#FAFAFA",
  textSecondary: "#A3A3A3",
  textTertiary: "#737373",
  borderSeparator: "#262626",
  borderDefault: "#404040",
};

export const BOARDUI_LIGHT: WebThemePalette = {
  id: "boardui",
  name: "BoardUI Crimson (預設)",
  source: "BoardUI",
  brightness: "light",
  canvas: "#FFFFFF",
  surfaceSecondary: "#F7F7F7",
  surfacePrimary: "#EBEBEB",
  surfaceRaised: "#FFFFFF",
  surfaceSunken: "#E5E5E5",
  accent: "#E50914",
  onAccent: "#FFFFFF",
  textPrimary: "#0A0A0A",
  textSecondary: "#525252",
  textTertiary: "#737373",
  borderSeparator: "#EBEBEB",
  borderDefault: "#D4D4D4",
};

export const TWENTY_FIRST_DEV_DARK_THEMES: WebThemePalette[] = [
  {
    id: "vercel",
    name: "Vercel",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#000000",
    surfaceSecondary: "#090909",
    surfacePrimary: "#1D1D1D",
    surfaceRaised: "#121212",
    surfaceSunken: "#000000",
    accent: "#FFFFFF",
    onAccent: "#000000",
    textPrimary: "#FFFFFF",
    textSecondary: "#A4A4A4",
    textTertiary: "#828282",
    borderSeparator: "#242424",
    borderDefault: "#474747",
  },
  {
    id: "claude",
    name: "Claude",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#262624",
    surfaceSecondary: "#2E2E2B",
    surfacePrimary: "#1B1B19",
    surfaceRaised: "#252523",
    surfaceSunken: "#191917",
    accent: "#D97757",
    onAccent: "#0A0A0A",
    textPrimary: "#C3C0B6",
    textSecondary: "#B7B5A9",
    textTertiary: "#99978D",
    borderSeparator: "#3E3E38",
    borderDefault: "#53534C",
  },
  {
    id: "supabase",
    name: "Supabase",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#121212",
    surfaceSecondary: "#171717",
    surfacePrimary: "#1F1F1F",
    surfaceRaised: "#1B1B1B",
    surfaceSunken: "#0C0C0C",
    accent: "#006239",
    onAccent: "#DDE8E3",
    textPrimary: "#E2E8F0",
    textSecondary: "#A2A2A2",
    textTertiary: "#838383",
    borderSeparator: "#292929",
    borderDefault: "#474849",
  },
  {
    id: "catppuccin",
    name: "Catppuccin",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#181825",
    surfaceSecondary: "#1E1E2E",
    surfacePrimary: "#292C3C",
    surfaceRaised: "#232434",
    surfaceSunken: "#101018",
    accent: "#CBA6F7",
    onAccent: "#1E1E2E",
    textPrimary: "#CDD6F4",
    textSecondary: "#A6ADC8",
    textTertiary: "#888EA6",
    borderSeparator: "#313244",
    borderDefault: "#4A4C60",
  },
  {
    id: "solar-dusk",
    name: "Solar Dusk",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#1C1917",
    surfaceSecondary: "#292524",
    surfacePrimary: "#201D1A",
    surfaceRaised: "#252120",
    surfaceSunken: "#12100F",
    accent: "#F97316",
    onAccent: "#0A0A0A",
    textPrimary: "#F5F5F4",
    textSecondary: "#A8A29E",
    textTertiary: "#8C8783",
    borderSeparator: "#44403C",
    borderDefault: "#605D59",
  },
  {
    id: "lime-frost",
    name: "Lime Frost",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#020617",
    surfaceSecondary: "#0F172A",
    surfacePrimary: "#1E293B",
    surfaceRaised: "#161F32",
    surfaceSunken: "#01040F",
    accent: "#AFF33E",
    onAccent: "#000000",
    textPrimary: "#F8FAFC",
    textSecondary: "#94A3B8",
    textTertiary: "#778499",
    borderSeparator: "#1E293B",
    borderDefault: "#414A5A",
  },
  {
    id: "ocean-breeze",
    name: "Ocean Breeze",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#0F172A",
    surfaceSecondary: "#1E293B",
    surfacePrimary: "#19212E",
    surfaceRaised: "#1C2535",
    surfaceSunken: "#0A0F1B",
    accent: "#34D399",
    onAccent: "#0F172A",
    textPrimary: "#D1D5DB",
    textSecondary: "#A9ADB5",
    textTertiary: "#8A909A",
    borderSeparator: "#4B5563",
    borderDefault: "#606976",
  },
  {
    id: "doom-64",
    name: "Doom 64",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#1A1A1A",
    surfaceSecondary: "#2A2A2A",
    surfacePrimary: "#252525",
    surfaceRaised: "#282828",
    surfaceSunken: "#111111",
    accent: "#E53935",
    onAccent: "#0A0A0A",
    textPrimary: "#E0E0E0",
    textSecondary: "#A0A0A0",
    textTertiary: "#868686",
    borderSeparator: "#4A4A4A",
    borderDefault: "#626262",
  },
  {
    id: "modern-minimal",
    name: "Modern Minimal",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#171717",
    surfaceSecondary: "#262626",
    surfacePrimary: "#1F1F1F",
    surfaceRaised: "#232323",
    surfaceSunken: "#0F0F0F",
    accent: "#3B82F6",
    onAccent: "#0A0A0A",
    textPrimary: "#E5E5E5",
    textSecondary: "#A3A3A3",
    textTertiary: "#888888",
    borderSeparator: "#404040",
    borderDefault: "#5A5A5A",
  },
  {
    id: "zen-linen",
    name: "Zen Linen",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#141414",
    surfaceSecondary: "#1C1C1C",
    surfacePrimary: "#2A2A2A",
    surfaceRaised: "#222222",
    surfaceSunken: "#0D0D0D",
    accent: "#D1CFC0",
    onAccent: "#363636",
    textPrimary: "#E8E3DA",
    textSecondary: "#BEBAB3",
    textTertiary: "#9A9792",
    borderSeparator: "#2C2C2C",
    borderDefault: "#4A4948",
  },
  {
    id: "claude-amber",
    name: "Claude Amber",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#262624",
    surfaceSecondary: "#2C2C2B",
    surfacePrimary: "#1B1B19",
    surfaceRaised: "#242423",
    surfaceSunken: "#191917",
    accent: "#D97757",
    onAccent: "#141413",
    textPrimary: "#F1F1EF",
    textSecondary: "#B7B5A9",
    textTertiary: "#98978D",
    borderSeparator: "#3E3E38",
    borderDefault: "#5B5B55",
  },
  {
    id: "sage-garden",
    name: "Sage Garden",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#0A0A0A",
    surfaceSecondary: "#121212",
    surfacePrimary: "#1A1A1A",
    surfaceRaised: "#161616",
    surfaceSunken: "#070707",
    accent: "#7C9082",
    onAccent: "#000000",
    textPrimary: "#F5F5F5",
    textSecondary: "#A0A0A0",
    textTertiary: "#818181",
    borderSeparator: "#2A2A2A",
    borderDefault: "#4A4A4A",
  },
  {
    id: "elegant-luxury",
    name: "Elegant Luxury",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#1C1917",
    surfaceSecondary: "#292524",
    surfacePrimary: "#1F1C1A",
    surfaceRaised: "#252120",
    surfaceSunken: "#12100F",
    accent: "#B91C1C",
    onAccent: "#FAF7F5",
    textPrimary: "#F5F5F4",
    textSecondary: "#D6D3D1",
    textTertiary: "#B0ADAB",
    borderSeparator: "#44403C",
    borderDefault: "#605D59",
  },
  {
    id: "twitter",
    name: "Twitter",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#000000",
    surfaceSecondary: "#17181C",
    surfacePrimary: "#181818",
    surfaceRaised: "#17181A",
    surfaceSunken: "#000000",
    accent: "#1C9CF0",
    onAccent: "#0A0A0A",
    textPrimary: "#E7E9EA",
    textSecondary: "#B9BBBC",
    textTertiary: "#959799",
    borderSeparator: "#242628",
    borderDefault: "#434547",
  },
  {
    id: "vintage-paper",
    name: "Vintage Paper",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#2D2621",
    surfaceSecondary: "#3A322C",
    surfacePrimary: "#312B26",
    surfaceRaised: "#362F29",
    surfaceSunken: "#1D1915",
    accent: "#C0A080",
    onAccent: "#2D2621",
    textPrimary: "#ECE5D8",
    textSecondary: "#C5BCAC",
    textTertiary: "#A69E90",
    borderSeparator: "#4A4039",
    borderDefault: "#645A52",
  },
  {
    id: "graphite-mono",
    name: "Graphite Mono",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#171717",
    surfaceSecondary: "#0E0E0E",
    surfacePrimary: "#262626",
    surfaceRaised: "#191919",
    surfaceSunken: "#0F0F0F",
    accent: "#E5E5E5",
    onAccent: "#171717",
    textPrimary: "#FAFAFA",
    textSecondary: "#A1A1A1",
    textTertiary: "#818181",
    borderSeparator: "#262626",
    borderDefault: "#484848",
  },
  {
    id: "amber-slate",
    name: "Amber Slate",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#1A1A1A",
    surfaceSecondary: "#202020",
    surfacePrimary: "#2A2A2A",
    surfaceRaised: "#252525",
    surfaceSunken: "#111111",
    accent: "#DF6035",
    onAccent: "#0A0A0A",
    textPrimary: "#E5E5E5",
    textSecondary: "#BCBCBC",
    textTertiary: "#9A9A9A",
    borderSeparator: "#353535",
    borderDefault: "#515151",
  },
  {
    id: "azure-mono",
    name: "Azure Mono",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#000000",
    surfaceSecondary: "#0F0F0F",
    surfacePrimary: "#181818",
    surfaceRaised: "#131313",
    surfaceSunken: "#000000",
    accent: "#2B65FF",
    onAccent: "#FFFFFF",
    textPrimary: "#FFFFFF",
    textSecondary: "#CCCCCC",
    textTertiary: "#A2A2A2",
    borderSeparator: "#26272E",
    borderDefault: "#494A4F",
  },
  {
    id: "t3-chat",
    name: "T3 Chat",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#221D27",
    surfaceSecondary: "#2C2632",
    surfacePrimary: "#28222D",
    surfaceRaised: "#2A2430",
    surfaceSunken: "#161319",
    accent: "#A3004C",
    onAccent: "#EFC0D8",
    textPrimary: "#D2C4DE",
    textSecondary: "#C2B6CF",
    textTertiary: "#A196AC",
    borderSeparator: "#3B3237",
    borderDefault: "#534952",
  },
  {
    id: "indigo-mono",
    name: "Indigo Mono",
    source: "21st.dev",
    brightness: "dark",
    canvas: "#000000",
    surfaceSecondary: "#181818",
    surfacePrimary: "#1D1D1D",
    surfaceRaised: "#1A1A1A",
    surfaceSunken: "#000000",
    accent: "#3F5EC2",
    onAccent: "#EFF6FF",
    textPrimary: "#FFFFFF",
    textSecondary: "#A4A4A4",
    textTertiary: "#858585",
    borderSeparator: "#242424",
    borderDefault: "#474747",
  },
];

export const TWENTY_FIRST_DEV_LIGHT_THEMES: WebThemePalette[] = [
  {
    id: "vercel",
    name: "Vercel",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FCFCFC",
    surfaceSecondary: "#F5F5F5",
    surfacePrimary: "#EBEBEB",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E4E4E4",
    accent: "#000000",
    onAccent: "#FFFFFF",
    textPrimary: "#000000",
    textSecondary: "#525252",
    textTertiary: "#6B6B6B",
    borderSeparator: "#E4E4E4",
    borderDefault: "#CCCCCC",
  },
  {
    id: "claude",
    name: "Claude",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FAF9F5",
    surfaceSecondary: "#F2EFE6",
    surfacePrimary: "#E9E6DC",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E2DED2",
    accent: "#C96442",
    onAccent: "#0A0A0A",
    textPrimary: "#3D3929",
    textSecondary: "#5E5D57",
    textTertiary: "#73726C",
    borderSeparator: "#DAD9D4",
    borderDefault: "#B4B2A7",
  },
  {
    id: "supabase",
    name: "Supabase",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FCFCFC",
    surfaceSecondary: "#F4F4F4",
    surfacePrimary: "#EDEDED",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E4E4E4",
    accent: "#72E3AD",
    onAccent: "#1E2723",
    textPrimary: "#171717",
    textSecondary: "#4A4A4A",
    textTertiary: "#6B6B6B",
    borderSeparator: "#DFDFDF",
    borderDefault: "#C7C7C7",
  },
  {
    id: "catppuccin",
    name: "Catppuccin",
    source: "21st.dev",
    brightness: "light",
    canvas: "#EFF1F5",
    surfaceSecondary: "#E6E9EF",
    surfacePrimary: "#DCE0E8",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#CCD0DA",
    accent: "#8839EF",
    onAccent: "#FFFFFF",
    textPrimary: "#4C4F69",
    textSecondary: "#51546E",
    textTertiary: "#6C6F85",
    borderSeparator: "#BCC0CC",
    borderDefault: "#ACB0BE",
  },
  {
    id: "solar-dusk",
    name: "Solar Dusk",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FDFBF7",
    surfaceSecondary: "#F8F4EE",
    surfacePrimary: "#F1E9DA",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E7DEC8",
    accent: "#B45309",
    onAccent: "#FFFFFF",
    textPrimary: "#4A3B33",
    textSecondary: "#5C5652",
    textTertiary: "#78716C",
    borderSeparator: "#E4D9BC",
    borderDefault: "#CBBFA0",
  },
  {
    id: "lime-frost",
    name: "Lime Frost",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FBFCF8",
    surfaceSecondary: "#F1F5F9",
    surfacePrimary: "#E6ECF2",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#DCE3EC",
    accent: "#AFF33E",
    onAccent: "#000000",
    textPrimary: "#0F172A",
    textSecondary: "#475569",
    textTertiary: "#64748B",
    borderSeparator: "#E2E8F0",
    borderDefault: "#CBD5E1",
  },
  {
    id: "ocean-breeze",
    name: "Ocean Breeze",
    source: "21st.dev",
    brightness: "light",
    canvas: "#F0F8FF",
    surfaceSecondary: "#E6F2FC",
    surfacePrimary: "#DCECF8",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#D0E3F3",
    accent: "#22C55E",
    onAccent: "#0A0A0A",
    textPrimary: "#1F2937",
    textSecondary: "#4B5563",
    textTertiary: "#6B7280",
    borderSeparator: "#D1DFEC",
    borderDefault: "#B8CCE0",
  },
  {
    id: "doom-64",
    name: "Doom 64",
    source: "21st.dev",
    brightness: "light",
    canvas: "#E6E6E6",
    surfaceSecondary: "#DCDCDC",
    surfacePrimary: "#D0D0D0",
    surfaceRaised: "#F0F0F0",
    surfaceSunken: "#C4C4C4",
    accent: "#B71C1C",
    onAccent: "#FFFFFF",
    textPrimary: "#1F1F1F",
    textSecondary: "#3D3D3D",
    textTertiary: "#555555",
    borderSeparator: "#B0B0B0",
    borderDefault: "#8F8F8F",
  },
  {
    id: "modern-minimal",
    name: "Modern Minimal",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FFFFFF",
    surfaceSecondary: "#F9FAFB",
    surfacePrimary: "#F1F3F5",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E5E7EB",
    accent: "#2563EB",
    onAccent: "#FFFFFF",
    textPrimary: "#1F2937",
    textSecondary: "#4B5563",
    textTertiary: "#6B7280",
    borderSeparator: "#E5E7EB",
    borderDefault: "#D1D5DB",
  },
  {
    id: "zen-linen",
    name: "Zen Linen",
    source: "21st.dev",
    brightness: "light",
    canvas: "#EFECE4",
    surfaceSecondary: "#E6E1D5",
    surfacePrimary: "#DCD6C6",
    surfaceRaised: "#F7F4EC",
    surfaceSunken: "#CFC8B8",
    accent: "#2E2E2E",
    onAccent: "#F4EFE4",
    textPrimary: "#1E1E1E",
    textSecondary: "#4A463F",
    textTertiary: "#5E5A52",
    borderSeparator: "#D2CBBB",
    borderDefault: "#B8B09E",
  },
  {
    id: "claude-amber",
    name: "Claude Amber",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FAF9F5",
    surfaceSecondary: "#F3F1EA",
    surfacePrimary: "#E9E6DC",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E1DDD1",
    accent: "#C96442",
    onAccent: "#0A0A0A",
    textPrimary: "#3D3929",
    textSecondary: "#595853",
    textTertiary: "#6E6D68",
    borderSeparator: "#DAD9D4",
    borderDefault: "#B4B2A7",
  },
  {
    id: "sage-garden",
    name: "Sage Garden",
    source: "21st.dev",
    brightness: "light",
    canvas: "#F8F7F4",
    surfaceSecondary: "#EFECE6",
    surfacePrimary: "#E5E2D9",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#DBD7CC",
    accent: "#7C9082",
    onAccent: "#0A0A0A",
    textPrimary: "#1A1F2E",
    textSecondary: "#4B525E",
    textTertiary: "#6B7280",
    borderSeparator: "#E2DFD7",
    borderDefault: "#C9C5BA",
  },
  {
    id: "elegant-luxury",
    name: "Elegant Luxury",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FAF7F5",
    surfaceSecondary: "#F3ECE8",
    surfacePrimary: "#EAE1DC",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E0D4CD",
    accent: "#9B2C2C",
    onAccent: "#FFFFFF",
    textPrimary: "#1A1A1A",
    textSecondary: "#57534E",
    textTertiary: "#78716C",
    borderSeparator: "#E9DDD2",
    borderDefault: "#D6C5B6",
  },
  {
    id: "twitter",
    name: "Twitter",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FFFFFF",
    surfaceSecondary: "#F7F8F8",
    surfacePrimary: "#EBEEF0",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E1E5E8",
    accent: "#1E9DF1",
    onAccent: "#0A0A0A",
    textPrimary: "#0F1419",
    textSecondary: "#4A5560",
    textTertiary: "#68737E",
    borderSeparator: "#E1EAEF",
    borderDefault: "#C9D6DE",
  },
  {
    id: "vintage-paper",
    name: "Vintage Paper",
    source: "21st.dev",
    brightness: "light",
    canvas: "#F5F1E6",
    surfaceSecondary: "#EDE6D8",
    surfacePrimary: "#E3DAC8",
    surfaceRaised: "#FFFCF5",
    surfaceSunken: "#D9CEB8",
    accent: "#A67C52",
    onAccent: "#0A0A0A",
    textPrimary: "#4A3F35",
    textSecondary: "#5C4E40",
    textTertiary: "#7D6B56",
    borderSeparator: "#DBD0BA",
    borderDefault: "#C2B397",
  },
  {
    id: "graphite-mono",
    name: "Graphite Mono",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FFFFFF",
    surfaceSecondary: "#F5F5F5",
    surfacePrimary: "#EAEAEA",
    surfaceRaised: "#FDFDFD",
    surfaceSunken: "#E0E0E0",
    accent: "#171717",
    onAccent: "#FAFAFA",
    textPrimary: "#0A0A0A",
    textSecondary: "#525252",
    textTertiary: "#737373",
    borderSeparator: "#E5E5E5",
    borderDefault: "#CCCCCC",
  },
  {
    id: "amber-slate",
    name: "Amber Slate",
    source: "21st.dev",
    brightness: "light",
    canvas: "#F5F6F7",
    surfaceSecondary: "#ECEEF0",
    surfacePrimary: "#E2E5E8",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#D6DAE0",
    accent: "#DF6035",
    onAccent: "#0A0A0A",
    textPrimary: "#1F242B",
    textSecondary: "#4B525C",
    textTertiary: "#6B7280",
    borderSeparator: "#D5D9DF",
    borderDefault: "#BAC0C9",
  },
  {
    id: "azure-mono",
    name: "Azure Mono",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FCFCFC",
    surfaceSecondary: "#F3F5F8",
    surfacePrimary: "#E8ECF2",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#DCE2EC",
    accent: "#2E67FF",
    onAccent: "#FFFFFF",
    textPrimary: "#0E142B",
    textSecondary: "#3D4663",
    textTertiary: "#5B6480",
    borderSeparator: "#E2E5EB",
    borderDefault: "#C6CBD6",
  },
  {
    id: "t3-chat",
    name: "T3 Chat",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FAF5FA",
    surfaceSecondary: "#F4E9F3",
    surfacePrimary: "#EEDBF0",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#E6CBE7",
    accent: "#A84370",
    onAccent: "#FFFFFF",
    textPrimary: "#501854",
    textSecondary: "#6A2B6F",
    textTertiary: "#834588",
    borderSeparator: "#EBC4EB",
    borderDefault: "#D6A3D8",
  },
  {
    id: "indigo-mono",
    name: "Indigo Mono",
    source: "21st.dev",
    brightness: "light",
    canvas: "#FAFAFA",
    surfaceSecondary: "#F3F3F5",
    surfacePrimary: "#E8E9EE",
    surfaceRaised: "#FFFFFF",
    surfaceSunken: "#DCDDE4",
    accent: "#3F5EC2",
    onAccent: "#EFF6FF",
    textPrimary: "#0F172A",
    textSecondary: "#475569",
    textTertiary: "#64748B",
    borderSeparator: "#E4E4E7",
    borderDefault: "#CBD0DA",
  },
];

export const ALL_DARK_THEMES: WebThemePalette[] = [
  BOARDUI_DARK,
  ...TWENTY_FIRST_DEV_DARK_THEMES,
];

export const ALL_LIGHT_THEMES: WebThemePalette[] = [
  BOARDUI_LIGHT,
  ...TWENTY_FIRST_DEV_LIGHT_THEMES,
];

export const THEME_PAIRS: WebThemePair[] = ALL_DARK_THEMES.map((dark, i) => ({
  id: dark.id,
  name: dark.name,
  source: dark.source,
  light: ALL_LIGHT_THEMES[i],
  dark,
}));

export function getThemesForBrightness(brightness: ThemeBrightness): WebThemePalette[] {
  return brightness === "light" ? ALL_LIGHT_THEMES : ALL_DARK_THEMES;
}

export function getThemeById(
  themeId: string | undefined | null,
  brightness: ThemeBrightness = "dark",
): WebThemePalette {
  const pair = THEME_PAIRS.find((p) => p.id === themeId) || THEME_PAIRS[0];
  return brightness === "light" ? pair.light : pair.dark;
}

const OVERRIDABLE_CSS_VARS = [
  "--color-background-full",
  "--color-background-primary-default",
  "--color-background-primary-hover",
  "--color-background-primary-active",
  "--color-background-secondary-default",
  "--color-background-secondary-hover",
  "--color-background-tertiary-default",
  "--color-background-tertiary-hover",
  "--color-segmented-control-background",
  "--color-segmented-control-selected-background",
  "--color-text-primary",
  "--color-text-secondary",
  "--color-text-tertiary",
  "--color-foreground-icon-primary",
  "--color-foreground-icon-secondary",
  "--color-foreground-icon-tertiary",
  "--color-separator-border",
  "--color-separator-border-strong",
  "--color-border-button-default",
  "--color-border-button-hover",
  "--color-border-focus-ring",
  "--color-accent-400",
  "--color-accent-500",
  "--color-accent-600",
  "--color-accent-700",
  "--color-text-on-accent",
  "--color-accent-foreground",
] as const;

export function applyWebTheme(
  themeId: string,
  brightness: ThemeBrightness,
): WebThemePalette {
  const palette = getThemeById(themeId, brightness);
  if (typeof document === "undefined") return palette;

  const root = document.documentElement;
  root.classList.toggle("dark", brightness === "dark");
  root.dataset.themeId = palette.id;
  root.dataset.themeBrightness = brightness;

  const accentFg = resolveAccentForeground(palette);

  if (palette.id === DEFAULT_THEME_ID) {
    for (const v of OVERRIDABLE_CSS_VARS) {
      root.style.removeProperty(v);
    }
    root.style.setProperty("--color-text-on-accent", palette.onAccent);
    root.style.setProperty("--color-accent-foreground", accentFg);
  } else {
    const hoverAccent = mixHex(palette.accent, palette.onAccent, 0.12);
    const activeAccent = mixHex(palette.accent, palette.canvas, 0.16);
    const surfaceHover = mixHex(palette.surfacePrimary, palette.textPrimary, 0.08);
    const secHover = mixHex(palette.surfaceSecondary, palette.textPrimary, 0.06);

    const vars: Record<string, string> = {
      "--color-background-full": palette.canvas,
      "--color-background-primary-default": palette.surfaceRaised,
      "--color-background-primary-hover": surfaceHover,
      "--color-background-primary-active": palette.surfacePrimary,
      "--color-background-secondary-default": palette.surfaceSecondary,
      "--color-background-secondary-hover": secHover,
      "--color-background-tertiary-default": palette.surfacePrimary,
      "--color-background-tertiary-hover": surfaceHover,
      "--color-segmented-control-background": palette.surfaceSunken,
      "--color-segmented-control-selected-background": palette.surfaceRaised,
      "--color-text-primary": palette.textPrimary,
      "--color-text-secondary": palette.textSecondary,
      "--color-text-tertiary": palette.textTertiary,
      "--color-foreground-icon-primary": palette.textPrimary,
      "--color-foreground-icon-secondary": palette.textSecondary,
      "--color-foreground-icon-tertiary": palette.textTertiary,
      "--color-separator-border": palette.borderSeparator,
      "--color-separator-border-strong": palette.borderDefault,
      "--color-border-button-default": palette.borderDefault,
      "--color-border-button-hover": mixHex(palette.borderDefault, palette.textPrimary, 0.25),
      "--color-border-focus-ring": palette.accent,
      "--color-accent-400": hoverAccent,
      "--color-accent-500": palette.accent,
      "--color-accent-600": activeAccent,
      "--color-accent-700": activeAccent,
      "--color-text-on-accent": palette.onAccent,
      "--color-accent-foreground": accentFg,
    };

    for (const [key, val] of Object.entries(vars)) {
      root.style.setProperty(key, val);
    }
  }

  return palette;
}

export function readWebSettings(): WebSettingsState {
  if (typeof localStorage === "undefined") return { ...DEFAULT_WEB_SETTINGS };
  try {
    const raw = localStorage.getItem(WEB_SETTINGS_STORAGE_KEY);
    if (!raw) return { ...DEFAULT_WEB_SETTINGS };
    const parsed = JSON.parse(raw) as Partial<WebSettingsState>;
    const brightness: ThemeBrightness = parsed.brightness === "light" ? "light" : "dark";
    const resolvedTheme = getThemeById(parsed.themeId, brightness).id;
    return {
      themeId: resolvedTheme,
      brightness,
      autoPlayNext: typeof parsed.autoPlayNext === "boolean" ? parsed.autoPlayNext : true,
    };
  } catch {
    return { ...DEFAULT_WEB_SETTINGS };
  }
}

export function saveWebSettings(next: WebSettingsState): void {
  if (typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(WEB_SETTINGS_STORAGE_KEY, JSON.stringify(next));
  } catch {}
}
