import os
import sys
from PIL import Image

SRC = r"C:\Users\Dylan\.gemini\antigravity-cli\brain\f989660a-bbe4-4d00-8c15-3f9a625d6a99\master_squirrel_icon_1795438270227.jpg"
ROOT = r"C:\Users\Dylan\Documents\github\dTVSteams"

def process():
    im = Image.open(SRC).convert("RGBA")
    
    # Save master PNG with solid background
    master_png = os.path.join(ROOT, "master_squirrel_icon.png")
    im.save(master_png, "PNG")
    print(f"Saved master PNG: {master_png}")
    
    # Create transparent foreground for adaptive icon
    # bg is ~ (18, 18, 18)
    bg_r, bg_g, bg_b = 18, 18, 18
    fg = Image.new("RGBA", im.size)
    
    pixels = im.load()
    fg_pixels = fg.load()
    
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = pixels[x, y]
            # Calculate distance from dark background
            # If bright line or red accent, keep full opacity
            diff = max(abs(r - bg_r), abs(g - bg_g), abs(b - bg_b))
            if diff < 15:
                fg_pixels[x, y] = (0, 0, 0, 0)
            elif diff < 35:
                alpha = int(255 * (diff - 15) / 20)
                fg_pixels[x, y] = (r, g, b, alpha)
            else:
                fg_pixels[x, y] = (r, g, b, 255)
                
    fg_master = os.path.join(ROOT, "master_squirrel_fg.png")
    fg.save(fg_master, "PNG")
    print(f"Saved master FG: {fg_master}")

    # Android mipmaps
    res_dir = os.path.join(ROOT, "flutter_app", "android", "app", "src", "main", "res")
    
    sizes = {
        "mipmap-mdpi": (48, 108),
        "mipmap-hdpi": (72, 162),
        "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324),
        "mipmap-xxxhdpi": (192, 432),
    }
    
    for folder, (legacy_sz, adapt_sz) in sizes.items():
        f_dir = os.path.join(res_dir, folder)
        os.makedirs(f_dir, exist_ok=True)
        
        # Legacy ic_launcher.png (uses solid background im)
        leg_img = im.resize((legacy_sz, legacy_sz), Image.Resampling.LANCZOS)
        leg_img.save(os.path.join(f_dir, "ic_launcher.png"), "PNG")
        
        # Adaptive ic_launcher_foreground.png (uses transparent fg)
        adapt_img = fg.resize((adapt_sz, adapt_sz), Image.Resampling.LANCZOS)
        adapt_img.save(os.path.join(f_dir, "ic_launcher_foreground.png"), "PNG")
        print(f"Generated {folder}: legacy={legacy_sz}x{legacy_sz}, foreground={adapt_sz}x{adapt_sz}")
        
    # Adaptive XML definition in mipmap-anydpi-v26
    anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(xml_content)
    print("Created mipmap-anydpi-v26/ic_launcher.xml")
    
    # Color definition in values/colors.xml
    values_dir = os.path.join(res_dir, "values")
    os.makedirs(values_dir, exist_ok=True)
    colors_xml = os.path.join(values_dir, "colors.xml")
    with open(colors_xml, "w", encoding="utf-8") as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#121212</color>
</resources>
""")
    print("Created values/colors.xml")
    
    # Web icons for flutter_app/web
    web_dir = os.path.join(ROOT, "flutter_app", "web")
    web_icons = os.path.join(web_dir, "icons")
    os.makedirs(web_icons, exist_ok=True)
    
    # Favicon 32x32
    fav32 = im.resize((32, 32), Image.Resampling.LANCZOS)
    fav32.save(os.path.join(web_dir, "favicon.png"), "PNG")
    
    # Icon-192 / Icon-512
    im.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-192.png"), "PNG")
    im.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-512.png"), "PNG")
    im.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-maskable-192.png"), "PNG")
    im.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons, "Icon-maskable-512.png"), "PNG")
    print("Updated flutter_app/web/icons")
    
    # Web-app and tv-web favicons
    for target in ["web-app", "tv-web"]:
        t_dir = os.path.join(ROOT, target)
        if os.path.exists(t_dir):
            im.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(t_dir, "favicon.png"), "PNG")
            # Save ICO format containing 16, 32, 48
            ico_sizes = [(16, 16), (32, 32), (48, 48)]
            im.save(os.path.join(t_dir, "favicon.ico"), format="ICO", sizes=ico_sizes)
            print(f"Updated {target} favicon.ico and favicon.png")

if __name__ == "__main__":
    process()
