"""Generate MacDjVu app icons (light + dark) for all required macOS sizes."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SIZES = [16, 32, 64, 128, 256, 512, 1024]

# Colors
LIGHT_BG = (45, 55, 72)       # dark slate document
LIGHT_TEXT = (255, 255, 255)   # white text
DARK_BG = (220, 225, 235)     # light gray document
DARK_TEXT = (30, 30, 30)       # dark text
ACCENT = (90, 130, 230)       # blue accent stripe


def draw_icon(size: int, bg_color: tuple, text_color: tuple) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = size // 8
    corner = size // 6

    # Document body
    draw.rounded_rectangle(
        [margin, margin // 2, size - margin, size - margin // 2],
        radius=corner,
        fill=bg_color,
    )

    # Accent stripe at top
    stripe_h = max(2, size // 10)
    draw.rounded_rectangle(
        [margin, margin // 2, size - margin, margin // 2 + stripe_h + corner],
        radius=corner,
        fill=ACCENT,
    )
    # Cover the bottom corners of the accent so it's flat
    draw.rectangle(
        [margin, margin // 2 + stripe_h, size - margin, margin // 2 + stripe_h + corner],
        fill=bg_color,
    )

    # "Dj" text
    font_size = size * 45 // 100
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", font_size)
    except (OSError, IOError):
        font = ImageFont.load_default()

    text = "Dj"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (size - tw) // 2
    ty = (size - th) // 2 + size // 16  # slightly below center (account for stripe)
    draw.text((tx, ty), text, fill=text_color, font=font)

    return img


def main():
    out = Path(__file__).parent.parent / "Assets.xcassets" / "AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)

    entries = []

    for s in SIZES:
        for appearance, bg, fg in [
            (None, LIGHT_BG, LIGHT_TEXT),
            ("dark", DARK_BG, DARK_TEXT),
        ]:
            icon = draw_icon(s, bg, fg)
            suffix = f"_{appearance}" if appearance else ""
            name = f"icon_{s}{suffix}.png"
            icon.save(out / name)

            # Determine scale and size-class
            # macOS icon slots: 16, 32, 128, 256, 512 at 1x and 2x
            scale_map = {16: (16, 1), 32: (16, 2), 64: (32, 2),
                         128: (128, 1), 256: (128, 2), 512: (256, 2),
                         1024: (512, 2)}
            pt_size, scale = scale_map[s]

            entry = {
                "filename": name,
                "idiom": "mac",
                "scale": f"{scale}x",
                "size": f"{pt_size}x{pt_size}",
            }
            if appearance:
                entry["appearances"] = [{"appearance": "luminosity", "value": appearance}]
            entries.append(entry)

    # Also need 256@1x and 512@1x
    for s, appearance, bg, fg in [
        (256, None, LIGHT_BG, LIGHT_TEXT),
        (512, None, LIGHT_BG, LIGHT_TEXT),
        (256, "dark", DARK_BG, DARK_TEXT),
        (512, "dark", DARK_BG, DARK_TEXT),
    ]:
        icon = draw_icon(s, bg, fg)
        suffix = f"_{appearance}" if appearance else ""
        name = f"icon_{s}x1{suffix}.png"
        icon.save(out / name)
        entry = {
            "filename": name,
            "idiom": "mac",
            "scale": "1x",
            "size": f"{s}x{s}",
        }
        if appearance:
            entry["appearances"] = [{"appearance": "luminosity", "value": appearance}]
        entries.append(entry)

    import json
    contents = {"images": entries, "info": {"version": 1, "author": "gen_icon.py"}}
    (out / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    print(f"Generated {len(entries)} icon variants in {out}")


if __name__ == "__main__":
    main()
