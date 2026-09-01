"""
Hizalama, ikinci gecis: bosluklari TEK SEKILDE doseyerek doldur.

Birinci gecis sadece "listede tek bir yere oturan" klasorleri yerlestiriyor.
Kisa diziler (n=1, n=2) birden fazla yere uydugu icin belirsiz kaliyor ve
kategoriye gore %50-80 arasi kapsama cikiyor.

Ikinci gecis: birinci gecisin biraktigi her bosluk icin, yerlestirilmemis
klasorlerle o boslugu TAM OLARAK doseyen kombinasyonlari sayiyoruz.
  * tek doseme varsa  -> kanittir, yerlestirilir
  * birden fazla varsa -> belirsiz, DOKUNULMAZ (tahmin yok)
  * hic yoksa          -> o boslugun dosyalari elimizde degil demektir

Sonuc: kanitlanmis esleme + kanitlanamayan bosluklarin acik listesi.
"""

import os
import sys
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chain


def dlc_order():
    """paket adi (kucuk harf) -> dlclist.xml sirasi. Temel oyun -1."""
    order = {}
    try:
        lines = [l.strip() for l in open('C:/bcc/out/dlclist.txt') if l.strip()]
    except OSError:
        return order
    for i, l in enumerate(lines):
        name = l.rstrip('/').rsplit('/', 1)[-1].lower()
        order[name] = i
    return order

CATS = [
    ('outerwear', '11', 'components', 'jbib',   'jacket'),
    ('tshirts',   '8',  'components', 'accs',   'tshirt'),
    ('pants',     '4',  'components', 'lowr',   'pants'),
    ('shoes',     '6',  'components', 'feet',   'shoes'),
    ('headwear',  '0',  'props',      'p_head', 'hat'),
    ('glasses',   '1',  'props',      'p_eyes', 'glasses'),
    ('arms',      '3',  'components', 'uppr',   'uppr'),
]

MAX_TILINGS = 20000        # kesisim icin tum cozumler lazim; limit yuksek


def findall(hay, need):
    if not need:
        return []
    return [i for i in range(len(hay) - len(need) + 1)
            if hay[i:i + len(need)] == need]


def ranges(idx):
    out, s, p = [], None, None
    for i in sorted(idx):
        if s is None:
            s = p = i
        elif i == p + 1:
            p = i
        else:
            out.append((s, p))
            s = p = i
    if s is not None:
        out.append((s, p))
    return out


def tilings(runtime, lo, hi, pool, rank=None, lo_rank=None, hi_rank=None,
            limit=MAX_TILINGS):
    """
    [lo,hi] araligini pool'daki klasorlerle tam doseyen tum cozumler.

    KRONOLOJIK KISIT: jbib'de dogrulandi ki calisma zamani sirasi DLC yukleme
    (dlclist.xml) sirasi. O yuzden bir dosemedeki paketler artan sirada olmali
    ve boslugun iki yanindaki capalarin sirasi arasinda kalmali. Bu kisit
    'N doseme' belirsizliklerinin cogunu tek cozume indiriyor.
    """
    found = []
    rank = rank or {}

    def rec(pos, used, acc, last):
        if len(found) >= limit:
            return
        if pos > hi:
            found.append(list(acc))
            return
        for folder, (nums, s) in pool.items():
            if folder in used:
                continue
            end = pos + len(s) - 1
            if end > hi:
                continue
            if runtime[pos:pos + len(s)] != s:
                continue
            r = rank.get(folder)
            if r is not None:
                if r < last:
                    continue
                if hi_rank is not None and r > hi_rank:
                    continue
            used.add(folder)
            acc.append((pos, folder))
            rec(pos + len(s), used, acc, r if r is not None else last)
            acc.pop()
            used.discard(folder)

    rec(lo, set(), [], lo_rank if lo_rank is not None else -2)
    return found


