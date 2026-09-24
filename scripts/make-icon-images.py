#!/usr/bin/env python3
"""Derives Resources/AppIcon.png and the status-item template images from the picked icon candidate (#39).

    scripts/make-icon-images.py [source]   # default: docs/icon-candidates/round2-2.png

The generated candidate is a two-colour tile (olive, cream glyph) on a white canvas, drawn freehand and not
on the macOS grid. Rather than cutting the tile out as drawn, this repaints it cleanly:

- The glyph is the cream area not connected to the canvas border (a flood fill from the corner removes the
  white canvas); its anti-aliased edge becomes alpha by interpolating luminance between tile and glyph colour.
- AppIcon.png: 1024x1024, transparent outside an 824x824 rounded tile (radius 185, the macOS app-icon grid) in
  the tile's median colour, with the glyph centred on it at the scale it had on the generated tile.
- StatusItem.png / StatusItem@2x.png: the glyph alone, black on transparent (loaded as a template image), fitted
  into 18x18 / 36x36 with 1 px / 2 px padding. At 18 px the source's gap between the lifted bar and the block
  would be about 1 px and blur shut, so the bar is moved up to widen the gap to about 2 px at 18 px.

The segmentation is specific to round2-2.png's composition: one light glyph, disconnected from the edges, on a
dark flat tile, on a white canvas. Any other source fails with a message rather than producing a wrong icon.

Needs Pillow and NumPy. Deterministic: the same source always yields the same files.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPOSITORY = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = REPOSITORY / "docs/icon-candidates/round2-2.png"
RESOURCES = REPOSITORY / "Resources"

CANVAS = 1024
TILE = 824
TILE_RADIUS = 185
SUPERSAMPLE = 4
WHITE_DISTANCE = 60  # summed RGB distance from white above which a pixel belongs to the tile
LIGHT_LUMINANCE = 200  # glyph pixels are at least this light; the tile is far darker
STATUS_GAP_FRACTION = 2 / 16  # minimum bar-to-block gap as a share of the status glyph height


def luminance(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def analyse(source):
    """Returns (tile colour, glyph colour, glyph alpha cropped to its bounding box, tile width in source px)."""
    rgb = np.asarray(Image.open(source).convert("RGB")).astype(float)
    tile_mask = np.abs(rgb - 255).sum(axis=2) > WHITE_DISTANCE
    ys, xs = np.where(tile_mask)
    tile_width = xs.max() - xs.min() + 1

    light = Image.fromarray(((luminance(rgb) > LIGHT_LUMINANCE) * 255).astype(np.uint8)).copy()  # writable
    ImageDraw.floodfill(light, (0, 0), 128)  # the white canvas, connected to the border
    glyph_core = np.asarray(light) == 255
    if not glyph_core.any():
        sys.exit(f"error: {source}: no light glyph found inside the tile (expected a light glyph on a dark tile, not touching its border)")
    cy, cx = np.where(glyph_core)
    if cx.min() <= xs.min() or cx.max() >= xs.max() or cy.min() <= ys.min() or cy.max() >= ys.max():
        sys.exit(f"error: {source}: the light glyph touches the tile border; this script expects it inside the tile")
    tile_only = tile_mask & ~np.asarray(Image.fromarray(glyph_core).filter(ImageFilter.MaxFilter(9)))
    tile_colour = np.median(rgb[tile_only], axis=0)
    glyph_colour = np.median(rgb[glyph_core], axis=0)

    near_glyph = np.asarray(Image.fromarray(glyph_core).filter(ImageFilter.MaxFilter(7)))
    tile_lum, glyph_lum = luminance(tile_colour), luminance(glyph_colour)
    edge = np.clip((luminance(rgb) - tile_lum) / (glyph_lum - tile_lum), 0, 1) * near_glyph
    alpha = np.maximum(edge, glyph_core)  # solid inside, so the glyph's own grain never shows the tile through
    gy, gx = np.where(alpha > 0.5)
    crop = alpha[gy.min() : gy.max() + 1, gx.min() : gx.max() + 1]
    return tile_colour, glyph_colour, crop, tile_width


def to_image(alpha):
    return Image.fromarray((alpha * 255).round().astype(np.uint8), "L")


def app_icon(tile_colour, glyph_colour, glyph_alpha, tile_width):
    big = CANVAS * SUPERSAMPLE
    tile_mask = Image.new("L", (big, big), 0)
    offset = (CANVAS - TILE) // 2 * SUPERSAMPLE
    ImageDraw.Draw(tile_mask).rounded_rectangle(
        (offset, offset, big - offset - 1, big - offset - 1), radius=TILE_RADIUS * SUPERSAMPLE, fill=255
    )
    tile_mask = tile_mask.resize((CANVAS, CANVAS), Image.LANCZOS)

    scale = TILE / tile_width
    height, width = glyph_alpha.shape
    glyph = to_image(glyph_alpha).resize((round(width * scale), round(height * scale)), Image.LANCZOS)
    glyph_mask = Image.new("L", (CANVAS, CANVAS), 0)
    glyph_mask.paste(glyph, ((CANVAS - glyph.width) // 2, (CANVAS - glyph.height) // 2))

    icon = Image.new("RGBA", (CANVAS, CANVAS), tuple(int(c) for c in tile_colour.round()) + (0,))
    icon.putalpha(tile_mask)
    cream = Image.new("RGBA", (CANVAS, CANVAS), tuple(int(c) for c in glyph_colour.round()) + (255,))
    icon.paste(cream, (0, 0), glyph_mask)
    return icon


def widen_gap(glyph_alpha):
    """Moves everything above the first empty row band (the lifted bar) up until the band is wide enough."""
    rows_with_ink = (glyph_alpha > 0.5).any(axis=1)
    empty = np.where(~rows_with_ink)[0]
    if empty.size == 0:
        return glyph_alpha
    gap_start, gap_end = empty.min(), empty.max() + 1
    wanted = int(np.ceil(STATUS_GAP_FRACTION * glyph_alpha.shape[0]))
    extra = max(0, wanted - (gap_end - gap_start))
    top, bottom = glyph_alpha[:gap_start], glyph_alpha[gap_end:]
    band = np.zeros((gap_end - gap_start + extra, glyph_alpha.shape[1]))
    return np.vstack([top, band, bottom])


def status_item(glyph_alpha, size, padding):
    inner = size - 2 * padding
    height, width = glyph_alpha.shape
    scale = inner / max(height, width)
    glyph = to_image(glyph_alpha).resize(
        (max(1, round(width * scale)), max(1, round(height * scale))), Image.LANCZOS
    )
    mask = Image.new("L", (size, size), 0)
    mask.paste(glyph, ((size - glyph.width) // 2, (size - glyph.height) // 2))
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    image.paste(Image.new("RGBA", (size, size), (0, 0, 0, 255)), (0, 0), mask)
    return image


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    tile_colour, glyph_colour, glyph_alpha, tile_width = analyse(source)
    RESOURCES.mkdir(exist_ok=True)
    app_icon(tile_colour, glyph_colour, glyph_alpha, tile_width).save(RESOURCES / "AppIcon.png")
    status_glyph = widen_gap(glyph_alpha)
    status_item(status_glyph, 18, 1).save(RESOURCES / "StatusItem.png")
    status_item(status_glyph, 36, 2).save(RESOURCES / "StatusItem@2x.png")
    print(f"tile {tile_colour.round()} glyph {glyph_colour.round()} -> {RESOURCES}")


if __name__ == "__main__":
    main()
