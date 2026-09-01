"""
Prop (sapka/gozluk/saat...) doku sayilarini .ymt meta verisinden cikar.

NEDEN: bilesenlerde her doku varyanti icin ayri bir .ytd dosyasi var, o yuzden
dosyadan saymak calisiyor. PROP'LARDA CALISMIYOR -- olculdu:

    mpbiker anchor 0 (sapka), ymt'ye gore : [1, 4, 10, 10, 10, 10, 4, ...]
    ayni klasorun .ytd dosyalarindan sayim: [7, 10, 1, 1, 1, 1, ...]

Oyun ymt'deki degerleri bildiriyor. Bu yuzden sapka/gozluk hizalamasi dosya
sayimiyla tutmuyordu (kapsama %62'de takildi).

Ymt yapisi (fivefury ile okundu, alan adlari hash olarak geliyor):
    ped_variation.propInfo
      aAnchors[]          0x7019CA89 = anchor id (0 sapka, 1 gozluk, 2 kulak,
                                       6 sol bilek, 7 sag bilek)
                          0x8856F65A = bu anchor'a ait aPropMetaData indeksleri
      aPropMetaData[]     0xE384F7EC = anchor icindeki drawable numarasi
                          0xF3B8348A = doku listesi (uzunlugu = doku sayisi)

Ymt dosyasi klasor adiyla adlandirilmis (mp_m_freemode_01_mp_m_bikerdlc_01.ymt),
yani eslemeyi dogrudan kuruyor.
"""

import os
import sys
from collections import defaultdict

import fivefury as ff

GTA = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced'
DLC = os.path.join(GTA, 'update', 'x64', 'dlcpacks')

ANCHOR_PREFIX = {0: 'p_head', 1: 'p_eyes', 2: 'p_ears',
                 6: 'p_lwrist', 7: 'p_rwrist'}

F_ANCHOR_ID = '0x7019CA89'
F_ANCHOR_ITEMS = '0x8856F65A'
F_DRAWABLE_NO = '0xE384F7EC'
F_TEX_LIST = '0xF3B8348A'


def _clothing_rpf(low):
    base = low.rsplit('/', 1)[-1]
    return ('cdimage' in low or base == 'dlc.rpf'
            or base.endswith(('_male.rpf', '_female.rpf', '_male_p.rpf', '_female_p.rpf'))
            or '_outfits.rpf' in base
            or (base.startswith('mp') and 'vehicle' not in base))


def prop_folder(component_folder):
    """mp_m_freemode_01_mp_m_X  ->  mp_m_freemode_01_p_mp_m_X"""
    for ped in ('mp_m_freemode_01', 'mp_f_freemode_01'):
        if component_folder.startswith(ped):
            return ped + '_p' + component_folder[len(ped):]
    return component_folder


def read_ymt_props(data):
    """ymt baytlari -> {prefix: {drawable: doku_sayisi}}"""
    try:
        y = ff.read_ymt(data)
        pi = y.ped_variation['propInfo']
    except Exception:
        return {}

    md = pi.get('aPropMetaData') or []
    out = defaultdict(dict)
    for an in pi.get('aAnchors') or []:
        anchor = an.get(F_ANCHOR_ID)
        prefix = ANCHOR_PREFIX.get(anchor)
        if not prefix:
            continue
        # Drawable numarasi = anchor listesindeki SIRA.
        # 0xE384F7EC alanini kullanmak yanlisti: mpbiker anchor 0'da 13 prop
        # varken o alan cakisip 5 benzersiz deger veriyordu (olculdu).
        for d, i in enumerate(an.get(F_ANCHOR_ITEMS) or []):
            if not isinstance(i, int) or i >= len(md):
                continue
            tex = md[i].get(F_TEX_LIST)
            if tex is not None:
                out[prefix][d] = len(tex)
    return out


def walk(archive, who, out, depth=0):
    for e in archive.iter_entries():
        s = str(getattr(e, 'path', ''))
        low = s.lower()
        if low.endswith('.ymt'):
            name = low.rsplit('/', 1)[-1][:-4]
            if name.startswith(who):
                try:
                    props = read_ymt_props(archive.read_entry_standalone(e))
                except Exception:
                    continue
                if props:
                    folder = prop_folder(name)
                    for prefix, m in props.items():
                        # PATCH YMT'LERI EZMESIN. Ayni klasor icin birden fazla
                        # ymt var (paket + patch'ler); patch surumleri kismi
                        # oluyor ve update() ile birlestirince dizi bozuluyor.
                        # En cok prop iceren surumu tutuyoruz.
                        if len(m) > len(out[folder].get(prefix, {})):
                            out[folder][prefix] = dict(m)
        elif low.endswith('.rpf') and depth < 3 and _clothing_rpf(low):
            try:
                n = archive.load_nested_archive(e)
            except Exception:
                continue
            if n is not None:
                walk(n, who, out, depth + 1)


def build(who='mp_m_freemode_01'):
    """-> {prop_folder: {prefix: {drawable: doku_sayisi}}}"""
    out = defaultdict(lambda: defaultdict(dict))

    srcs = [os.path.join(GTA, 'x64%s.rpf' % c) for c in 'abcdefghijklmnopqrstuvw']
    srcs += [os.path.join(GTA, 'update', f) for f in ('update.rpf', 'update2.rpf')]
    srcs += [os.path.join(DLC, d, 'dlc.rpf') for d in sorted(os.listdir(DLC))]

    for p in srcs:
        if not os.path.exists(p):
            continue
        try:
            a = ff.load_rpf(p)
        except Exception:
            continue
        walk(a, who, out)

    return out


if __name__ == '__main__':
    import json
    who = sys.argv[1] if len(sys.argv) > 1 else 'mp_m_freemode_01'
    res = build(who)
    print('%d klasor' % len(res))
    tot = defaultdict(int)
    for f, m in sorted(res.items()):
        for prefix, d in m.items():
            tot[prefix] += len(d)
    for k, v in sorted(tot.items()):
        print('  %-10s %d drawable' % (k, v))
