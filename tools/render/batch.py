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

# FiveM b3323 LEGACY GTA V uzerinde calisiyor -- kaynak da o olmali.
GTA = os.environ.get('GTA_DIR',
    os.path.join('D:', os.sep, 'SteamLibrary', 'steamapps', 'common',
                 'Grand Theft Auto V'))
DLC = os.path.join(GTA, 'update', 'x64', 'dlcpacks')

# slot -> dosya oneki
PREFIX = {'jacket': 'jbib', 'tshirt': 'accs', 'pants': 'lowr',
          'shoes': 'feet', 'hat': 'p_head', 'glasses': 'p_eyes',
          'uppr': 'uppr'}

# magazada gosterilmeyen slotlar atlanir
SKIP = {'uppr'}


def _clothing_rpf(low):
    base = low.rsplit('/', 1)[-1]
    return ('cdimage' in low or base == 'dlc.rpf'
            or base.endswith(('_male.rpf', '_female.rpf', '_male_p.rpf', '_female_p.rpf'))
            or '_outfits.rpf' in base
            or (base.startswith('mp') and 'vehicle' not in base))


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
    # chain.build ile AYNI kaynak listesi olmali. Sadece x64v + dlcpacks
    # bakmak eksikti: erken DLC'ler (mpBeach, mpHipster...) x64w.rpf'in
    # icindeki dlc.rpf'te duruyor -- 51 parcanin .ydd'si o yuzden bulunamadi.
    for c in 'abcdefghijklmnopqrstuvw':
        p = os.path.join(GTA, 'x64%s.rpf' % c)
        if os.path.exists(p):
            yield p
    for f in ('update.rpf', 'update2.rpf'):
        p = os.path.join(GTA, 'update', f)
        if os.path.exists(p):
            yield p
    # BIR PAKETTE BIRDEN FAZLA dlc*.rpf OLABILIR. mpbattle/mpheist4/
    # mpsecurity/mptuner erkek giysilerini dlc1.rpf ve dlc2.rpf'te tutuyor.
    # Sadece dlc.rpf'e bakmak bu dort paketi neredeyse tamamen kaciriyordu:
    # olculdu, tuner klasorunde 10 dosya gorunuyordu, gercegi 94.
    for d in sorted(os.listdir(DLC)):
        for f in sorted(os.listdir(os.path.join(DLC, d))):
            if re.match(r'^dlc\d*\.rpf$', f.lower()):
                yield os.path.join(DLC, d, f)


def index_archive(archive, want, ydds, ytds):
    """Bu arsivdeki istenen .ydd ve .ytd girdilerini GLOBAL indekse ekle.

    Arsiv basina eslestirmek YANLIS: bir parcanin .ydd'si mp2024_02_male.rpf'te
    iken .ytd'si patch2025_01_male.rpf'te olabiliyor. Oyle yapinca 285 parca
    'dokusuz' diye elendi. Once her sey indeksleniyor, sonra render ediliyor.
    """
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
            if m:
                k = (folder, m.group(1), int(m.group(2)))
                if k in want and k not in ydds:
                    ydds[k] = (archive, e)
        elif low.endswith('.ytd'):
            m = re.match(r'^([a-z_]+?)_diff_(\d{3})_([a-z])(?:_.*)?\.ytd$', f)
            if m:
                k = (folder, m.group(1), int(m.group(2)))
                if k in want:
                    # TEK ADAY TUTMAK YANLIS: ayni isimli doku birden fazla
                    # arsivde bulunabiliyor ve bazi kopyalari cozulemeyen
                    # formatta (olculdu: mptuner feet_diff_002_a_uni hem BC4
                    # hem BC1 olarak var; ilk bulunan BC4 render'i patlatiyordu).
                    # Hepsini topluyoruz, render sirasinda cozuleni kullanacagiz.
                    ytds.setdefault(k, []).append((m.group(3), archive, e))


def index_walk(archive, want, ydds, ytds, depth=0):
    """
    Arsivi ve giysi tasiyabilecek ic arsivlerini ozyinelemeli indeksle.

    Tek kat inmek yetmiyordu: erken DLC'ler (mpBeach, mpHipster, mpBusiness,
    mpValentines...) x64w.rpf > dlc.rpf > mpbeach.rpf seklinde IKI KAT ice
    gomulu. Onlarin 51 parcasi bu yuzden bulunamiyordu.
    """
    index_archive(archive, want, ydds, ytds)
    if depth >= 3:
        return
    for e in list(archive.iter_entries()):
        s = str(getattr(e, 'path', ''))
        low = s.lower()
        if not low.endswith('.rpf') or not _clothing_rpf(low):
            continue
        try:
            n = archive.load_nested_archive(e)
        except Exception:
            continue
        if n is not None:
            index_walk(n, want, ydds, ytds, depth + 1)


def main():
    mapdir, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    tmp = os.path.join(outdir, '_tmp')
    os.makedirs(tmp, exist_ok=True)

    want = load_wanted(mapdir)
    print('istenen parca: %d' % len(want))

    # --- 1. gecis: global indeks
    t0 = time.time()
    ydds, ytds = {}, {}
    for src in sources():
        try:
            a = ff.load_rpf(src)
        except Exception:
            continue
        index_walk(a, want, ydds, ytds)
    print('indeks %.0f sn: %d ydd, %d ytd' % (time.time() - t0, len(ydds), len(ytds)))

    # --- 2. gecis: render
    stats = {'yazildi': 0, 'atlandi': 0, 'hata': 0, 'doku_yok': 0}
    for k, (ar, ydd_e) in sorted(ydds.items()):
        slot, drawable = want[k]
        out = os.path.join(outdir, '%s_%d.png' % (slot, drawable))
        if os.path.exists(out):
            stats['atlandi'] += 1
            continue
        if k not in ytds:
            stats['doku_yok'] += 1
            continue
        yp = os.path.join(tmp, 'a.ydd')
        tp = os.path.join(tmp, 'a.ytd')
        last = None
        done = False
        try:
            open(yp, 'wb').write(ar.read_entry_standalone(ydd_e))
        except Exception as ex:
            stats['hata'] += 1
            if stats['hata'] <= 8:
                print('  HATA(ydd) %s %s_%03d: %s' % (k[0][-24:], k[1], k[2], ex))
            continue
        # En dusuk varyant harfi tercih edilir; ayni harfin cozulemeyen
        # kopyasi varsa bir sonrakine gecilir.
        for _letter, tar, te in sorted(ytds[k], key=lambda x: x[0]):
            try:
                open(tp, 'wb').write(tar.read_entry_standalone(te))
                render_ydd.render(yp, tp, out, size=512, yaw=180, quiet=True)
                done = True
                break
            except Exception as ex:
                last = ex
        if done:
            stats['yazildi'] += 1
            if stats['yazildi'] % 100 == 0:
                print('  %d yazildi  %.0f sn' % (stats['yazildi'], time.time() - t0))
        else:
            stats['hata'] += 1
            if stats['hata'] <= 12:
                print('  HATA %s %s_%03d: %s' % (k[0][-24:], k[1], k[2], last))

    print('\nbitti: %(yazildi)d yazildi, %(atlandi)d zaten vardi, '
          '%(hata)d hata, %(doku_yok)d dokusuz' % stats)
    print('sure %.0f sn' % (time.time() - t0))


if __name__ == '__main__':
    main()
