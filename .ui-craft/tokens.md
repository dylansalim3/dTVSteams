# Design Tokens: dTVSteams Three-Layer Token Spine

Conforms to the BoardUI design system (`src/react/styles/theme.css`), Mobile-Mirrored Web stylesheet (`web-app/app.css`), and Flutter multi-theme design tokens (`flutter_app/lib/ui/app_tokens.dart` & `app_themes.dart`). All seven token categories (color, spacing, type, radii, shadows, motion, z-index) are represented across both explicit light and intentional dark modes.

---

## Layer 1: Primitive Tokens

Raw, value-named scales shared across platforms. Never role-named.

### Color Primitives
```css
/* Tinted / Deep Dark Neutrals (no pure #000 canvas) */
--color-white:       #ffffff;
--color-neutral-50:  #fafafa;
--color-neutral-100: #f7f7f7;
--color-neutral-200: #ebebeb;
--color-neutral-300: #d4d4d4;
--color-neutral-400: #a3a3a3;
--color-neutral-500: #737373;
--color-neutral-600: #525252;
--color-neutral-700: #404040;
--color-neutral-750: #2f2f2f;
--color-neutral-800: #262626;
--color-neutral-850: #1e1e1e;
--color-neutral-900: #171717;
--color-neutral-925: #121212;
--color-neutral-950: #0a0a0a;

/* Brand Accent Ramp (Crimson Red default, overridden at runtime in React/Flutter theme picker) */
--color-accent-400: #f87171;
--color-accent-500: #e50914;
--color-accent-600: #b80710;

/* Status Bases */
--color-green-500:  #46d369;
--color-green-700:  #15803d;
--color-amber-500:  #ffb300;
--color-amber-700:  #b45309;
--color-red-500:    #e50914;
--color-blue-400:   #3392ff;
```

### Spacing (4px / 8pt Aligned Scale)
```css
--space-xs:  4px;   /* 0.25rem — Flutter AppSpacing.xs */
--space-sm:  8px;   /* 0.5rem  — Flutter AppSpacing.sm */
--space-md:  12px;  /* 0.75rem — compact mobile card gutters (AppSpacing.md) */
--space-lg:  16px;  /* 1rem    — Flutter AppSpacing.lg */
--space-xl:  24px;  /* 1.5rem  — Flutter AppSpacing.xl */
--space-2xl: 32px;  /* 2rem    — Flutter AppSpacing.xxl */
--space-3xl: 48px;  /* 3rem    — major section separation */
```

### Typography Scale
```css
--font-sans: "Inter", "Noto Sans TC", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
--font-mono: "JetBrains Mono", ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;

/* Composite roles aligned to BoardUI styles/typography.css & Flutter AppType */
--text-title-1:   24px / 32px weight 500 tracking -0.48px;
--text-title-2:   20px / 28px weight 500 tracking -0.40px;
--text-title-3:   18px / 26px weight 600 tracking -0.27px;
--text-headline:  16px / 24px weight 500 tracking -0.16px;
--text-body:      14px / 20px weight 500 / 400;
--text-body-2:    13px / 18px weight 500;
--text-caption-1: 12px / 16px weight 600 / 500 / 400;
--text-caption-2: 11px / 14px weight 500;
/* Numeric rule: font-variant-numeric: tabular-nums on timers, countdowns, badges, counts */
```

### Radii (Role-Differentiated Scale)
```css
--radius-xs:      4px;    /* micro progress bars */
--radius-badge:   6px;    /* status pills, compact tags */
--radius-sm:      8px;    /* nested rows, mini-thumbs */
--radius-control: 10px;   /* BoardUI radius-2lg: buttons, search fields, filter chips */
--radius-card:    16px;   /* episode cards, surface blocks */
--radius-panel:   20px;   /* BoardUI radius-2-5xl: large containers */
--radius-modal:   24px;   /* bottom sheets, centered dialogs */
--radius-full:    9999px; /* icon buttons, circular avatars, action discs */
```

### Shadows (Multi-Layer Elevation)
```css
--shadow-card:     0 1px 1px 0 rgb(0 0 0 / 0.05);
--shadow-sm:       0 1px 2px 0 rgb(0 0 0 / 0.06), 0 1px 3px 0 rgb(0 0 0 / 0.10);
--shadow-md:       0 2px 4px -1px rgb(0 0 0 / 0.06), 0 4px 6px -1px rgb(0 0 0 / 0.10);
--shadow-lg:       0 4px 6px -2px rgb(0 0 0 / 0.05), 0 10px 15px -3px rgb(0 0 0 / 0.10);
--shadow-xl:       0 10px 10px -5px rgb(0 0 0 / 0.04), 0 20px 25px -5px rgb(0 0 0 / 0.10);
--shadow-dropdown: 0 1px 1px 0 rgb(0 0 0 / 0.04), 0 4px 4px 0 rgb(0 0 0 / 0.02);
/* Dark mode rule: drop shadows yield to 1px border rings (--border-default / --border-strong) */
```

### Motion
```css
--duration-instant: 80ms;
--duration-fast:    150ms; /* AppDurations.fast — micro-hover, icon state */
--duration-focus:   180ms; /* AppDurations.focus — D-pad / focus ring transitions */
--duration-normal:  220ms; /* AppDurations.normal — modal/sheet entry */
--duration-slow:    250ms; /* overlay fade */

--ease-out:         cubic-bezier(0.16, 1, 0.3, 1);
--ease-in-out:      cubic-bezier(0.4, 0, 0.2, 1);
/* Reduced motion: collapses transitions/animations under @media (prefers-reduced-motion: reduce) */
```

