#!/usr/bin/env python3
"""Cuts the three owner icon atlases in assets/icon/ into one 128 px PNG per item in assets/icon/items/.

Needs Pillow, numpy and scipy. Specks of stray colour around the icons are dropped: only connected
blobs of at least 3% of the biggest one are kept (a tusk pair is two big blobs)."""

from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ICONS = Path(__file__).resolve().parents[1] / "assets" / "icon"
OUT = ICONS / "items"
SIZE = 128
SHEETS = {
	"Low-poly nature inventory sprite sheet.png": (3, ["sticks", "flower", "grass", "mushroom", "berries", "dark_berries", "frog", "feather", "grub"]),
	"Eight low-poly primitive gear icons-2.png": (4, ["stone", "arrow", "spear", "sling", "bow", "net", "knife", "club"]),
	"Rooster, turkey, tusks, and steel gear-1.png": (4, ["rooster", "turkey", "tusk", "metal_plate", "component", "metal_tusk"]),
}


def cut(cell: Image.Image) -> Image.Image:
	alpha = np.array(cell)[:, :, 3]
	labels, count = ndimage.label(alpha > 128)
	sizes = ndimage.sum(np.ones_like(alpha), labels, range(1, count + 1))
	keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.03 * max(sizes)]
	mask = np.isin(labels, keep)
	mask = ndimage.binary_dilation(mask, iterations=3)  # keep the soft edge of the kept blobs
	data = np.array(cell)
	data[:, :, 3] = np.where(mask, data[:, :, 3], 0)
	icon = Image.fromarray(data).crop(Image.fromarray(data).getbbox())
	icon.thumbnail((SIZE, SIZE), Image.LANCZOS)
	canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
	canvas.paste(icon, ((SIZE - icon.width) // 2, (SIZE - icon.height) // 2))
	return canvas


def main() -> None:
	OUT.mkdir(exist_ok=True)
	for sheet, (cols, names) in SHEETS.items():
		image = Image.open(ICONS / sheet).convert("RGBA")
		rows = -(-len(names) // cols)
		w, h = image.width // cols, image.height // rows
		for i, name in enumerate(names):
			x, y = (i % cols) * w, (i // cols) * h
			cut(image.crop((x, y, x + w, y + h))).save(OUT / f"{name}.png")


if __name__ == "__main__":
	main()
