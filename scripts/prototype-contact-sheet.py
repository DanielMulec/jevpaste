#!/usr/bin/env python3
# PROTOTYPE — menu-settings, never merged. Contact sheet: 4 across, each cell numbered in a big label.
# usage: prototype-contact-sheet.py <out.png> <title> <cell.png> [caption] ...   (pairs: image, caption)
import sys
from PIL import Image, ImageDraw, ImageFont

out, title, rest = sys.argv[1], sys.argv[2], sys.argv[3:]
cells = [(rest[i], rest[i + 1]) for i in range(0, len(rest), 2)]
CELL_W, PAD, HEAD, CAP = 900, 30, 110, 70
images = []
for path, caption in cells:
    im = Image.open(path).convert("RGBA")
    scale = min(1.0, (CELL_W - 2 * PAD) / im.width)
    images.append((im.resize((int(im.width * scale), int(im.height * scale))), caption))
cols = 4
rows = (len(images) + cols - 1) // cols
row_h = [max(im.height for im, _ in images[r * cols:(r + 1) * cols]) + CAP + 2 * PAD for r in range(rows)]
sheet = Image.new("RGB", (cols * CELL_W, HEAD + sum(row_h)), (242, 242, 245))
draw = ImageDraw.Draw(sheet)
def font(size, bold=False):
    for name in (["/System/Library/Fonts/Supplemental/Arial Bold.ttf"] if bold else []) + [
            "/System/Library/Fonts/Supplemental/Arial Unicode.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()
draw.text((PAD, 30), title, fill=(20, 20, 20), font=font(44, True))
y = HEAD
for r in range(rows):
    for c in range(cols):
        i = r * cols + c
        if i >= len(images):
            break
        im, caption = images[i]
        x = c * CELL_W
        draw.rectangle([x + 8, y + 8, x + CELL_W - 8, y + row_h[r] - 8], outline=(200, 200, 205), width=2)
        sheet.paste(im, (x + (CELL_W - im.width) // 2, y + PAD + CAP), im)
        draw.ellipse([x + 18, y + 16, x + 88, y + 86], fill=(10, 100, 230))
        label = str(i + 1)
        f = font(46, True)
        w = draw.textlength(label, font=f)
        draw.text((x + 53 - w / 2, y + 24), label, fill="white", font=f)
        draw.text((x + 104, y + 34), caption, fill=(40, 40, 40), font=font(28))
    y += row_h[r]
sheet.save(out)
print(out, sheet.size)
