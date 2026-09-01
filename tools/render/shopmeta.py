"""
GTA'nin KENDI kiyafet magazasi verisinden esleme kur.

`mp_<cinsiyet>_freemode_01_<dlc>_shop.meta` dosyalari GTA Online'in kiyafetci
menusunun kaynagi. Her kayitta:

    uniqueNameHash     DLC_MP_BIKER_M_JBIB_21_0  -> joaat'i oyunun bildirdigi
                                                    apparel hash'i
    localDrawableIndex DLC icindeki dosya numarasi (jbib_021)
    textureIndex       doku varyanti
    eCompType          PV_COMP_JBIB gibi  /  eAnchorPoint ANCHOR_HEAD gibi
    textLabel          parcanin gercek adi (GetLabelText ile cozulur)
    cost               Rockstar fiyati
    forcedComponents   kol uyumlulugu

Yani "magazadaki 157 numara hangi dosya" sorusunun cevabi burada YAZIYOR.
Parmak izi yontemi (align2.py) tahmin icermiyordu ama cikarimdi; bu dogrudan
oyunun tablosu. Ikisi cakisan yerlerde karsilastiriliyor (bkz. crosscheck.py).

DIKKAT: sadece <pedComponents> ve <pedProps> bolumleri okunuyor. <pedOutfits>
baska DLC'lerin parcalarina atifta bulunuyor (biker dosyasinda DLC_MP_APA_...
gorundu), oradan klasor cikarimi yanlis olur.
"""

import os
import re
import sys
import json

import fivefury as ff

GTA = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced'
DLC = os.path.join(GTA, 'update', 'x64', 'dlcpacks')

TAG = re.compile(r'</?Item>')


def top_items(body):
    """
    Bolumun EN UST seviyedeki <Item> bloklarini dondur.

    Basit non-greedy regex ISE YARAMIYOR: bir kaydin icinde
    <restrictionTags><Item>...</Item></restrictionTags> gibi ic ice Item'lar
    var ve `<Item>(.*?)</Item>` ilk kapanista kesiyor -- localDrawableIndex
    gibi alanlar kayboluyor (olculdu: 16471 yerine ~50 kayit cikti).
    Bu yuzden derinlik sayilarak ayriliyor.
    """
    out = []
    depth = 0
    start = None
    for m in TAG.finditer(body):
        if m.group(0) == '<Item>':
            if depth == 0:
                start = m.end()
            depth += 1
        else:
            depth -= 1
            if depth == 0 and start is not None:
                out.append(body[start:m.start()])
                start = None
    return out
FIELD = {
    'name': re.compile(r'<uniqueNameHash>([A-Za-z0-9_]+)</uniqueNameHash>'),
    # PROP'LAR FARKLI ADLANDIRIYOR: bilesenler localDrawableIndex, prop'lar
    # localPropIndex. Sadece ilkine bakmak sapka/gozluk eslemesini SIFIR
    # birakiyordu (olculdu).
    'local': re.compile(r'<localDrawableIndex value="(-?\d+)"'),
    'local_prop': re.compile(r'<localPropIndex value="(-?\d+)"'),
    'drawable': re.compile(r'<drawableIndex value="(-?\d+)"'),
    'prop_index': re.compile(r'<propIndex value="(-?\d+)"'),
    'tex': re.compile(r'<textureIndex value="(-?\d+)"'),
    'comp': re.compile(r'<eCompType>(\w+)</eCompType>'),
    'anchor': re.compile(r'<eAnchorPoint>(\w+)</eAnchorPoint>'),
    'label': re.compile(r'<textLabel>([A-Za-z0-9_]+)</textLabel>'),
    'cost': re.compile(r'<cost value="(-?\d+)"'),
}


def joaat(s):
    h = 0
    for c in s.lower():
        h = (h + ord(c)) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h ^= h >> 6
    h = (h + (h << 3)) & 0xFFFFFFFF
    h ^= h >> 11
    h = (h + (h << 15)) & 0xFFFFFFFF
    return h


def _shop_rpf(low):
    base = low.rsplit('/', 1)[-1]
    return ('cdimage' in low or base == 'dlc.rpf' or 'common' in low
            or base.endswith(('_male.rpf', '_female.rpf'))
            or (base.startswith('mp') and 'vehicle' not in base))


def collect(who='mp_m_freemode_01'):
    """{dosya adi: xml metni} -- ilk gorulen kazanir."""
    metas = {}

    def walk(a, depth=0):
        for e in a.iter_entries():
            s = str(getattr(e, 'path', ''))
            low = s.lower()
            if low.endswith('_shop.meta') and who in low:
                nm = low.rsplit('/', 1)[-1]
                if nm not in metas:
                    try:
                        metas[nm] = a.read_entry_bytes(e).decode('utf-8', 'replace')
                    except Exception:
                        pass
            elif low.endswith('.rpf') and depth < 2 and _shop_rpf(low):
                try:
                    n = a.load_nested_archive(e)
                except Exception:
                    continue
                if n is not None:
                    walk(n, depth + 1)

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
        walk(a)
    return metas


def section(txt, tag):
    i = txt.find('<%s>' % tag)
    j = txt.find('</%s>' % tag)
    return txt[i:j] if (i >= 0 and j > i) else ''


def parse(txt):
    """-> (fullDlcName, [kayit])"""
    m = re.search(r'<fullDlcName>([A-Za-z0-9_]+)</fullDlcName>', txt)
    full = m.group(1).lower() if m else None

    out = []
    for tag, kind in (('pedComponents', 'comp'), ('pedProps', 'prop')):
        body = section(txt, tag)
        if not body:
            continue
        for chunk in top_items(body):
            rec = {}
            for k, rx in FIELD.items():
                mm = rx.search(chunk)
                if mm:
                    rec[k] = mm.group(1)
            if 'name' not in rec:
                continue
            if 'local' not in rec and 'local_prop' in rec:
                rec['local'] = rec['local_prop']
            rec['kind'] = kind
            out.append(rec)
    return full, out


def main():
    who = sys.argv[1] if len(sys.argv) > 1 else 'mp_m_freemode_01'
    outdir = sys.argv[2]
    os.makedirs(outdir, exist_ok=True)

    metas = collect(who)
    print('%s icin %d shop.meta' % (who, len(metas)))

    rows = []
    for nm, txt in sorted(metas.items()):
        full, recs = parse(txt)
        if not full:
            print('  fullDlcName yok, atlandi: %s' % nm)
            continue
        for r in recs:
            r['folder'] = full
            r['hash'] = joaat(r['name'])
            rows.append(r)

    print('toplam kayit: %d' % len(rows))
    with open(os.path.join(outdir, 'shopmeta_%s.json' % who), 'w') as f:
        json.dump(rows, f)
    print('yazildi: shopmeta_%s.json' % who)


if __name__ == '__main__':
    main()
