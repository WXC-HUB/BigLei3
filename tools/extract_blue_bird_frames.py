"""Derive transparent blue-bird animation frames from the supplied green sheet.

This is deterministic asset preparation only: no image generation is involved.
"""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"C:\Users\claude.wu\Downloads\image (2).png")
FRAME_DIR = PROJECT_ROOT / "assets" / "birds" / "blue"
STAGE_SOURCE = PROJECT_ROOT / "assets" / "backgrounds" / "birdwatch-tree-stage.png"
STAGE_CLEAN = PROJECT_ROOT / "assets" / "backgrounds" / "birdwatch-tree-stage-no-blue.png"

SHEET_COLUMNS = 4
SHEET_ROWS = 2
FRAME_WIDTH = 448
OUTPUT_HEIGHT = 336
ROW_CROP_TOPS = (165, 620)


def _remove_green(frame: np.ndarray) -> np.ndarray:
	"""Turn the neon key into alpha while preserving the olive leaves."""
	rgb = frame.astype(np.float32)
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	key_strength = np.minimum(g - 1.65 * r, g - 1.65 * b)
	alpha = np.clip((42.0 - key_strength) / 34.0, 0.0, 1.0)
	alpha[g < 145.0] = 1.0

	# Remove the green spill only along semi-transparent antialiased edges.
	edge = (alpha > 0.0) & (alpha < 1.0)
	g[edge] = np.minimum(g[edge], np.maximum(r[edge], b[edge]) * 1.15)
	rgba = np.clip(np.dstack((r, g, b, alpha * 255.0)), 0, 255).astype(np.uint8)

	# Cell edges contain occasional fragments from the neighbouring drawing.
	# Keep the main connected bird/branch plus intentional interior accents.
	component_mask = (rgba[..., 3] > 96).astype(np.uint8)
	count, labels, stats, _centroids = cv2.connectedComponentsWithStats(component_mask, 8)
	if count > 1:
		largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
		keep = labels == largest
		for label in range(1, count):
			if label == largest:
				continue
			x, _y, width, _height, area = stats[label]
			touches_side = x == 0 or x + width >= rgba.shape[1]
			if area >= 18 and not touches_side:
				keep |= labels == label
		rgba[..., 3][~keep] = 0
	return rgba


def extract_frames() -> None:
	FRAME_DIR.mkdir(parents=True, exist_ok=True)
	sheet = np.asarray(Image.open(SOURCE).convert("RGB"))
	for row in range(SHEET_ROWS):
		top = ROW_CROP_TOPS[row]
		for column in range(SHEET_COLUMNS):
			left = column * FRAME_WIDTH
			frame = sheet[top : top + OUTPUT_HEIGHT, left : left + FRAME_WIDTH]
			rgba = _remove_green(frame)
			index = row * SHEET_COLUMNS + column + 1
			Image.fromarray(rgba, "RGBA").save(FRAME_DIR / f"blue_bird_{index:02d}.png")


def clean_baked_blue_bird() -> None:
	"""Remove only the saturated blue silhouette of the old top-left bird."""
	image = cv2.imread(str(STAGE_SOURCE), cv2.IMREAD_COLOR)
	if image is None:
		raise FileNotFoundError(STAGE_SOURCE)
	hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
	blue = cv2.inRange(hsv, np.array([88, 80, 45]), np.array([125, 255, 255]))
	roi = np.zeros_like(blue)
	roi[:205, :260] = 255
	blue = cv2.bitwise_and(blue, roi)
	blue = cv2.morphologyEx(blue, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
	mask = np.zeros_like(blue)
	contours, _hierarchy = cv2.findContours(blue, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
	for contour in contours:
		if cv2.contourArea(contour) >= 80:
			cv2.drawContours(mask, [contour], -1, 255, cv2.FILLED)
	mask = cv2.dilate(mask, np.ones((9, 9), np.uint8), iterations=1)
	clean = cv2.inpaint(image, mask, 7, cv2.INPAINT_NS)
	if not cv2.imwrite(str(STAGE_CLEAN), clean):
		raise OSError(f"Could not write {STAGE_CLEAN}")


if __name__ == "__main__":
	extract_frames()
	clean_baked_blue_bird()
	print(f"Wrote 8 frames to {FRAME_DIR}")
	print(f"Wrote clean stage to {STAGE_CLEAN}")
