import os
import json
import math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "scripts", "app_icon_source.jpg")

# Measured crop bounds inside the 2000x2000 source image that strip the outer
# dark navy border (#1E2034) plus its 6px JPEG transition fringe.
CROP_BOX = (172, 172, 1828, 1828)
CORNER_RADIUS_RATIO = 0.22


def _build_full_bleed(cropped_rgb: Image.Image) -> Image.Image:
    """Radially extend pure interior corner colors outward to eliminate dark fringes."""
    w, h = cropped_rgb.size
    bleed = cropped_rgb.copy()
    src_px = cropped_rgb.load()
    dst_px = bleed.load()

    # Curve radius inside the 1656x1656 crop that clears all anti-aliased edge pixels.
    r_curve = 370.0
    r_sample = 352.0

    corners = [
        (r_curve, r_curve, lambda x, y: x < r_curve and y < r_curve),
        (w - 1 - r_curve, r_curve, lambda x, y: x > w - 1 - r_curve and y < r_curve),
        (r_curve, h - 1 - r_curve, lambda x, y: x < r_curve and y > h - 1 - r_curve),
        (w - 1 - r_curve, h - 1 - r_curve, lambda x, y: x > w - 1 - r_curve and y > h - 1 - r_curve),
    ]

    for cx, cy, in_quad in corners:
        y_start = 0 if cy < h / 2 else int(cy)
        y_end = int(cy) + 1 if cy < h / 2 else h
        x_start = 0 if cx < w / 2 else int(cx)
        x_end = int(cx) + 1 if cx < w / 2 else w
        for y in range(y_start, y_end):
            for x in range(x_start, x_end):
                if not in_quad(x, y):
                    continue
                dx = x - cx
                dy = y - cy
                dist = math.hypot(dx, dy)
                if dist >= r_sample and dist > 0:
                    sx = int(round(cx + dx * (r_sample / dist)))
                    sy = int(round(cy + dy * (r_sample / dist)))
                    sx = max(0, min(w - 1, sx))
                    sy = max(0, min(h - 1, sy))
                    dst_px[x, y] = src_px[sx, sy]

    # Also clean the outermost 4px rim along all 4 sides from 12px deeper inside
    rim = 6
    sample_depth = 14
    for x in range(w):
        for y in range(rim):
            dst_px[x, y] = dst_px[x, sample_depth]
            dst_px[x, h - 1 - y] = dst_px[x, h - 1 - sample_depth]
    for y in range(h):
        for x in range(rim):
            dst_px[x, y] = dst_px[sample_depth, y]
            dst_px[w - 1 - x, y] = dst_px[w - 1 - sample_depth, y]

    return bleed


def _rounded_mask(size: int, radius: int) -> Image.Image:
    """Create a 4x supersampled anti-aliased rounded-rectangle alpha mask."""
    ss = 4
    hi = size * ss
    r_hi = radius * ss
    mask = Image.new("L", (hi, hi), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, hi - 1, hi - 1], radius=r_hi, fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def _make_rounded_rgba(full_bleed_rgb: Image.Image, size: int) -> Image.Image:
    base = full_bleed_rgb.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    radius = max(2, round(size * CORNER_RADIUS_RATIO))
    base.putalpha(_rounded_mask(size, radius))
    return base


