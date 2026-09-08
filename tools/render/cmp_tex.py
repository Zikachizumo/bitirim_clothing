"""Her doku varyantinin BOYUTUNU iki kurulumda karsilastir.

Amac: Legacy'de "dama tahtasi" / yer tutucu olan bir doku Enhanced'ta gercek
olabilir mi? Oyleyse Enhanced'tan render edilen kare, oyunda (Legacy b3323)
gorunenle ORTUSMEZ -- bu bir risk, olculmeli.
"""
import os, sys, json, time, hashlib, importlib
from collections import defaultdict
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fivefury as ff

LEG = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V'
ENH = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced'

def scan(gta, mapdir, dumpfile):
    os.environ['GTA_DIR'] = gta
    import batch, batch_tex
    importlib.reload(batch); importlib.reload(batch_tex)
    want = batch.load_wanted(mapdir)
    counts = batch_tex.game_counts(dumpfile)
    ydds, ytds = {}, {}
    for src in batch.sources():
        try: a = ff.load_rpf(src)
        except Exception: continue
        batch.index_walk(a, want, ydds, ytds)
    res = {}
    for k in sorted(ydds):
        slot, drawable = want[k]
        folder, prefix, num = k
        n = counts.get(slot, {}).get(drawable, 0)
        by = defaultdict(list)
        for letter, tar, te in ytds.get(k, []):
            by[letter].append((tar, te))
        for t in range(n):
            letter = chr(ord('a') + t)
            for tar, te in by.get(letter, []):
                try: ytd = ff.read_ytd(tar.read_entry_standalone(te))
                except Exception: continue
                name = '%s_diff_%03d_%s' % (prefix, num, letter)
                tex = next((x for x in ytd.textures
                            if (x.name or '').lower().startswith(name)), None)
                if tex is None: continue
                res[(slot, drawable, t)] = (tex.width, tex.height, tex.format_name,
                                            hashlib.sha1(bytes(tex.data)).hexdigest())
                break
    return res

mapdir, dumpfile = sys.argv[1], sys.argv[2]
t0 = time.time()
L = scan(LEG, mapdir, dumpfile); print('legacy   %d doku  %.0f sn' % (len(L), time.time()-t0), flush=True)
E = scan(ENH, mapdir, dumpfile); print('enhanced %d doku  %.0f sn' % (len(E), time.time()-t0), flush=True)

SMALL = 64 * 64          # yer tutucular 64x64 veya daha kucuk
common = sorted(set(L) & set(E))
ls = {k for k in common if L[k][0]*L[k][1] <= SMALL}
es = {k for k in common if E[k][0]*E[k][1] <= SMALL}
print('ortak %d doku' % len(common))
print('kucuk(<=64x64) -- legacy %d, enhanced %d' % (len(ls), len(es)))
print('LEGACY kucuk ama ENHANCED buyuk (RISK): %d' % len(ls - es))
print('ENHANCED kucuk ama LEGACY buyuk       : %d' % len(es - ls))
from collections import Counter
print('  risk dagilimi:', dict(Counter(s for s, _, _ in (ls - es))))
for k in sorted(ls - es)[:10]:
    print('   %-8s %4d doku %d   legacy %dx%d %s -> enhanced %dx%d %s'
          % (k[0], k[1], k[2], L[k][0], L[k][1], L[k][2], E[k][0], E[k][1], E[k][2]))
print('format dagilimi legacy  :', dict(Counter(v[2] for v in L.values())))
print('format dagilimi enhanced:', dict(Counter(v[2] for v in E.values())))

h_same = sum(1 for k in common if L[k][3] == E[k][3])
print('DOKU BAYTLARI BIREBIR AYNI: %d / %d' % (h_same, len(common)))
diffh = [k for k in common if L[k][3] != E[k][3]]
from collections import Counter as C2
print('  farkli olanlarin dagilimi:', dict(C2(s for s, _, _ in diffh)))
json.dump(['%s_%d_%d' % k for k in sorted(diffh)], open('texhash_diff.json', 'w'))

json.dump({'risk': ['%s_%d_%d' % k for k in sorted(ls - es)],
           'enh_small': ['%s_%d_%d' % k for k in sorted(es)],
           'leg_small': ['%s_%d_%d' % k for k in sorted(ls)]},
          open('cmp_tex.json', 'w'), indent=1)
print('yazildi: cmp_tex.json')
