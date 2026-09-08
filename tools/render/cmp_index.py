"""Legacy ve Enhanced indekslerini karsilastir: hangi parca nerede var/yok."""
import os, sys, json, time, importlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

LEG = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V'
ENH = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced'

def build(gta, mapdir):
    os.environ['GTA_DIR'] = gta
    import batch
    importlib.reload(batch)
    want = batch.load_wanted(mapdir)
    ydds, ytds = {}, {}
    for src in batch.sources():
        try: a = batch.ff.load_rpf(src)
        except Exception: continue
        batch.index_walk(a, want, ydds, ytds)
    sizes = {}
    for k, (ar, e) in ydds.items():
        try: sizes[want[k]] = len(ar.read_entry_standalone(e))
        except Exception: sizes[want[k]] = -1
    tex = {want[k] for k in ytds}
    return want, sizes, tex

mapdir = sys.argv[1]
want, LS, LT = build(LEG, mapdir)
print('LEGACY   ydd %d / istenen %d, ytd %d' % (len(LS), len(want), len(LT)))
want, ES, ET = build(ENH, mapdir)
print('ENHANCED ydd %d / istenen %d, ytd %d' % (len(ES), len(want), len(ET)))
allw = set(want.values())
onlyL = sorted(set(LS) - set(ES)); onlyE = sorted(set(ES) - set(LS))
print('sadece LEGACY %d, sadece ENHANCED %d, ikisinde %d'
      % (len(onlyL), len(onlyE), len(set(LS) & set(ES))))
from collections import Counter
print('  sadece legacy dagilim:', dict(Counter(s for s, _ in onlyL)))
print('  sadece enhanced dagilim:', dict(Counter(s for s, _ in onlyE)))
print('  ilk 15 sadece-legacy:', onlyL[:15])
STUB = 2000
ls = {k for k, v in LS.items() if 0 <= v < STUB}
es = {k for k, v in ES.items() if 0 <= v < STUB}
print('kucuk(<2KB) ydd -- legacy %d, enhanced %d' % (len(ls), len(es)))
fix = sorted(k for k in ls if ES.get(k, 0) >= STUB)
print('LEGACY stub ama ENHANCED dolu: %d' % len(fix))
print('  dagilim:', dict(Counter(s for s, _ in fix)))
json.dump({'onlyL': onlyL, 'onlyE': onlyE, 'legacy_stub': sorted(ls),
           'enh_stub': sorted(es), 'fix': fix,
           'LS': {'%s_%d' % k: v for k, v in LS.items()},
           'ES': {'%s_%d' % k: v for k, v in ES.items()}},
          open('cmp_index.json', 'w'), indent=1)
print('yazildi: cmp_index.json')
