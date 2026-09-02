"""
Yer tutucu ("dama tahtasi") dokulari bul.

Bazi doku varyantlarinin dosyasi gercek bir doku degil, Rockstar'in eksik-doku
yer tutucusu: 64x64 boyutunda, iki renkli bir dama tahtasi. Render edilince
magazada dama tahtasi olarak gorunuyor.

Olcut: dokunun ALANI, ayni parcanin en buyuk varyantinin 1/16'sinden kucuk.
Yer tutucular 64x64, gercek dokular 512x512 -- arada 64 kat var.

"Benzersiz renk sayisi" olcutu DENENDI VE ISE YARAMADI: BC1 sikistirmasi ve
render'daki golgelendirme iki renkli bir dama tahtasini 671 farkli renge
cikariyor (olculdu, jacket 0 doku 6). Boyut yapisal bir sinyal, renk degil.

Cikti: placeholders.json  -> {slot: {drawable: [doku indeksleri]}}
       ve ekrana data/removed.lua'ya yapistirilabilir bir ozet.
"""

import os
import sys
import json
import time
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
import fivefury as ff
import batch
import render_ydd
from batch_tex import game_counts


def main():
    mapdir, dumpfile, outfile = sys.argv[1], sys.argv[2], sys.argv[3]

    want = batch.load_wanted(mapdir)
    counts = game_counts(dumpfile)

    t0 = time.time()
    ydds, ytds = {}, {}
    for src in batch.sources():
        try:
            a = ff.load_rpf(src)
        except Exception:
            continue
        batch.index_walk(a, want, ydds, ytds)
    print('indeks %.0f sn' % (time.time() - t0), flush=True)

    found = defaultdict(lambda: defaultdict(list))
    seen = 0
    for k in sorted(ydds):
        slot, drawable = want[k]
        folder, prefix, num = k
        ntex = counts.get(slot, {}).get(drawable, 0)
        by_letter = defaultdict(list)
        for letter, tar, te in ytds.get(k, []):
            by_letter[letter].append((tar, te))

        sizes = {}
        small = {}
        for t in range(ntex):
            letter = chr(ord('a') + t)
            for tar, te in by_letter.get(letter, []):
                try:
                    ytd = ff.read_ytd(tar.read_entry_standalone(te))
                except Exception:
                    continue
                name = '%s_diff_%03d_%s' % (prefix, num, letter)
                tex = next((x for x in ytd.textures
                            if (x.name or '').lower().startswith(name)), None)
                if tex is None:
                    continue
                sizes[t] = tex.width * tex.height
                small[t] = (tex.width, tex.height)
                seen += 1
                break

        if not sizes:
            continue
        big = max(sizes.values())
        for t in small:
            if sizes.get(t, 0) * 16 <= big:
                found[slot][drawable].append(t)

    total = sum(len(v) for m in found.values() for v in m.values())
    print('\n%d doku incelendi, %d yer tutucu bulundu (%.0f sn)'
          % (seen, total, time.time() - t0))
    for slot in sorted(found):
        n = sum(len(v) for v in found[slot].values())
        print('   %-8s %4d doku, %3d parcada' % (slot, n, len(found[slot])))

    json.dump({s: {str(d): sorted(v) for d, v in m.items()} for s, m in found.items()},
              open(outfile, 'w'), indent=1)
    print('yazildi: %s' % outfile)


if __name__ == '__main__':
    main()
