"""
512x512 render'leri 256x256'ya indir.

ALFA AGIRLIKLI ortalama sart: duz ortalama alinca saydam piksellerin siyahi
renge karisiyor ve siluetin cevresi is gibi kararıyor (olculdu).
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import pngio


def shrink(src, dst, size=256):
    px = pngio.read(src).astype(np.float32)
    h, w = px.shape[:2]
    k = h // size
    if k < 1 or h % size or w % size:
        raise ValueError('%s: %dx%d -> %d tam bolunmuyor' % (src, w, h, size))
    blocks = px.reshape(size, k, size, k, 4)
    a = blocks[:, :, :, :, 3:4]
    asum = a.sum((1, 3))
    rgb = (blocks[:, :, :, :, :3] * a).sum((1, 3)) / np.maximum(asum, 1e-6)
    out = np.concatenate([rgb, asum / (k * k)], 2)
    pngio.write(dst, np.clip(out, 0, 255).astype(np.uint8))


if __name__ == '__main__':
    srcdir, dstdir = sys.argv[1], sys.argv[2]
    os.makedirs(dstdir, exist_ok=True)
    n = skip = 0
    for f in sorted(os.listdir(srcdir)):
        if not f.endswith('.png'):
            continue
        d = os.path.join(dstdir, f)
        if os.path.exists(d):
            skip += 1
            continue
        shrink(os.path.join(srcdir, f), d)
        n += 1
    print('%d yeni, %d zaten vardi' % (n, skip))
