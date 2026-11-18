#!/usr/bin/env python3
"""Draws Mercader's own art (no game assets):

* Mercader/Media/icon.tga: an ink coin pouch on a parchment disc with a gold rim, 64x64, like the other
  addons' icons (the addon compartment and the minimap button use it).
* Mercader/Media/pin.tga: the map mark of a vendor the player visited (an ink pouch on a gold badge), 64x64.
* Mercader/Media/pin_rumour.tga: the mark of a rumour (a softer pouch on pale parchment), 64x64.
* Mercader/Media/dot.tga: the corner disc with the number of vendors a mark stands for, 32x32.
* Mercader/Media/glow.tga: the ring that pulses around a mark, 64x64.
* Mercader/Media/emblem.tga: the pouch drawn big for the book's page with no vendor chosen, 256x256.
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


def pouch(d: ImageDraw.ImageDraw, cx: float, top: float, scale: float, body, cord) -> None:
    """The coin pouch as a bold silhouette: a round body, a gathered neck with its cord and the open mouth."""

    def s(v: float) -> float:
        return v * scale

    d.ellipse((cx - s(128), top + s(82), cx + s(128), top + s(312)), fill=body)
    d.polygon([(cx - s(62), top + s(107)), (cx + s(62), top + s(107)), (cx + s(40), top + s(52)), (cx - s(40), top + s(52))], fill=body)
    d.polygon([(cx - s(40), top + s(52)), (cx + s(40), top + s(52)), (cx + s(74), top), (cx - s(74), top)], fill=body)
    d.rounded_rectangle((cx - s(60), top + s(40), cx + s(60), top + s(70)), radius=s(14), fill=cord)


def pin(rumour: bool) -> Image.Image:
    """A map mark: a little pouch on a round badge. Gold for a vendor the player visited; pale parchment
    with a softer pouch for a rumour. Bold shapes only: it is drawn at about 24 px."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((10, 10, S - 10, S - 10), fill=INK)
    if rumour:
        d.ellipse((50, 50, S - 50, S - 50), fill=(236, 223, 194, 255))
        pouch(d, S / 2, 118, 0.92, (133, 104, 74, 255), (236, 223, 194, 255))
    else:
        d.ellipse((50, 50, S - 50, S - 50), fill=GOLD_DEEP)
        d.ellipse((66, 66, S - 66, S - 66), fill=(232, 186, 84, 255))
        pouch(d, S / 2, 118, 0.92, INK, (255, 236, 170, 255))
    return im


def dot() -> Image.Image:
    """The small ink disc a mark wears at its corner when it stands for several vendors (the number goes on it)."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((16, 16, S - 16, S - 16), fill=(255, 236, 170, 255))
    d.ellipse((56, 56, S - 56, S - 56), fill=INK)
    return im


def emblem() -> Image.Image:
    """The book's emblem for the page shown while no vendor is chosen: the pouch in ink with its gold cord and
    coin, a ring of ink around it, no disc behind (the parchment shows through)."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((14, 14, S - 14, S - 14), outline=(58, 35, 19, 150), width=6)
    d.ellipse((30, 30, S - 30, S - 30), outline=(148, 112, 31, 200), width=3)
    cx = S / 2
    pouch(d, cx, 104, 1.0, INK, GOLD)
    d.ellipse((cx - 52, 262, cx + 52, 366), fill=GOLD)
    d.ellipse((cx - 38, 276, cx + 38, 352), fill=GOLD_DEEP)
    d.ellipse((cx - 28, 286, cx + 28, 342), fill=GOLD)
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
    save(pin(False), "pin", 64)
    save(pin(True), "pin_rumour", 64)
    save(dot(), "dot", 32)
    save(glow(), "glow", 64)
    save(emblem(), "emblem", 256)


if __name__ == "__main__":
    main()