def main():
    dump = json.load(open(sys.argv[1]))
    outdir = sys.argv[2]
    who = 'mp_m_freemode_01' if dump['gender'] == 'male' else 'mp_f_freemode_01'

    os.makedirs(outdir, exist_ok=True)
    print('ped: %s -- arsivler taraniyor...' % who)
    acc, origin = chain.build(who)
    print('  %d klasor\n' % len(acc))

    summary = []
    for cat, key, kind, prefix, slot in CATS:
        entries = dump[kind].get(key)
        if not entries:
            continue
        runtime = [e['tex'] for e in entries]

        seqs = {}
        for folder, comps in acc.items():
            if prefix in comps:
                nums = sorted(comps[prefix])
                seqs[folder] = (nums, [len(comps[prefix][d]) for d in nums])

        mapping, taken, placed = {}, set(), set()

        # --- 1. gecis: listede tek yere oturanlar
        for folder, (nums, s) in seqs.items():
            pos = findall(runtime, s)
            if len(pos) == 1:
                p = pos[0]
                if any(p + i in taken for i in range(len(s))):
                    continue
                for i, num in enumerate(nums):
                    mapping[p + i] = (folder, num)
                    taken.add(p + i)
                placed.add(folder)
        first = len(taken)

        # --- 2. gecis: bosluklari tek sekilde doseyerek doldur
        pool = {f: v for f, v in seqs.items() if f not in placed and v[1]}

        # klasor -> dlclist sirasi (paketinden)
        ORD = dlc_order()
        rank = {}
        for f in seqs:
            pk = (origin.get(f) or '').lower().strip('()')
            rank[f] = ORD.get(pk)

        # bosluk oncesi/sonrasi capalarin sirasi -> arama araligi
        def anchor_rank(idx, step):
            i = idx
            while 0 <= i < len(runtime):
                if i in mapping:
                    r = rank.get(mapping[i][0])
                    if r is not None:
                        return r
                i += step
            return None

        unresolved = []
        for lo, hi in ranges([i for i in range(len(runtime)) if i not in taken]):
            # Kronolojik sira kisiti KULLANILMIYOR: denendi, belirsizligi
            # azaltti ama kapsamayi da dusurdu (1310 -> 1306). Sebep, bir
            # klasorun 'paketi'nin onu ilk buldugum arsive gore atanmasi --
            # o da gec bir patch olabiliyor, yani sira guvenilmez.
            sols = tilings(runtime, lo, hi, pool)

            if not sols:
                unresolved.append((lo, hi, 0))
                continue

            #[ TUM DOSEMELERIN KESISIMI ]
            # Bosluk tek sekilde dosenmiyor olabilir ama bazi konumlarda TUM
            # cozumler ayni parcayi koyuyorsa o konum yine de kanitlanmistir.
            # Sadece "tek doseme" aramak bu bilgiyi cope atiyordu.
            common = None
            for sol in sols:
                cur = {}
                for pos, folder in sol:
                    nums, sq = seqs[folder]
                    for i, num in enumerate(nums):
                        cur[pos + i] = (folder, num)
                if common is None:
                    common = cur
                else:
                    common = {k: v for k, v in common.items()
                              if k in cur and cur[k] == v}
                if not common:
                    break

            if common:
                used_folders = set()
                for k, v in common.items():
                    mapping[k] = v
                    taken.add(k)
                    used_folders.add(v[0])
                for f in used_folders:
                    placed.add(f)
                    pool.pop(f, None)
            if len(common or {}) < (hi - lo + 1):
                unresolved.append((lo, hi, len(sols)))

        cov = len(taken)
        path = os.path.join(outdir, 'map_%s.json' % slot)
        json.dump({str(k): [v[0], v[1]] for k, v in sorted(mapping.items())},
                  open(path, 'w'), indent=1)

        print('%-10s %d/%d  %%%.1f   (1.gecis %d, 2.gecis +%d)'
              % (cat, cov, len(runtime), 100.0 * cov / len(runtime), first, cov - first))
        if unresolved:
            txt = ', '.join('%d..%d(%d)=%s' % (a, b, b - a + 1,
                            'cozum yok' if n == 0 else '%d doseme' % n)
                            for a, b, n in unresolved[:6])
            print('           cozulmeyen: %s' % txt)
        summary.append((cat, cov, len(runtime)))

    print('\n=== ozet ===')
    tot = done = 0
    for cat, c, n in summary:
        tot += n
        done += c
        print('  %-10s %4d/%-4d  %%%.1f' % (cat, c, n, 100.0 * c / n))
    print('  %-10s %4d/%-4d  %%%.1f' % ('TOPLAM', done, tot, 100.0 * done / tot))


if __name__ == '__main__':
    main()
