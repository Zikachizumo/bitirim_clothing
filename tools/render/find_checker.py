"""
Dama tahtasi (yer tutucu) dokulari KESIN olarak bul -- bayt esitligi ile.

Olculdu: Rockstar'in eksik-doku yer tutucusu her yerde AYNI DOSYA.
    jbib_000_g, jbib_013_e, feet_000_a, lowr_002_a
    -> dorduü de 64x64 BC1, 2728 bayt, sha1 cf8ff45d653c... birebir ayni

Bu yuzden boyut/renk gibi sezgisel olculere gerek yok: her dokunun ham
baytlari hash'lenir, ayni hash'i paylasanlar gruplanir. Gercek bir giysi
dokusu yer tutucuyla bayt bayt ayni olamaz, yani YANLIS POZITIF imkansiz.

Onceki yontem (boyut orani <= 1/16) iki durumu kaciriyordu:
  - parcanin BUTUN varyantlari yer tutucuysa (kiyas edilecek buyuk yok)
  - yer tutucu 64x64 degil de daha buyukse

Cikti:
    checker_groups.json  paylasilan her hash icin ornek liste + onizleme PNG
    checker_hits.json    {slot: {drawable: [doku indeksleri]}}  (--hash ile)

Kullanim:
    1) python find_checker.py <map> <dump> out/            -> gruplari cikar
       out/preview_<hash>.png dosyalarina GOZLE bak
    2) python find_checker.py <map> <dump> out/ --hash h1,h2  -> vurus listesi
"""

import os
import sys
import json
import time
import hashlib
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
import fivefury as ff
import pngio
import batch
import render_ydd
from batch_tex import game_counts


def scan(mapdir, dumpfile):
    """-> (hash -> [(slot, drawable, tex)]), (hash -> ornek Texture)"""
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
    print('indeks %.0f sn, %d parca' % (time.time() - t0, len(ydds)), flush=True)

    groups = defaultdict(list)
    sample = {}
    dims = {}
    seen = 0
    for k in sorted(ydds):
        slot, drawable = want[k]
        folder, prefix, num = k
        ntex = counts.get(slot, {}).get(drawable, 0)
        by_letter = defaultdict(list)
        for letter, tar, te in ytds.get(k, []):
            by_letter[letter].append((tar, te))

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
                h = hashlib.sha1(bytes(tex.data)).hexdigest()
                groups[h].append((slot, drawable, t))
                dims[h] = (tex.width, tex.height, tex.format_name)
                if h not in sample:
                    sample[h] = tex
                seen += 1
                break
        if seen and seen % 3000 == 0:
            print('  %d doku  %.0f sn' % (seen, time.time() - t0), flush=True)

    print('%d doku hash\'lendi, %d benzersiz' % (seen, len(groups)))
    return groups, sample, dims


def main():
    mapdir, dumpfile, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
    picked = None
    if '--hash' in sys.argv:
        picked = set(sys.argv[sys.argv.index('--hash') + 1].split(','))
    os.makedirs(outdir, exist_ok=True)

    cache = os.path.join(outdir, 'groups_raw.json')
    if os.path.exists(cache):
        groups = {h: [tuple(x) for x in v] for h, v in json.load(open(cache)).items()}
        sample = {}
        print('onbellekten okundu: %d grup' % len(groups))
    else:
        groups, sample, dims = scan(mapdir, dumpfile)
        json.dump({h: v for h, v in groups.items()}, open(cache, 'w'))
        json.dump(dims, open(os.path.join(outdir, 'dims.json'), 'w'))

    if picked is None:
        # Birden fazla PARCADA gecen dokular supheli. Ayni parcanin iki
        # varyantinin ayni olmasi normal degil ama tek basina kanit da degil.
        shared = {}
        for h, lst in groups.items():
            items = {(s, d) for s, d, _ in lst}
            if len(items) >= 2:
                shared[h] = lst
        print('\n%d hash birden fazla PARCADA gecyor:' % len(shared))
        for h, lst in sorted(shared.items(), key=lambda x: -len(x[1])):
            items = {(s, d) for s, d, _ in lst}
            slots = sorted({s for s, _, _ in lst})
            print('   %s  %5d doku  %4d parca  kategoriler: %s'
                  % (h[:12], len(lst), len(items), ','.join(slots)))
            tex = sample.get(h)
            if tex is not None:
                try:
                    px = render_ydd.decode_texture(tex)
                    pngio.write(os.path.join(outdir, 'preview_%s.png' % h[:12]), px)
                except Exception as ex:
                    print('        onizleme yazilamadi: %s' % ex)
        json.dump({h: lst for h, lst in shared.items()},
                  open(os.path.join(outdir, 'checker_groups.json'), 'w'))
        print('\nonizlemelere BAK, sonra --hash <h1,h2> ile calistir.')
        return

    hits = defaultdict(lambda: defaultdict(list))
    for h in picked:
        for slot, drawable, t in groups.get(h, []):
            hits[slot][drawable].append(t)
    total = sum(len(v) for m in hits.values() for v in m.values())
    print('\nsecilen %d hash -> %d doku, %d parca'
          % (len(picked), total, sum(len(m) for m in hits.values())))
    for slot in sorted(hits):
        n = sum(len(v) for v in hits[slot].values())
        print('   %-8s %4d doku, %3d parcada' % (slot, n, len(hits[slot])))
    json.dump({s: {str(d): sorted(v) for d, v in m.items()} for s, m in hits.items()},
              open(os.path.join(outdir, 'checker_hits.json'), 'w'), indent=1)
    print('yazildi: checker_hits.json')


if __name__ == '__main__':
    main()
