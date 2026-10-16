"""Downscale map overviews for the shareable demo copy.

usage: resize-overviews.py <width> <quality> <src> <dst> [<src> <dst> ...]
"""
import sys
from PIL import Image

Image.MAX_IMAGE_PIXELS = None


def main(argv):
    width, quality = int(argv[1]), int(argv[2])
    pairs = argv[3:]
    if not pairs or len(pairs) % 2:
        raise SystemExit("expected <src> <dst> pairs")
    for src, dst in zip(pairs[0::2], pairs[1::2]):
        with Image.open(src) as im:
            im = im.convert("RGB")
            if im.width > width:
                im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
            im.save(dst, "JPEG", quality=quality, optimize=True, progressive=True)


if __name__ == "__main__":
    main(sys.argv)
