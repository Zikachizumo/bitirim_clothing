"""
Eksik ped klasorlerinin dosyalari HANGI arsivde -- hedefli arama.

Onceki genis tarama klasor adlarini karistirdi (kapsama 441'den 331'e dustu),
cunku klasor adini yol parcasindan cikariyordu. Burada oyle bir cikarim YOK:
sadece "yolun icinde su klasor adi geciyor mu" diye bakiyoruz ve tam yolu
raporluyoruz. Yanlis eslestirme riski yok.
"""

import os
import sys
import time
from collections import defaultdict

import fivefury as ff

GTA = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced'
DLC = os.path.join(GTA, 'update', 'x64', 'dlcpacks')

TARGETS = [
    'mp_m_freemode_01_mp_m_tuner',
    'mp_m_freemode_01_mp_m_security',
    'mp_m_freemode_01_mp_m_2024_02',
    'mp_m_freemode_01_mp_m_2025_01',
    'mp_m_freemode_01_mp_m_2025_02',
    'mp_m_freemode_01_mp_m_2026_01',
    'mp_m_freemode_01_mp_m_heist4',
    'mp_m_freemode_01_mp_m_battle',
    'mp_m_freemode_01_male_freemode_beach',
    'mp_m_freemode_01_male_freemode_hipster',
]

hits = defaultdict(lambda: defaultdict(int))   # target -> arsiv yolu -> dosya sayisi
seen = set()


def walk(a, label, depth=0):
    if depth > 4:
        return
    try:
        entries = list(a.iter_entries())
    except Exception:
        return
    for e in entries:
        s = str(getattr(e, 'path', ''))
        low = s.lower()
        if low.endswith('.ydd') or low.endswith('.ytd'):
            for t in TARGETS:
                if t in low:
                    hits[t][label] += 1
                    break
        elif low.endswith('.rpf'):
            key = label + '|' + low
            if key in seen:
                continue
            seen.add(key)
            try:
                n = a.load_nested_archive(e)
            except Exception:
                continue
            if n is not None:
                walk(n, label + ' > ' + s.split('/')[-1], depth + 1)


def main():
    srcs = [(os.path.join(GTA, 'x64%s.rpf' % c), 'x64%s.rpf' % c)
            for c in 'abcdefghijklmnopqrstuvw']
    srcs += [(os.path.join(GTA, 'update', 'update.rpf'), 'update.rpf'),
             (os.path.join(GTA, 'update', 'update2.rpf'), 'update2.rpf')]
    srcs += [(os.path.join(DLC, d, 'dlc.rpf'), d)
             for d in sorted(os.listdir(DLC))]

    t0 = time.time()
    for path, label in srcs:
        if not os.path.exists(path):
            continue
        try:
            a = ff.load_rpf(path)
        except Exception:
            continue
        walk(a, label)
        sys.stdout.write('.')
        sys.stdout.flush()
    print('\ntarama %.0f sn\n' % (time.time() - t0))

    for t in TARGETS:
        if not hits[t]:
            print('%-42s BULUNAMADI' % t)
            continue
        print('%s' % t)
        for label, n in sorted(hits[t].items(), key=lambda x: -x[1]):
            print('    %-58s %d dosya' % (label, n))


if __name__ == '__main__':
    main()
