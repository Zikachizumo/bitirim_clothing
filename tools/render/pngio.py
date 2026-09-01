"""
PNG oku/yaz. PIL yok, elle.

DIKKAT: IDAT 8192'lik parcalara bolunuyor ve sRGB chunk'i ekleniyor.
Tek dev IDAT'li dosyayi goruntuleyici reddetti (olculdu 2026-09-01); kendi
cozuculerim okuyordu ama calisan dosyalarin yapisi boyleydi, ona uyduruldu.
"""

import zlib
import struct
import numpy as np

SIG = bytes([137, 80, 78, 71, 13, 10, 26, 10])


def _chunk(tag, data):
    c = struct.pack('>I', len(data)) + tag + data
    return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)


def write(path, px):
    """px: (h,w,3) veya (h,w,4) uint8."""
    h, w, ch = px.shape
    if ch not in (3, 4):
        raise ValueError('3 veya 4 kanal bekleniyor, %d geldi' % ch)

    # Her satirin basina TEK filtre bayti. (np.concatenate ile (h,1,ch) sifir
    # eklemek ch bayt ekler -- satir adimi kayar, goruntu kademe kademe
    # oteleniyordu. Bu hata yasandi, yatay serit gibi gorunuyor.)
    rows = np.zeros((h, w * ch + 1), np.uint8)
    rows[:, 1:] = px.reshape(h, w * ch)
    comp = zlib.compress(rows.tobytes(), 9)

    out = [SIG,
           _chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6 if ch == 4 else 2, 0, 0, 0)),
           _chunk(b'sRGB', bytes([0]))]
    for i in range(0, len(comp), 8192):
        out.append(_chunk(b'IDAT', comp[i:i + 8192]))
    out.append(_chunk(b'IEND', b''))

    with open(path, 'wb') as f:
        f.write(b''.join(out))


def read(path):
    """-> (h,w,ch) uint8. Sadece 8-bit, interlace yok."""
    d = open(path, 'rb').read()
    if d[:8] != SIG:
        raise ValueError('PNG imzasi yok')

    off, idat, w, h, ct = 8, [], None, None, None
    while off < len(d):
        ln = struct.unpack('>I', d[off:off + 4])[0]
        tag = d[off + 4:off + 8]
        data = d[off + 8:off + 8 + ln]
        if tag == b'IHDR':
            w, h, bd, ct = struct.unpack('>IIBB', data[:10])
            if bd != 8:
                raise ValueError('sadece 8-bit destekleniyor')
        elif tag == b'IDAT':
            idat.append(data)
        elif tag == b'IEND':
            break
        off += 12 + ln

    ch = {0: 1, 2: 3, 4: 2, 6: 4}[ct]
    raw = zlib.decompress(b''.join(idat))
    stride = w * ch
    out = np.zeros((h, stride), np.uint8)

    pos = 0
    for y in range(h):
        f = raw[pos]
        pos += 1
        line = np.frombuffer(raw[pos:pos + stride], np.uint8).astype(np.int32)
        pos += stride
        prev = out[y - 1].astype(np.int32) if y else np.zeros(stride, np.int32)

        if f == 0:
            cur = line
        elif f == 2:                              # Up: satir icinde bagimlilik yok
            cur = (line + prev) & 0xFF
        else:                                     # Sub/Average/Paeth: soldan bagimli
            cur = np.zeros(stride, np.int32)
            for x in range(stride):
                a = cur[x - ch] if x >= ch else 0
                b = prev[x]
                c = prev[x - ch] if x >= ch else 0
                v = line[x]
                if f == 1:
                    v += a
                elif f == 3:
                    v += (a + b) // 2
                elif f == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    v += a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                cur[x] = v & 0xFF
        out[y] = cur.astype(np.uint8)

    return out.reshape(h, w, ch)


def over(rgba, bg=(30, 30, 30)):
    """Saydam goruntuyu duz zemine bindir -> (h,w,3)."""
    a = rgba[:, :, 3:4].astype(np.float32) / 255.0
    back = np.array(bg, np.float32).reshape(1, 1, 3)
    return np.clip(rgba[:, :, :3].astype(np.float32) * a + back * (1 - a), 0, 255).astype(np.uint8)
