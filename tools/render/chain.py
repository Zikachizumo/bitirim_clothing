"""
Calisma zamani listesini DLC klasorlerine zincirleyerek boл.

Temel dizinin birebir uydugu dogrulandi (16/16). Simdi 16. konumdan itibaren
her adimda "hangi klasorun doku-sayisi dizisi buraya oturuyor" diye bakiyoruz.
Tek aday varsa esleme kesin; birden fazla aday varsa belirsizlik raporlanir --
tahmin edilmez.

Cikti: drawable indeksi -> (klasor, dosya numarasi) tablosu.
"""

import os
import re
import sys
import json
from collections import defaultdict

import fivefury as ff

# FiveM b3323 LEGACY GTA V uzerinde calisiyor -- kaynak da o olmali.
GTA = os.environ.get('GTA_DIR',
    os.path.join('D:', os.sep, 'SteamLibrary', 'steamapps', 'common',
                 'Grand Theft Auto V'))
DLC = os.path.join(GTA, 'update', 'x64', 'dlcpacks')

YDD = re.compile(r'^([a-z_]+?)_(\d{3})_[a-z]\.ydd$')
YTD = re.compile(r'^([a-z_]+?)_diff_(\d{3})_([a-z])(?:_.*)?\.ytd$')
PROP_YDD = re.compile(r'^(p_[a-z]+)_(\d{3})\.ydd$')
PROP_YTD = re.compile(r'^(p_[a-z]+)_diff_(\d{3})_([a-z])\.ytd$')



def _giysi_arsivi(low):
    """
    Bu ic arsive inilsin mi?

    Filtresiz inmek YANLIS (olculdu: kapsama 441 -> 331 dustu, cunku fazladan
    doku bulunca parmak izi dizisi bozuluyor). Ama sadece 'cdimage' aramak da
    eksikti -- hedefli arama (hunt_folders.py) giysilerin su adlarda da
    durdugunu gosterdi:
      x64w.rpf > dlc.rpf > mpbeach.rpf        (cift ic ice, erken DLC'ler)
      mppatchesng > mppatches_m_outfits.rpf
      patchday27ng > patchday27ng_male.rpf
    """
    base = low.rsplit('/', 1)[-1]
    if 'cdimage' in low:
        return True
    if base == 'dlc.rpf':
        return True
    if base.endswith(('_male.rpf', '_female.rpf', '_male_p.rpf', '_female_p.rpf')):
        return True
    if '_outfits.rpf' in base:
        return True
    # x64w.rpf > dlc.rpf icindeki mpbeach.rpf / mphipster.rpf gibi paketler
    if base.startswith('mp') and base.endswith('.rpf') and 'vehicle' not in base:
        return True
    return False


def scan_archive(a, acc, src, depth=0):
    for e in a.iter_entries():
        s = str(getattr(e, 'path', ''))
        low = s.lower()
        parts = s.split('/')
        fname = parts[-1]
        folder = parts[-2].lower() if len(parts) > 1 else ''

        if low.endswith('.ydd'):
            m = YDD.match(fname) or PROP_YDD.match(fname)
            if m:
                acc[folder][m.group(1)].setdefault(int(m.group(2)), set())
                src[folder] = src.get(folder) or a
        elif low.endswith('.ytd'):
            m = YTD.match(fname) or PROP_YTD.match(fname)
            if m:
                acc[folder][m.group(1)].setdefault(int(m.group(2)), set()).add(m.group(3))
        elif low.endswith('.rpf') and depth < 4 and _giysi_arsivi(low):
            try:
                n = a.load_nested_archive(e)
            except Exception:
                continue
            if n is not None:
                scan_archive(n, acc, src, depth + 1)


