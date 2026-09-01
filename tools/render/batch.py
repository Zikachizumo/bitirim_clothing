"""
Eslemesi KANITLANMIS parcalari toplu render et.

Girdi : map_<slot>.json (align2.py ciktisi)
Cikti : out/<slot>_<drawable>.png  -- saydam, 512x512

Isleyis: arsiv arsiv gezilir. Bir ic arsivde bir klasorun hem .ydd'si hem
.ytd'si birlikte duruyor (olculdu), o yuzden her sey bellekte tutulmadan
arsiv basinda render edilebiliyor.

Eslenmemis drawable'lara DOKUNULMAZ -- onlarin oyun ici kareleri yerinde kalir.
"""

import os
import re
import sys
import json
import time
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fivefury as ff
import render_ydd

GTA = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced'
DLC = os.path.join(GTA, 'update', 'x64', 'dlcpacks')

# slot -> dosya oneki
PREFIX = {'jacket': 'jbib', 'tshirt': 'accs', 'pants': 'lowr',
          'shoes': 'feet', 'hat': 'p_head', 'glasses': 'p_eyes',
          'uppr': 'uppr'}

# magazada gosterilmeyen slotlar atlanir
SKIP = {'uppr'}


def load_wanted(mapdir):
    """(folder, prefix, num) -> (slot, drawable)"""
    want = {}
    for slot, prefix in PREFIX.items():
        if slot in SKIP:
            continue
        p = os.path.join(mapdir, 'map_%s.json' % slot)
        if not os.path.exists(p):
            continue
        for drawable, (folder, num) in json.load(open(p)).items():
            want[(folder, prefix, int(num))] = (slot, int(drawable))
    return want


def sources():
    yield os.path.join(GTA, 'x64v.rpf')
    for d in sorted(os.listdir(DLC)):
        p = os.path.join(DLC, d, 'dlc.rpf')
        if os.path.exists(p):
            yield p


def process(archive, want, outdir, tmp, stats):
    """Bir ic arsivi tara ve icindeki istenen parcalari render et."""
    # klasor -> {prefix_num: entry} indeksle
    ydds, ytds = {}, {}
    for e in archive.iter_entries():
        s = str(getattr(e, 'path', ''))
        low = s.lower()
        parts = s.split('/')
        if len(parts) < 2:
            continue
        folder = parts[-2].lower()
        f = parts[-1]

        if low.endswith('.ydd'):
            m = re.match(r'^([a-z_]+?)_(\d{3})(?:_[a-z])?\.ydd$', f)
            if m and (folder, m.group(1), int(m.group(2))) in want:
                ydds[(folder, m.group(1), int(m.group(2)))] = e
        elif low.endswith('.ytd'):
            m = re.match(r'^([a-z_]+?)_diff_(\d{3})_([a-z])(?:_.*)?\.ytd$', f)
            if m:
                k = (folder, m.group(1), int(m.group(2)))
                if k in want and (k not in ytds or m.group(3) < ytds[k][0]):
                    ytds[k] = (m.group(3), e)

    for k, ydd_entry in ydds.items():
        if k not in ytds:
            stats['doku_yok'] += 1
            continue
        slot, drawable = want[k]
        out = os.path.join(outdir, '%s_%d.png' % (slot, drawable))
        if os.path.exists(out):
            stats['atlandi'] += 1
            continue
        try:
            yp = os.path.join(tmp, 'a.ydd')
            tp = os.path.join(tmp, 'a.ytd')
            open(yp, 'wb').write(archive.read_entry_standalone(ydd_entry))
            open(tp, 'wb').write(archive.read_entry_standalone(ytds[k][1]))
            render_ydd.render(yp, tp, out, size=512, yaw=180, quiet=True)
            stats['yazildi'] += 1
        except Exception as ex:
            stats['hata'] += 1
            if stats['hata'] <= 5:
                print('  HATA %s %s_%03d: %s' % (k[0][-20:], k[1], k[2], ex))


def main():
    mapdir, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    tmp = os.path.join(outdir, '_tmp')
    os.makedirs(tmp, exist_ok=True)

    want = load_wanted(mapdir)
    print('istenen parca: %d' % len(want))

    stats = {'yazildi': 0, 'atlandi': 0, 'hata': 0, 'doku_yok': 0}
    t0 = time.time()

    for src in sources():
        try:
            a = ff.load_rpf(src)
        except Exception:
            continue
        for e in list(a.iter_entries()):
            s = str(getattr(e, 'path', ''))
            if not s.lower().endswith('.rpf') or 'cdimage' not in s.lower():
                continue
            try:
                n = a.load_nested_archive(e)
            except Exception:
                continue
            if n is None:
                continue
            process(n, want, outdir, tmp, stats)
        print('  %-58s yazilan=%d atlanan=%d hata=%d  %.0fs'
              % (os.path.basename(os.path.dirname(src)) or 'x64v',
                 stats['yazildi'], stats['atlandi'], stats['hata'], time.time() - t0))

    print('\nbitti: %(yazildi)d yazildi, %(atlandi)d zaten vardi, '
          '%(hata)d hata, %(doku_yok)d dokusuz' % stats)
    print('sure %.0f sn' % (time.time() - t0))


if __name__ == '__main__':
    main()
