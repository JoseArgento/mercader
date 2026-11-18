#!/usr/bin/env python3
"""Draws Mercader's own art (no game assets):

* Mercader/Media/icon.tga: an ink coin pouch on a parchment disc with a gold rim, 64x64, like the other
  addons' icons (the addon compartment and the minimap button use it).
* Mercader/Media/pin.tga: the map mark of a vendor the player visited (a gold coin with an ink rim), 32x32.
* Mercader/Media/pin_rumour.tga: the mark of a rumour (the same rim, a pale see-through centre), 32x32.
* Mercader/Media/glow.tga: the ring that pulses around a mark, 64x64.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "Mercader" / "Media"
DOCS = ROOT / "docs"

S = 512  # drawn big, scaled down
PARCHMENT, PARCHMENT_DARK = (242, 227, 192, 255), (222, 201, 158, 255)
GOLD, GOLD_DEEP = (216, 168, 69, 255), (148, 112, 31, 255)
INK = (58, 35, 19, 255)


def save(im: Image.Image, name: str, size: int) -> None:
    small = im.resize((size, size), Image.LANCZOS)
    MEDIA.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)
    small.save(MEDIA / f"{name}.tga", format="TGA", orientation=-1)
    small.save(DOCS / f"{name}.png")  # a look at it outside the game; not shipped
    print(MEDIA / f"{name}.tga", small.size)


def icon() -> Image.Image:
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # disc with a two-tone gold rim
    d.ellipse((8, 8, S - 8, S - 8), fill=GOLD_DEEP)
    d.ellipse((22, 22, S - 22, S - 22), fill=GOLD)
    d.ellipse((38, 38, S - 38, S - 38), fill=PARCHMENT_DARK)
    d.ellipse((50, 50, S - 50, S - 50), fill=PARCHMENT)
    cx = S / 2
    # the pouch: a round ink body, a neck gathered by a gold cord, and the open mouth above it
    d.ellipse((cx - 128, 190, cx + 128, 420), fill=INK)
    d.polygon([(cx - 62, 215), (cx + 62, 215), (cx + 40, 160), (cx - 40, 160)], fill=INK)
    d.polygon([(cx - 40, 160), (cx + 40, 160), (cx + 74, 108), (cx - 74, 108)], fill=INK)
    d.rounded_rectangle((cx - 58, 150, cx + 58, 176), radius=12, fill=GOLD)
    # a gold coin on the pouch, with an ink dot
    d.ellipse((cx - 56, 258, cx + 56, 370), fill=GOLD)
    d.ellipse((cx - 40, 274, cx + 40, 354), fill=GOLD_DEEP)
    d.ellipse((cx - 30, 284, cx + 30, 344), fill=GOLD)
    return im


def pin(rumour: bool) -> Image.Image:
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((24, 24, S - 24, S - 24), fill=INK)
    if rumour:
        d.ellipse((78, 78, S - 78, S - 78), fill=(242, 227, 192, 150))
    else:
        d.ellipse((70, 70, S - 70, S - 70), fill=GOLD)
        d.ellipse((120, 120, S - 120, S - 120), fill=GOLD_DEEP)
        d.ellipse((146, 146, S - 146, S - 146), fill=GOLD)
    return im


def glow() -> Image.Image:
    """A soft gold ring, see-through in the middle: it pulses around the mark "Open map" points at."""
    im = Image.new("RGBA", (S, S), (255, 214, 96, 0))  # the ring's own colour, see-through: the blur stays gold
    d = ImageDraw.Draw(im)
    d.ellipse((40, 40, S - 40, S - 40), outline=(255, 214, 96, 255), width=46)
    im = im.filter(ImageFilter.GaussianBlur(14))
    return im


def main() -> None:
    save(icon(), "icon", 64)
    save(pin(False), "pin", 32)
    save(pin(True), "pin_rumour", 32)
    save(glow(), "glow", 64)


if __name__ == "__main__":
    main()