def build(who):
    acc = defaultdict(lambda: defaultdict(dict))
    src = {}
    origin = {}

    # Erken DLC'ler (mpBeach, mpBusiness, mpHipster, mpIndependence...) ayri
    # paket olarak diskte YOK; oyunun kendi x64*.rpf'lerine ve update.rpf'in
    # dlc_patch/ dalina gomulmusler. Hepsini tariyoruz.
    bases = [(os.path.join(GTA, 'x64%s.rpf' % c), '(x64%s)' % c)
             for c in 'abcdefghijklmnopqrstuvw']
    bases += [(os.path.join(GTA, 'update', 'update.rpf'), '(update.rpf)'),
              (os.path.join(GTA, 'update', 'update2.rpf'), '(update2.rpf)')]
    for base_rpf, label in bases:
        if not os.path.exists(base_rpf):
            continue
        try:
            a = ff.load_rpf(base_rpf)
        except Exception:
            continue
        before = set(acc)
        scan_archive(a, acc, src)
        for f in set(acc) - before:
            origin[f] = label

    # Bir pakette birden fazla dlc*.rpf olabilir (mpbattle/mpheist4/
    # mpsecurity/mptuner erkek giysilerini dlc1.rpf ve dlc2.rpf'te tutuyor).
    for pack in sorted(os.listdir(DLC)):
        for fn in sorted(os.listdir(os.path.join(DLC, pack))):
            if not re.match(r'^dlc\d*\.rpf$', fn.lower()):
                continue
            try:
                ar = ff.load_rpf(os.path.join(DLC, pack, fn))
            except Exception:
                continue
            before = set(acc)
            scan_archive(ar, acc, src)
            for f in set(acc) - before:
                origin[f] = pack

    # sadece istenen ped
    acc = {f: c for f, c in acc.items() if who in f}
    return acc, origin


def main():
    dump = json.load(open(sys.argv[1]))
    prefix = sys.argv[2]
    comp = sys.argv[3]
    who = sys.argv[4] if len(sys.argv) > 4 else 'mp_m_freemode_01'

    src = dump['components'] if comp in dump['components'] else dump['props']
    runtime = [e['tex'] for e in src[comp]]

    acc, origin = build(who)

    # klasor -> dizi
    seqs = {}
    for folder, comps in acc.items():
        if prefix not in comps:
            continue
        nums = sorted(comps[prefix])
        seqs[folder] = (nums, [len(comps[prefix][d]) for d in nums])

    print('%s / comp %s: calisma zamani %d drawable, %d aday klasor'
          % (prefix, comp, len(runtime), len(seqs)))

    mapping = {}
    pos = 0
    used = set()
    steps = []

    while pos < len(runtime):
        cands = []
        for folder, (nums, s) in seqs.items():
            if folder in used or not s:
                continue
            if runtime[pos:pos + len(s)] == s:
                cands.append(folder)
        if not cands:
            print('\n  DURDU: konum %d icin eslesen klasor yok.' % pos)
            print('     kalan dizi (ilk 20):', runtime[pos:pos + 20])
            break
        if len(cands) > 1:
            # ayni uzunluk+dizi -> belirsiz; en uzun eslesme tercih edilir
            lens = {len(seqs[c][1]) for c in cands}
            if len(lens) == 1:
                print('\n  BELIRSIZ konum %d: %s (ayni dizi)' % (pos, cands))
        folder = max(cands, key=lambda c: len(seqs[c][1]))
        nums, s = seqs[folder]
        for i, num in enumerate(nums):
            mapping[pos + i] = (folder, num)
        steps.append((pos, len(s), folder, origin.get(folder, '?'), len(cands)))
        used.add(folder)
        pos += len(s)

    print('\n=== zincir (%d/%d drawable eslesti) ===' % (pos, len(runtime)))
    for start, n, folder, pack, nc in steps:
        flag = '' if nc == 1 else '  [%d aday]' % nc
        print('  %4d..%-4d  %-46s %s%s' % (start, start + n - 1, folder, pack, flag))

    if pos == len(runtime):
        print('\n  >>> TAM ESLESME <<<')
        out = sys.argv[5] if len(sys.argv) > 5 else None
        if out:
            json.dump({str(k): list(v) for k, v in mapping.items()},
                      open(out, 'w'), indent=1)
            print('  esleme yazildi:', out)


if __name__ == '__main__':
    main()
