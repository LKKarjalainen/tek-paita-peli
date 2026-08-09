#!/usr/bin/env python3
"""Read marker positions off a hand-drawn map PNG.

    python3 tools/scan_map.py world/maps/kattila.png

Markers:
    yellow  (255,255,0)  a place to search
    cyan    (0,255,255)  a doorway
    magenta (255,0,255)  a person to ask

Because each map is drawn at the origin of its room at 1:1, the centre printed
here is the world position to put the Area2D at -- paste it straight into the
.tscn.

Where a doorway leads is read off the region colour it opens onto, which in
käytävä is: red = Aula, blue = Kattila, green = outdoors, orange = Varasto.
That legend is not machine-checked; this script only reports geometry.

Re-run this whenever a map is redrawn; the numbers in the room scenes are only
as current as the last run.
"""

import sys
from collections import deque

from PIL import Image

MARKERS = {
    "search": (255, 255, 0),
    "door": (0, 255, 255),
    "npc": (255, 0, 255),
}
TOLERANCE = 30
MIN_BLOB = 12


def near(c, target):
    return all(abs(a - b) <= TOLERANCE for a, b in zip(c, target))


def blobs(px, w, h, target):
    seen = set()
    out = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or not near(px[x, y], target):
                continue
            queue = deque([(x, y)])
            seen.add((x, y))
            pts = []
            while queue:
                cx, cy = queue.popleft()
                pts.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and near(px[nx, ny], target):
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            if len(pts) >= MIN_BLOB:
                out.append(pts)
    return out


def main(paths):
    for path in paths:
        im = Image.open(path).convert("RGB")
        w, h = im.size
        px = im.load()
        print(f"{path}  {w}x{h}")
        for kind, colour in MARKERS.items():
            found = blobs(px, w, h, colour)
            if not found:
                print(f"  no {kind} markers")
            for pts in sorted(found, key=lambda p: (min(b for _, b in p), min(a for a, _ in p))):
                xs = [a for a, _ in pts]
                ys = [b for _, b in pts]
                print(
                    f"  {kind:8s} position = Vector2({sum(xs) // len(xs)}, {sum(ys) // len(ys)})"
                    f"   size ~{max(xs) - min(xs) + 1}x{max(ys) - min(ys) + 1}"
                )


if __name__ == "__main__":
    main(sys.argv[1:] or ["world/maps/kaytava.png", "world/maps/kattila.png", "world/maps/varasto.png"])
