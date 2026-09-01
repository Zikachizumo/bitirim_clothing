"""
shop.meta eslemesini kur ve parmak izi eslemesiyle KARSILASTIR.

Iki bagimsiz yontem:
  A) parmak izi (align2.py)  -- doku sayisi dizilerini hizalayarak cikarim
  B) shop.meta (shopmeta.py) -- oyunun kendi tablosu, cikarim yok

Cakistiklari yerde ayni seyi soyluyorlarsa ikisi de dogrulanmis olur.
Celiskiler tek tek raporlanir -- sessizce birinin tercih edilmesi YASAK.

Birlesik esleme: B nerede varsa B (dogrudan veri), yoksa A (temel oyun
parcalarinin apparel hash'i 0 oldugu icin B onlari kapsamiyor).
"""

import os
import sys
import json
from collections import defaultdict

SLOT = {
    ('components', '11'): 'jacket',
    ('components', '8'): 'tshirt',
    ('components', '4'): 'pants',
    ('components', '6'): 'shoes',
    ('components', '3'): 'uppr',
    ('props', '0'): 'hat',
    ('props', '1'): 'glasses',
}


def prop_folder(folder):
    for ped in ('mp_m_freemode_01', 'mp_f_freemode_01'):
        if folder.startswith(ped):
            return ped + '_p' + folder[len(ped):]
    return folder


def main():
    dumpf, metaf, mapdir, outdir = sys.argv[1:5]
    os.makedirs(outdir, exist_ok=True)

    dump = json.load(open(dumpf))
    rows = json.load(open(metaf))

    # calisma zamani hash -> (slot, drawable)
    rt = {}
    for kind in ('components', 'props'):
        for key, lst in dump[kind].items():
            slot = SLOT.get((kind, key))
            if not slot:
                continue
            for x in lst:
                h = x.get('hash')
                if h:
                    rt.setdefault(h & 0xFFFFFFFF, (slot, x['d']))

    # shop.meta -> slot -> drawable -> (folder, localIndex)
    metamap = defaultdict(dict)
    labels = defaultdict(dict)
    costs = defaultdict(dict)
    conflicts_meta = []

    for r in rows:
        hit = rt.get(r['hash'])
        if not hit:
            continue
        slot, drawable = hit
        local = r.get('local')
        if local is None:
            continue
        local = int(local)
        folder = prop_folder(r['folder']) if r['kind'] == 'prop' else r['folder']

        prev = metamap[slot].get(drawable)
        if prev and prev != (folder, local):
            conflicts_meta.append((slot, drawable, prev, (folder, local), r['name']))
            continue
        metamap[slot][drawable] = (folder, local)
        if r.get('label'):
            labels[slot][drawable] = r['label']
        if r.get('cost') is not None:
            costs[slot][drawable] = int(r['cost'])

    print('shop.meta eslemesi:')
    for slot in sorted(metamap):
        print('   %-8s %d drawable' % (slot, len(metamap[slot])))
    if conflicts_meta:
        print('   shop.meta KENDI ICINDE celiskili: %d' % len(conflicts_meta))
        for c in conflicts_meta[:5]:
            print('      %s %s: %s vs %s (%s)' % c)

    # --- parmak izi ile karsilastir
    print('\n=== iki yontem karsilastirmasi ===')
    total_same = total_diff = 0
    for slot in sorted(metamap):
        p = os.path.join(mapdir, 'map_%s.json' % slot)
        if not os.path.exists(p):
            continue
        fp = {int(k): tuple(v) for k, v in json.load(open(p)).items()}
        both = set(fp) & set(metamap[slot])
        same = [d for d in both if fp[d] == metamap[slot][d]]
        diff = [d for d in both if fp[d] != metamap[slot][d]]
        total_same += len(same)
        total_diff += len(diff)
        print('   %-8s ortak %4d  ayni %4d  FARKLI %d' % (slot, len(both), len(same), len(diff)))
        for d in diff[:4]:
            print('        drawable %-4d parmakizi=%s  shopmeta=%s'
                  % (d, fp[d], metamap[slot][d]))

    print('\n   toplam ortak %d, ayni %d, farkli %d' % (total_same + total_diff, total_same, total_diff))

    # --- birlesik esleme
    print('\n=== birlesik esleme ===')
    for slot in sorted(set(list(metamap) + ['jacket', 'tshirt', 'pants', 'shoes', 'hat', 'glasses'])):
        p = os.path.join(mapdir, 'map_%s.json' % slot)
        fp = {int(k): tuple(v) for k, v in json.load(open(p)).items()} if os.path.exists(p) else {}
        merged = dict(fp)
        merged.update(metamap.get(slot, {}))     # shop.meta oncelikli
        key = {'jacket': ('components', '11'), 'tshirt': ('components', '8'),
               'pants': ('components', '4'), 'shoes': ('components', '6'),
               'uppr': ('components', '3'), 'hat': ('props', '0'),
               'glasses': ('props', '1')}[slot]
        total = len(dump[key[0]][key[1]])
        json.dump({str(k): list(v) for k, v in sorted(merged.items())},
                  open(os.path.join(outdir, 'map_%s.json' % slot), 'w'), indent=1)
        print('   %-8s parmakizi %4d + shopmeta %4d -> %4d/%4d  %%%.1f'
              % (slot, len(fp), len(metamap.get(slot, {})), len(merged), total,
                 100.0 * len(merged) / total))

    json.dump({s: {str(k): v for k, v in m.items()} for s, m in labels.items()},
              open(os.path.join(outdir, 'labels.json'), 'w'), indent=1)
    json.dump({s: {str(k): v for k, v in m.items()} for s, m in costs.items()},
              open(os.path.join(outdir, 'costs.json'), 'w'), indent=1)
    print('\nlabels.json ve costs.json yazildi')


if __name__ == '__main__':
    main()
