"""
SONDAJ: bir .ydd giysisini saydam arka planli PNG'ye render et.

Amac referanstaki gorunumu yakalamak: beden yok, sadece giysi, arkasi saydam.
Oyun ici ekran karesi ALMIYOR -- model dosyasindan ciziyor.

Bagimlilik: fivefury (Unlicense) + numpy. PIL yok.
"""

import os
import sys
import numpy as np
import fivefury as ff

# Gomulu Python'da python312._pth var -> betigin klasoru sys.path'e OTOMATIK
# eklenmiyor (ve PYTHONPATH de yok sayiliyor). Elle ekliyoruz.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pngio


# --------------------------------------------------------------- BC cozucu
# fivefury doku cozmuyor (sadece save_dds / to_dds_bytes veriyor), bu yuzden burada.

def _rgb565(c):
    r = ((c >> 11) & 0x1F).astype(np.uint16)
    g = ((c >> 5) & 0x3F).astype(np.uint16)
    b = (c & 0x1F).astype(np.uint16)
    return np.stack([(r * 527 + 23) >> 6,
                     (g * 259 + 33) >> 6,
                     (b * 527 + 23) >> 6], -1).astype(np.float32)


def _color_blocks(blk, punchthrough):
    """
    BC1 renk bloklari. blk (n,8) uint8 -> palet (n,4,3), indeks (n,16),
    ve 4. palet girdisi saydam mi (n,) maskesi.

    `punchthrough=True` (tek basina BC1): c0 <= c1 ise blok 3-renk + SAYDAM
    modundadir, indeks 3 = tamamen saydam. Bu goz ardi edilirse alpha ile
    kesilmis parcalar (or. kolsuz atletin kol yeri) dolu gorunur -- yasandi.
    `punchthrough=False` (BC3 icindeki renk blogu): her zaman 4-renk modu.
    """
    c0 = blk[:, 0].astype(np.uint16) | (blk[:, 1].astype(np.uint16) << 8)
    c1 = blk[:, 2].astype(np.uint16) | (blk[:, 3].astype(np.uint16) << 8)
    e0, e1 = _rgb565(c0), _rgb565(c1)

    pal = np.zeros((len(blk), 4, 3), np.float32)
    pal[:, 0], pal[:, 1] = e0, e1

    three = (c0 <= c1) & punchthrough
    pal[:, 2] = np.where(three[:, None], (e0 + e1) / 2.0, (2 * e0 + e1) / 3.0)
    pal[:, 3] = np.where(three[:, None], 0.0, (e0 + 2 * e1) / 3.0)

    bits = np.zeros(len(blk), np.uint32)
    for i in range(4):
        bits |= blk[:, 4 + i].astype(np.uint32) << np.uint32(8 * i)
    idx = np.stack([(bits >> np.uint32(2 * k)) & np.uint32(3) for k in range(16)], -1)
    return pal, idx.astype(np.uint8), three


def _alpha_blocks(blk):
    """BC3/BC4 alpha bloklari. blk (n,8) uint8 -> palet (n,8), indeks (n,16)."""
    a0 = blk[:, 0].astype(np.float32)
    a1 = blk[:, 1].astype(np.float32)

    pal = np.zeros((len(blk), 8), np.float32)
    pal[:, 0], pal[:, 1] = a0, a1
    gt = a0 > a1
    for i in range(2, 8):                                  # 8-alpha modu
        pal[:, i] = ((8 - i) * a0 + (i - 1) * a1) / 7.0
    for i in range(2, 6):                                  # 6-alpha modu
        pal[:, i] = np.where(gt, pal[:, i], ((6 - i) * a0 + (i - 1) * a1) / 5.0)
    pal[:, 6] = np.where(gt, pal[:, 6], 0.0)
    pal[:, 7] = np.where(gt, pal[:, 7], 255.0)

    bits = np.zeros(len(blk), np.uint64)
    for i in range(6):
        bits |= blk[:, 2 + i].astype(np.uint64) << np.uint64(8 * i)
    idx = np.stack([(bits >> np.uint64(3 * k)) & np.uint64(7) for k in range(16)], -1)
    return pal, idx.astype(np.uint8)


def decode_texture(tex):
    """fivefury Texture -> (h,w,4) uint8 RGBA, sadece mip 0."""
    w, h, fmt = tex.width, tex.height, tex.format_name
    bw, bh = (w + 3) // 4, (h + 3) // 4
    size = tex.mip_sizes[0] if tex.mip_sizes else len(tex.data)
    raw = np.frombuffer(tex.data[:size], np.uint8)

    if fmt not in ('BC1', 'BC3'):
        raise NotImplementedError('desteklenmeyen doku formati: %s' % fmt)

    stride = 8 if fmt == 'BC1' else 16
    blocks = raw[:bw * bh * stride].reshape(bh * bw, stride)
    if fmt == 'BC3':
        apal, aidx = _alpha_blocks(blocks[:, :8])
        cpal, cidx, _ = _color_blocks(blocks[:, 8:], punchthrough=False)
        a = np.take_along_axis(apal, aidx.astype(np.intp), 1)
    else:
        cpal, cidx, three = _color_blocks(blocks, punchthrough=True)
        # 3-renk modunda indeks 3 = saydam
        a = np.where(three[:, None] & (cidx == 3), 0.0, 255.0).astype(np.float32)
    rgb = np.take_along_axis(cpal, cidx.astype(np.intp)[:, :, None].repeat(3, 2), 1)

    px = np.concatenate([rgb, a[:, :, None]], 2).reshape(bh, bw, 4, 4, 4)
    px = px.transpose(0, 3, 1, 2, 4).reshape(bh * 4, bw * 4, 4)
    return np.clip(px[:h, :w], 0, 255).astype(np.uint8)