def _make_adaptive_background(full_bleed_rgb: Image.Image, size: int) -> Image.Image:
    """Create a smooth mint/teal/peach full-bleed background for Android adaptive icons."""
    w, h = full_bleed_rgb.size
    bg = Image.new("RGB", (w, h))
    src_px = full_bleed_rgb.load()
    dst_px = bg.load()
    inset = 24
    for y in range(h):
        ty = y / (h - 1)
        left_c = src_px[inset, y]
        right_c = src_px[w - 1 - inset, y]
        for x in range(w):
            tx = x / (w - 1)
            top_c = src_px[x, inset]
            bot_c = src_px[x, h - 1 - inset]
            hr = left_c[0] * (1 - tx) + right_c[0] * tx
            hg = left_c[1] * (1 - tx) + right_c[1] * tx
            hb = left_c[2] * (1 - tx) + right_c[2] * tx
            vr = top_c[0] * (1 - ty) + bot_c[0] * ty
            vg = top_c[1] * (1 - ty) + bot_c[1] * ty
            vb = top_c[2] * (1 - ty) + bot_c[2] * ty
            dst_px[x, y] = (
                int((hr + vr) * 0.5),
                int((hg + vg) * 0.5),
                int((hb + vb) * 0.5),
            )
    bg = bg.resize((size, size), Image.Resampling.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(radius=max(4, size // 32)))
    return bg.convert("RGBA")


def _make_centered_foreground(rounded_1024: Image.Image, size: int, scale: float = 0.72) -> Image.Image:
    """Center the rounded icon inside the adaptive safe zone on a transparent canvas."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner_sz = max(1, round(size * scale))
    inner = rounded_1024.resize((inner_sz, inner_sz), Image.Resampling.LANCZOS)
    offset = (size - inner_sz) // 2
    canvas.paste(inner, (offset, offset), inner)
    return canvas


def _make_maskable(full_bleed_rgb: Image.Image, bg_1024: Image.Image, rounded_1024: Image.Image, size: int) -> Image.Image:
    """Compose a full-bleed maskable web icon with safe-zone inset (80%)."""
    canvas = bg_1024.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    inner_sz = max(1, round(size * 0.80))
    inner = rounded_1024.resize((inner_sz, inner_sz), Image.Resampling.LANCZOS)
    offset = (size - inner_sz) // 2
    canvas.paste(inner, (offset, offset), inner)
    return canvas


def process() -> None:
    if not os.path.exists(SRC):
        raise FileNotFoundError(f"Icon source not found: {SRC}")

    raw = Image.open(SRC).convert("RGB")
    cropped = raw.crop(CROP_BOX)
    full_bleed = _build_full_bleed(cropped)
    rounded_1024 = _make_rounded_rgba(full_bleed, 1024)
    adaptive_bg_1024 = _make_adaptive_background(full_bleed, 1024)

    # Save master PNGs at repo root
    master_icon = os.path.join(ROOT, "master_app_icon.png")
    rounded_1024.save(master_icon, "PNG")
    print(f"Saved master rounded icon: {master_icon}")

    # 1. Android mipmaps (legacy rounded ic_launcher + adaptive foreground/background)
    res_dir = os.path.join(ROOT, "flutter_app", "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": (48, 108),
        "mipmap-hdpi": (72, 162),
        "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324),
        "mipmap-xxxhdpi": (192, 432),
    }

    for folder, (legacy_sz, adapt_sz) in android_sizes.items():
        f_dir = os.path.join(res_dir, folder)
        os.makedirs(f_dir, exist_ok=True)

        _make_rounded_rgba(full_bleed, legacy_sz).save(
            os.path.join(f_dir, "ic_launcher.png"), "PNG"
        )
        _make_centered_foreground(rounded_1024, adapt_sz, scale=0.72).save(
            os.path.join(f_dir, "ic_launcher_foreground.png"), "PNG"
        )
        adaptive_bg_1024.resize((adapt_sz, adapt_sz), Image.Resampling.LANCZOS).save(
            os.path.join(f_dir, "ic_launcher_background.png"), "PNG"
        )
        print(
            f"Generated {folder}: legacy={legacy_sz}x{legacy_sz}, "
            f"adaptive={adapt_sz}x{adapt_sz}"
        )

    anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    for xml_name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi_dir, xml_name), "w", encoding="utf-8") as f:
            f.write(adaptive_xml)
    print("Updated mipmap-anydpi-v26/ic_launcher.xml & ic_launcher_round.xml")

    values_dir = os.path.join(res_dir, "values")
    os.makedirs(values_dir, exist_ok=True)
    with open(os.path.join(values_dir, "colors.xml"), "w", encoding="utf-8") as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#4FE5C7</color>
</resources>
""")
    print("Updated values/colors.xml")

    # 2. iOS AppIcon.appiconset (opaque RGB PNGs — iOS applies squircle rounding)
    ios_dir = os.path.join(
        ROOT, "flutter_app", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    ios_contents_path = os.path.join(ios_dir, "Contents.json")
    if os.path.exists(ios_contents_path):
        with open(ios_contents_path, "r", encoding="utf-8") as f:
            ios_contents = json.load(f)
        seen_ios = set()
        for entry in ios_contents.get("images", []):
            filename = entry.get("filename")
            size_str = entry.get("size", "")
            scale_str = entry.get("scale", "1x")
            if not filename or filename in seen_ios or "x" not in size_str:
                continue
            seen_ios.add(filename)
            pt = float(size_str.split("x")[0])
            scale = int(scale_str.replace("x", ""))
            px_size = round(pt * scale)
            full_bleed.resize((px_size, px_size), Image.Resampling.LANCZOS).save(
                os.path.join(ios_dir, filename), "PNG"
            )
        print(f"Updated {len(seen_ios)} iOS AppIcon PNGs")

    # 3. macOS AppIcon.appiconset (transparent rounded corners)
    macos_dir = os.path.join(
        ROOT, "flutter_app", "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    if os.path.exists(macos_dir):
        macos_sizes = [16, 32, 64, 128, 256, 512, 1024]
        for sz in macos_sizes:
            _make_rounded_rgba(full_bleed, sz).save(
                os.path.join(macos_dir, f"app_icon_{sz}.png"), "PNG"
            )
        print(f"Updated {len(macos_sizes)} macOS AppIcon PNGs")

    # 4. Windows app_icon.ico (multi-size rounded transparent ICO)
    win_ico = os.path.join(
        ROOT, "flutter_app", "windows", "runner", "resources", "app_icon.ico"
    )
    if os.path.exists(os.path.dirname(win_ico)):
        ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        rounded_1024.save(win_ico, format="ICO", sizes=ico_sizes)
        print(f"Updated Windows ICO: {win_ico}")

    # 5. Flutter Web icons & manifest
    web_dir = os.path.join(ROOT, "flutter_app", "web")
    web_icons = os.path.join(web_dir, "icons")
    os.makedirs(web_icons, exist_ok=True)
    _make_rounded_rgba(full_bleed, 32).save(os.path.join(web_dir, "favicon.png"), "PNG")
    _make_rounded_rgba(full_bleed, 192).save(os.path.join(web_icons, "Icon-192.png"), "PNG")
    _make_rounded_rgba(full_bleed, 512).save(os.path.join(web_icons, "Icon-512.png"), "PNG")
    _make_maskable(full_bleed, adaptive_bg_1024, rounded_1024, 192).save(
        os.path.join(web_icons, "Icon-maskable-192.png"), "PNG"
    )
    _make_maskable(full_bleed, adaptive_bg_1024, rounded_1024, 512).save(
        os.path.join(web_icons, "Icon-maskable-512.png"), "PNG"
    )
    print("Updated flutter_app/web/favicon.png & icons/")

    # 6. tv-web favicons (also copied into dist/react and dist/tv-web by scripts/build.mjs)
    tv_web_dir = os.path.join(ROOT, "tv-web")
    if os.path.exists(tv_web_dir):
        _make_rounded_rgba(full_bleed, 32).save(os.path.join(tv_web_dir, "favicon.png"), "PNG")
        rounded_1024.save(
            os.path.join(tv_web_dir, "favicon.ico"),
            format="ICO",
            sizes=[(16, 16), (32, 32), (48, 48)],
        )
        print("Updated tv-web/favicon.png & tv-web/favicon.ico")


if __name__ == "__main__":
    process()
