"""
Tum DLC paketlerini tara: erkek freemode giysi/prop drawable sayilarini cikar.

Amac tek bir soruyu cevaplamak: dosyalardan sayilan toplam, oyunun calisirken
verdigi katalogla tutuyor mu? (mağaza: jbib/ust 544, lowr/pantolon 202,
feet/ayakkabi 151, accs/tisort 213, p_head/sapka 221, p_eyes/gozluk 59)
"""

import re
import sys
import json
import time
from collections import defaultdict

import fivefury as ff

GTA = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced'
DLC = GTA + r'\update\x64\dlcpacks'

COMP = re.compile(r'^([a-z]+)_(\d{3})_([a-z])\.ydd$')
PROP = re.compile(r'^(p_[a-z]+)_(\d{3})\.ydd$')


def collect(archive, out, who_prefix):
    """archive icindeki .ydd'leri say. out[klasor][prefix] = set(drawable no)."""
    for e in archive.iter_entries():
        s = str(getattr(e, 'path', ''))
        if not s.lower().endswith('.ydd'):
            continue
        parts = s.split('/')
        folder = parts[-2] if len(parts) > 1 else ''
        if who_prefix not in folder.lower():
            continue
        f = parts[-1]
        m = COMP.match(f) or PROP.match(f)
        if m:
            out[folder][m.group(1)].add(int(m.group(2)))


def scan_rpf(path, out, who_prefix, depth=0):
    try:
        a = ff.load_rpf(path)
    except Exception as ex:
        print('  ACILAMADI %s: %s' % (path, ex))
        return
    _scan_archive(a, out, who_prefix, depth)


def _scan_archive(a, out, who_prefix, depth):
    collect(a, out, who_prefix)
    if depth > 2:
        return
    for e in list(a.iter_entries()):
        s = str(getattr(e, 'path', ''))
        if not s.lower().endswith('.rpf'):
            continue
        # sadece giysi tasiyabilecek arsivlere in
        low = s.lower()
        if not ('cdimages' in low or 'peds' in low or 'ped' in low):
            continue
        try:
            n = a.load_nested_archive(e)
        except Exception:
            continue
        if n is not None:
            _scan_archive(n, out, who_prefix, depth + 1)


def main():
    who = sys.argv[1] if len(sys.argv) > 1 else 'mp_m_freemode_01'
    out = defaultdict(lambda: defaultdict(set))

    t0 = time.time()
    print('--- temel oyun (x64v.rpf) ---')
    scan_rpf(GTA + r'\x64v.rpf', out, who)
    print('    %.1fs, %d klasor' % (time.time() - t0, len(out)))

    import os
    packs = sorted(os.listdir(DLC))
    for i, pack in enumerate(packs, 1):
        p = os.path.join(DLC, pack, 'dlc.rpf')
        if not os.path.exists(p):
            continue
        t = time.time()
        before = len(out)
        scan_rpf(p, out, who)
        print('  [%2d/%d] %-24s %.1fs  (+%d klasor)'
              % (i, len(packs), pack, time.time() - t, len(out) - before))

    # ozet
    print('\n=== ozet (%s) ===' % who)
    per = defaultdict(int)
    for folder, comps in out.items():
        for c, ds in comps.items():
            per[c] += len(ds)

    for c in sorted(per):
        print('  %-8s toplam drawable = %d' % (c, per[c]))

    dump = {f: {c: sorted(d) for c, d in comps.items()} for f, comps in out.items()}
    with open(sys.argv[2] if len(sys.argv) > 2 else 'scan.json', 'w') as fh:
        json.dump(dump, fh, indent=1)
    print('\nklasor sayisi: %d,  toplam sure %.1fs' % (len(out), time.time() - t0))


if __name__ == '__main__':
    main()