# ------------------------------------------------------------- rasterizer

def _sample(img, uv, tw, th):
    """Bilinear doku ornekleme. Nearest kullanildiginda dikislerde kare kare
    basamaklar goruluyordu."""
    fu = (uv[:, 0] % 1.0) * tw - 0.5
    fv = (uv[:, 1] % 1.0) * th - 0.5
    u0 = np.floor(fu).astype(np.intp)
    v0 = np.floor(fv).astype(np.intp)
    du = (fu - u0)[:, None]
    dv = (fv - v0)[:, None]

    u0m, u1m = u0 % tw, (u0 + 1) % tw
    v0m, v1m = v0 % th, (v0 + 1) % th
    t00 = img[v0m, u0m].astype(np.float32)
    t10 = img[v0m, u1m].astype(np.float32)
    t01 = img[v1m, u0m].astype(np.float32)
    t11 = img[v1m, u1m].astype(np.float32)
    return (t00 * (1 - du) + t10 * du) * (1 - dv) + (t01 * (1 - du) + t11 * du) * dv


def render(ydd_path, ytd_path, out_path, size=512, ss=3, margin=0.06,
           yaw=0.0, quiet=False, prefer=None):
    """
    `prefer`: doku adi oneki (kucuk harf). Doku VARYANTI render edilirken
    gerekiyor -- mesh'in materyali her zaman 'a' varyantini isaret ediyor
    ('jbib_diff_000_a_uni'), oysa 'b' varyantinin .ytd'sinde doku
    'jbib_diff_000_b_uni' adiyla duruyor. Ad esitligi tutmaz, o yuzden
    dogru varyantin adi disaridan veriliyor.
    """
    ydr = ff.read_ydd(ydd_path).drawables[0].drawable
    meshes = ydr.primary_meshes                    # sadece HIGH LOD
    if not meshes:
        raise RuntimeError('HIGH LOD mesh yok')

    # dokuyu ADIYLA esle -- ilkine korlemesine guvenme
    ytd = ff.read_ytd(ytd_path)
    # Buyuk/kucuk harf duyarsiz: materyalde 'Jbib_diff_000_a_uni' yazarken
    # dosyada 'jbib_diff_000_a_uni' oluyor (olculdu, biker jbib_000).
    want = (meshes[0].material.primary_texture_name or '').lower()
    tex = None
    if prefer:
        tex = next((t for t in ytd.textures
                    if (t.name or '').lower().startswith(prefer)), None)
    if tex is None:
        tex = next((t for t in ytd.textures if (t.name or '').lower() == want), None)

    # Korlemesine ytd.textures[0]'a dusmek YASAK: oyle yapinca gozluk drawable 0
    # icin 'givemechecker' (GTA'nin eksik-doku yer tutucusu) secildi ve dama
    # tahtasi bir kare uretildi. Once ADIYLA, olmazsa dosyadaki TEK gercek
    # diffuse ile; o da yoksa uretmiyoruz -- parca oyun ici karesiyle kalir.
    if tex is None:
        real = [t for t in ytd.textures
                if '_diff_' in (t.name or '').lower()
                and 'checker' not in (t.name or '').lower()]
        if len(real) == 1:
            tex = real[0]
        else:
            raise LookupError('doku secilemedi: istenen %r, dosyada %s'
                              % (want, [t.name for t in ytd.textures[:5]]))
    if 'checker' in (tex.name or '').lower():
        raise LookupError('yer tutucu doku: %r' % tex.name)
    img = decode_texture(tex)
    th, tw = img.shape[:2]

    # --- geometri (HIGH LOD meshleri birlestir)
    Ps, Ns, UVs, Fs = [], [], [], []
    base = 0
    for m in meshes:
        Ps.append(np.array([[v.x, v.y, v.z] for v in m.positions], np.float32))
        Ns.append(np.array([[v.x, v.y, v.z] for v in m.normals], np.float32))
        UVs.append(np.array([[t.x, t.y] for t in m.texcoords[0]], np.float32))
        Fs.append(np.array(m.indices, np.int32).reshape(-1, 3) + base)
        base += m.vertex_count
    P = np.concatenate(Ps)
    N = np.concatenate(Ns)
    UV = np.concatenate(UVs)
    F = np.concatenate(Fs)

    # --- kamera: ortografik, Z ekseni etrafinda yaw ile donuyor.
    # GTA ped uzayi OLCULDU: X yanlamasina, Y derinlik, Z yukari.
    # Kamera yonu c=(sin,cos); bakis f=-c; ekran sagi r=(f_y,-f_x)=(-cos,sin).
    # yaw=0 -> +Y'den bakis (on), yaw=180 -> arka.
    cx, cy = np.sin(np.radians(yaw)), np.cos(np.radians(yaw))
    sx = P[:, 0] * (-cy) + P[:, 1] * cx
    sy = P[:, 2]
    depth = P[:, 0] * cx + P[:, 1] * cy

    lo = np.array([sx.min(), sy.min()])
    hi = np.array([sx.max(), sy.max()])
    span = (hi - lo).max() * (1.0 + 2 * margin)
    ctr = (hi + lo) / 2.0

    R = size * ss
    px = (sx - ctr[0]) / span * R + R / 2.0
    py = (ctr[1] - sy) / span * R + R / 2.0        # ekran y asagi bakar

    colour = np.zeros((R, R, 3), np.float32)
    alpha = np.zeros((R, R), np.float32)
    zbuf = np.full((R, R), -1e9, np.float32)

    # Giysiler acik kabuk (ic yuz de gorunuyor) -> cift tarafli aydinlatma:
    # normalin isaretini yok sayiyoruz, yoksa ic yuzler simsiyah kaliyor.
    key = np.array([-0.35 * cy - 0.80 * cx, 0.80 * cy - 0.35 * cx, 0.45], np.float32)
    key /= np.linalg.norm(key)

    for tri in F:
        x0, x1, x2 = px[tri]
        y0, y1, y2 = py[tri]
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue

        xmin = max(int(np.floor(min(x0, x1, x2))), 0)
        xmax = min(int(np.ceil(max(x0, x1, x2))), R - 1)
        ymin = max(int(np.floor(min(y0, y1, y2))), 0)
        ymax = min(int(np.ceil(max(y0, y1, y2))), R - 1)
        if xmin > xmax or ymin > ymax:
            continue

        gx, gy = np.meshgrid(np.arange(xmin, xmax + 1) + 0.5,
                             np.arange(ymin, ymax + 1) + 0.5)

        w0 = ((x1 - x0) * (gy - y0) - (gx - x0) * (y1 - y0)) / area
        w1 = ((gx - x0) * (y2 - y0) - (x2 - x0) * (gy - y0)) / area
        w2 = 1.0 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not inside.any():
            continue

        yy, xx = np.nonzero(inside)
        # barycentric -> kose eslemesi: w2->v0, w1->v1, w0->v2
        b = np.stack([w2[inside], w1[inside], w0[inside]], -1)
        d = b @ depth[tri]

        keep = d > zbuf[yy + ymin, xx + xmin]
        if not keep.any():
            continue
        b, d, yy, xx = b[keep], d[keep], yy[keep], xx[keep]

        texel = _sample(img, b @ UV[tri], tw, th)

        vis = texel[:, 3] > 127                    # alpha-cutout
        if not vis.any():
            continue
        b, d, yy, xx, texel = b[vis], d[vis], yy[vis], xx[vis], texel[vis]

        nrm = b @ N[tri]
        nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-6)
        shade = 0.34 + 0.66 * np.abs(nrm @ key)                  # ambient + anahtar isik
        rim = 0.18 * (1.0 - np.abs(nrm[:, 0] * cx + nrm[:, 1] * cy)) ** 2   # kenar isigi

        yy, xx = yy + ymin, xx + xmin
        colour[yy, xx] = np.clip(texel[:, :3] * (shade + rim)[:, None], 0, 255)
        alpha[yy, xx] = 255.0
        zbuf[yy, xx] = d

    # supersample indirgeme -> kenarlar ve alpha yumusar
    out = np.concatenate([colour, alpha[:, :, None]], 2)
    out = out.reshape(size, ss, size, ss, 4).mean((1, 3))

    # Kenar pikselinde renk, kapsanmayan alt-orneklerin siyahiyla ortalanip
    # kararir. Alpha ile geri normalize et, yoksa siluetin cevresi is gibi olur.
    a = out[:, :, 3:4] / 255.0
    rgb = np.where(a > 1e-3, out[:, :, :3] / np.maximum(a, 1e-3), 0.0)
    rgba = np.clip(np.concatenate([rgb, out[:, :, 3:4]], 2), 0, 255).astype(np.uint8)

    pngio.write(out_path, rgba)
    if not quiet:
        print('  %s  %dx%d  doluluk %%%.1f  doku %s %dx%d  ucgen %d'
              % (out_path.rsplit('/', 1)[-1], size, size,
                 (rgba[:, :, 3] > 0).mean() * 100, tex.format_name, tw, th, len(F)))
    return rgba


if __name__ == '__main__':
    render(sys.argv[1], sys.argv[2], sys.argv[3],
           size=int(sys.argv[4]) if len(sys.argv) > 4 else 512,
           yaw=float(sys.argv[5]) if len(sys.argv) > 5 else 0.0)
