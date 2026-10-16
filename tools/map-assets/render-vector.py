"""Satellite + crisp vector layer (roads, buildings, walls) from the terrain file.

  render-vector.py overview <tiles_dir> [size=8192]   -> overview8k.jpg (8K map for the editor)
  render-vector.py region <tiles_dir> x0 y0 x1 y1 mpp out.jpg   -> detailed crop for checking

Inputs are produced by extract-map-background.js / build-background.py (satellite
tiles + background.json) and build-vector-map.js (vector.json). Read-only on the
game files; writes only into the world's tiles folder (or the given output).
"""
import sys, json, math
from pathlib import Path
from PIL import Image, ImageDraw

Image.MAX_IMAGE_PIXELS = 400_000_000
STYLE = {  # fill, outline
    'track': ((176, 150, 104), None), 'road': ((222, 222, 214), None), 'main': ((236, 204, 120), None),
    'wall': ((215, 215, 210), None), 'building': ((128, 78, 64), (60, 34, 28)), 'house': ((72, 74, 84), (28, 29, 34)),
}
ORDER = ['track', 'road', 'main', 'wall', 'building', 'house']


def load(folder):
    folder = Path(folder)
    bg = json.loads((folder / 'background.json').read_text(encoding='utf-8'))
    vec = json.loads((folder / 'vector.json').read_text(encoding='utf-8'))
    if vec['worldSize'] != bg['worldSize']:
        raise ValueError('vector and satellite world sizes differ')
    return folder, bg, vec


def satellite(folder, bg, x0, y0, x1, y1, mpp):
    """Satellite mosaic for world rect [x0,x1]x[y0,y1] (y up) at mpp metres/pixel."""
    W, H = round((x1 - x0) / mpp), round((y1 - y0) / mpp)
    img = Image.new('RGB', (W, H), (25, 65, 90))
    size, sx, sy = bg['worldSize'], bg['strideX'], bg['strideY']
    missing = set(bg.get('missingTiles', []))
    for ty in range(bg['rows']):
        top = size - ty * sy; bottom = max(0, top - sy)
        if bottom >= y1 or top <= y0: continue
        for tx in range(bg['columns']):
            left = tx * sx; right = min(size, left + sx)
            if right <= x0 or left >= x1 or f'{tx}_{ty}' in missing: continue
            f = folder / 'tiles' / f'{tx}_{ty}.jpg'
            if not f.exists(): continue
            t = Image.open(f).convert('RGB')
            px0, py0 = round((left - x0) / mpp), round((y1 - top) / mpp)
            px1, py1 = round((right - x0) / mpp), round((y1 - bottom) / mpp)
            img.paste(t.resize((max(1, px1 - px0), max(1, py1 - py0)), Image.Resampling.LANCZOS), (px0, py0))
    return img


def draw_vectors(img, vec, x0, y0, x1, y1, mpp):
    d = ImageDraw.Draw(img, 'RGBA')
    tf = lambda x, y: ((x / 10 - x0) / mpp, (y1 - y / 10) / mpp)
    pad = 50 * 10
    # shapefile roads: [n, widthDm, kind, x1,y1,...]; real width, at least 1 px; tracks first, main roads on top
    rl = vec['layers'].get('roadline', []); lines = []; i = 0
    while i < len(rl):
        n, wdm, kind = rl[i], rl[i + 1], rl[i + 2]; xy = rl[i + 3:i + 3 + 2 * n]; i += 3 + 2 * n
        xs = xy[0::2]; ys = xy[1::2]
        if max(xs) < x0 * 10 - pad or min(xs) > x1 * 10 + pad or max(ys) < y0 * 10 - pad or min(ys) > y1 * 10 + pad: continue
        lines.append((kind, wdm, [tf(xs[k], ys[k]) for k in range(n)]))
    for kind in (2, 1, 0):
        color = {0: (236, 204, 120), 1: (222, 222, 214), 2: (176, 150, 104)}[kind]
        for k, wdm, pts in lines:
            if k == kind: d.line(pts, fill=color, width=max(1, round(wdm / 10 / mpp)), joint='curve')
    for name in ORDER:
        flat = vec['layers'].get(name, []); fill, outline = STYLE[name]
        for i in range(0, len(flat), 8):
            q = flat[i:i + 8]; xs = q[0::2]; ys = q[1::2]
            if max(xs) < x0 * 10 - pad or min(xs) > x1 * 10 + pad or max(ys) < y0 * 10 - pad or min(ys) > y1 * 10 + pad: continue
            # corners come as a strip (0,1,3,2 order makes the quad); keep the convex order
            pts = [tf(q[0], q[1]), tf(q[2], q[3]), tf(q[6], q[7]), tf(q[4], q[5])]
            d.polygon(pts, fill=fill, outline=outline if (outline and mpp < 3) else None)
    w = max(1, round(2 / mpp))
    for name, step, color in (('rail', 6, (60, 40, 40)), ('power', 4, (230, 210, 60))):
        flat = vec['layers'].get(name, [])
        for i in range(0, len(flat), step):
            q = flat[i:i + step]; pts = [tf(q[j], q[j + 1]) for j in range(0, len(q), 2)]
            d.line(pts, fill=color, width=w)
    return img


def overview(folder, size=8192):
    folder, bg, vec = load(folder)
    world = bg['worldSize']; mpp = world / size
    img = satellite(folder, bg, 0, 0, world, world, mpp)
    draw_vectors(img, vec, 0, 0, world, world, mpp)
    out = folder / 'overview8k.jpg'; tmp = folder / 'overview8k.tmp.jpg'
    img.save(tmp, quality=90, subsampling=0, optimize=True); tmp.replace(out)
    print(json.dumps({'overview8k': str(out), 'size': size, 'metersPerPixel': round(mpp, 3)}))


def region(folder, x0, y0, x1, y1, mpp, out):
    folder, bg, vec = load(folder)
    img = satellite(folder, bg, x0, y0, x1, y1, mpp)
    draw_vectors(img, vec, x0, y0, x1, y1, mpp)
    img.save(out, quality=92)
    print(json.dumps({'region': out, 'px': img.size}))


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'overview': overview(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 8192)
    elif mode == 'region': region(sys.argv[2], *map(float, sys.argv[3:8]), sys.argv[8])
    else: raise SystemExit(__doc__)
