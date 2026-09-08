"""Bir parcanin (slot,drawable) BUTUN dosya adlarini listele -- sonekler dahil."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fivefury as ff, batch

slot, drawable = sys.argv[1], int(sys.argv[2])
mapdir = sys.argv[3] if len(sys.argv) > 3 else 'map8'
want = batch.load_wanted(mapdir)
ks = [k for k, v in want.items() if v == (slot, drawable)]
if not ks:
    print('haritada yok'); sys.exit(1)
folder, prefix, num = ks[0]
target = '%s_%03d' % (prefix, num)
print('%s %d -> klasor %s, dosya oneki %s' % (slot, drawable, folder, target))
hits = set()
def walk(a, src, depth=0):
    for e in list(a.iter_entries()):
        s = str(getattr(e, 'path', '')); low = s.lower(); f = s.split('/')[-1]
        parts = s.split('/')
        if low.endswith(('.ydd', '.ytd')) and f.lower().startswith(target) \
           and len(parts) > 1 and parts[-2].lower() == folder:
            try: n = len(a.read_entry_standalone(e))
            except Exception: n = -1
            hits.add((f, n, os.path.basename(os.path.dirname(src)) + '/' + os.path.basename(src)))
        elif low.endswith('.rpf') and depth < 3 and batch._clothing_rpf(low):
            try: nn = a.load_nested_archive(e)
            except Exception: continue
            if nn is not None: walk(nn, src, depth + 1)
for src in batch.sources():
    try: a = ff.load_rpf(src)
    except Exception: continue
    walk(a, src)
for f, n, src in sorted(hits):
    print('   %-32s %9d B   [%s]' % (f, n, src))
