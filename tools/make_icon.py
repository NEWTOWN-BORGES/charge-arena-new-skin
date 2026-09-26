"""Ícone da app a partir do rosto do BIT (art/icon/bit_face.png, de tools/render_icon.gd).

    python3 tools/make_icon.py

Escreve o ícone adaptativo do Android (frente e fundo, 432 px) e o ícone clássico de 192 px.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "art" / "icon"


def background(size):
    # A vivid teal-to-blue gradient with a soft light behind the head.
    bg = Image.new("RGBA", (size, size))
    top, bottom = (47, 196, 165), (35, 92, 196)
    d = ImageDraw.Draw(bg)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r = int(size * 0.34)
    for k in range(r, 0, -2):
        gd.ellipse([size / 2 - k, size * 0.46 - k, size / 2 + k, size * 0.46 + k], fill=(255, 255, 255, int(90 * (1 - k / r))))
    return Image.alpha_composite(bg, glow)


def main():
    face = Image.open(ICON / "bit_face.png").convert("RGBA")
    # The render cuts the body off square at the bottom: fade the lowest third out.
    alpha = face.getchannel("A")
    w, h = face.size
    fade = Image.new("L", face.size, 255)
    for y in range(int(h * 0.62), h):
        fade.paste(int(255 * (1 - (y - h * 0.62) / (h * 0.38))), (0, y, w, y + 1))
    face.putalpha(Image.composite(alpha, Image.new("L", face.size, 0), fade))
    # Adaptive foreground: the face inside the central safe zone.
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(face.resize((280, 280), Image.LANCZOS), (76, 76))
    fg.save(ICON / "bit_foreground.png")
    background(432).save(ICON / "bit_background.png")
    full = background(192)
    full.alpha_composite(face.resize((160, 160), Image.LANCZOS), (16, 16))
    mask = Image.new("L", (192, 192), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 191, 191], 42, fill=255)
    icon = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    icon.paste(full, (0, 0), mask)
    icon.save(ICON / "bit_icon.png")
    print("ICON", ICON / "bit_icon.png")


if __name__ == "__main__":
    main()