### Z-Index
```css
--z-base:           0;
--z-raised:         1;
--z-dropdown:       10;
--z-sticky:         20;  /* Sticky top header */
--z-modal-backdrop: 30;  /* Sheet / modal backdrop */
--z-modal:          40;  /* Channel picker, Share, History, Sleep Timer dialogs */
--z-toast:          50;
--z-tooltip:        60;
```

---

## Layer 2: Semantic Tokens (Intentional Light + Dark Modes)

### Default Dark Surface Stack (Web Primary & Flutter `boardUiDefault`)
| Semantic Role | Web CSS Var (`web-app/app.css` / `theme.css`) | Value | Flutter Token (`AppColors`) |
|---|---|---|---|
| Canvas ground | `--bg-canvas` / `--color-background-full` | `#121212` (`--color-neutral-925`) | `AppColors.canvas` |
| Elevated surface / Cards | `--yt-surface` / `--yt-card-bg` | `#171717` (`--color-neutral-900`) | `AppColors.surfaceRaised` |
| Secondary / Sticky Chrome | `--color-background-secondary-default` | `#171717` / `rgba(23,23,23,0.94)` | `AppColors.surfaceSecondary` |
| Hover surface | `--yt-card-hover` | `#202020` | `AppColors.surfacePrimary` |
| Interactive / Overlay / Focus fill | `--yt-surface-interactive` / `--yt-card-focus` | `#262626` (`--color-neutral-800`) | `AppColors.surfaceInteractive` |
| Sunken inset well | `--color-background-sunken` | `#0a0a0a` (`--color-neutral-950`) | `AppColors.surfaceSunken` |
| Primary text | `--yt-text-primary` / `--color-text-primary` | `#fafafa` (`--color-neutral-50`) | `AppColors.textPrimary` |
| Secondary text | `--yt-text-secondary` / `--color-text-secondary` | `#a3a3a3` (`--color-neutral-400`) | `AppColors.textSecondary` |
| Tertiary / Placeholder text | `--yt-text-tertiary` / `--color-text-tertiary` | `#737373` (`--color-neutral-500`) | `AppColors.textTertiary` |
| Separator / Default Border | `--yt-border` / `--color-border-button-default` | `#262626` (`--color-neutral-800`) | `AppColors.borderDefault` |
| Strong Border | `--yt-border-strong` | `#404040` (`--color-neutral-700`) | `AppColors.borderHover` |
| Accent CTA / Active State | `--yt-red` / `--color-accent-500` | `#e50914` | `AppColors.accent` |
| Accent Hover | `--yt-red-hover` / `--color-accent-600` | `#b80710` | `AppColors.accentHover` |
| Accent Tint Fill | `--yt-red-soft` | `rgba(229, 9, 20, 0.16)` | `AppColors.accentSoft` |
| Focus Ring | `--yt-focus-ring` / `--color-border-focus-ring` | `#e50914` | `AppColors.accent` |
| Success / Watched | `--yt-green` / `--yt-green-soft` | `#46d369` / `rgba(70, 211, 105, 0.15)` | `AppColors.success` |

### Light Mode Remap (`:root` in `src/react/styles/theme.css` + Light Themes in `AppThemes`)
Light mode is explicitly authored — never auto-inverted:
- **Canvas**: `#ffffff` / neutral tint `#fafafa`–`#f8fafc` (`color-scheme: light dark`)
- **Raised Surface**: `#ffffff` with `--shadow-card` and `--color-border-button-default` (`#ebebeb`)
- **Text Primary / Secondary**: `#0a0a0a` / `#737373` (Flutter: `#0F172A` / `#475569`)
- **Status Semantic Foreground**: Darkened for WCAG AA on white (`success: #15803d`, `onSuccess: #ffffff`, `warning: #b45309`, `onWarning: #ffffff`)

### Multi-Theme Contract (`21st.dev` 20-Theme Palette Engine — Flutter `app_themes.dart`)
1. Supports `boardUiDefault` + 20 curated themes from `21st.dev/themes` across light and dark polarities.
2. Every theme explicitly defines `canvas`, `surfaceSecondary`, `surfacePrimary`, `surfaceRaised`, `surfaceSunken`, `accent`, `accentHover`, `accentSoft`, `textPrimary`, `textSecondary`, `textTertiary`, `borderDefault`, `borderSeparator`, `borderHover`, and `actionCircleBg`.
3. Interactive foregrounds (`onAccent`, `onSuccess`, `onWarning`) resolve via luminance/contrast calculation (`contrastRatio` in `app_themes.dart`) so active pills, selected channel chips, and buttons never drop below WCAG contrast.

---

## Layer 3: Component Tokens

Created specifically for multi-state shared components:

```css
/* Episode & History Cards (AppCardTokens + .ep-card) */
--card-radius:             var(--radius-card);       /* 16px */
--card-padding:            var(--space-md);          /* 12px */
--card-bg:                 var(--yt-card-bg);
--card-border:             var(--yt-border);
--card-action-visual-size: 36px;                     /* AppCardTokens.actionVisualSize */
--card-action-hit-size:    44px;                     /* AppCardTokens.actionHitSize (min touch target) */
--card-action-icon-size:   18px;                     /* AppCardTokens.actionIconSize */

/* Sleek Toggle Switch (CompactSwitchTile in Flutter) */
--switch-scale:            0.72;
--switch-track-active:     var(--accent-bg);
--switch-thumb-active:     var(--text-on-accent);
--switch-track-inactive:   var(--yt-surface-interactive);
--switch-thumb-inactive:   var(--yt-text-secondary);

/* Mobile-Mirrored Top Bar & Channel Pill */
--header-height:           56px;
--shell-max-width:         760px;                    /* Single-column web shell parity with mobile */
--pill-radius:             var(--radius-full);
--control-radius:          var(--radius-control);    /* 10px */
```
