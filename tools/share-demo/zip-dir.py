"""Zip a folder so the archive contains the folder itself as its single root.

usage: zip-dir.py <folder> <archive.zip>
"""
import os
import sys
import zipfile


def main(folder, archive):
    folder = os.path.abspath(folder)
    root = os.path.dirname(folder)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for base, _dirs, files in os.walk(folder):
            for name in sorted(files):
                path = os.path.join(base, name)
                # JPEGs are already compressed — store them to save build time.
                kind = zipfile.ZIP_STORED if name.lower().endswith(".jpg") else zipfile.ZIP_DEFLATED
                z.write(path, os.path.relpath(path, root), compress_type=kind)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
