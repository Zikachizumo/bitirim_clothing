"""Kurulumun TAMAMINDA bir dosya adini ara (filtre yok)."""
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fivefury as ff

GTA = os.environ.get('GTA_DIR', r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V')
name = sys.argv[1].lower()
hits = []
def walk(a, src, depth=0):
    for e in list(a.iter_entries()):
        s = str(getattr(e, 'path', '')); low = s.lower()
        f = low.split('/')[-1]
        if f.startswith(name) and low.endswith('.ydd'):
            try: n = len(a.read_entry_standalone(e))
            except Exception: n = -1
            parts = s.split('/')
            hits.append((parts[-2] if len(parts) > 1 else '?', parts[-1], n, src))
        elif low.endswith('.rpf') and depth < 4:
            try: nn = a.load_nested_archive(e)
            except Exception: continue
            if nn is not None: walk(nn, src, depth + 1)
srcs = []
for c in 'abcdefghijklmnopqrstuvw':
    p = os.path.join(GTA, 'x64%s.rpf' % c)
    if os.path.exists(p): srcs.append(p)
for f in ('update.rpf', 'update2.rpf'):
    p = os.path.join(GTA, 'update', f)
    if os.path.exists(p): srcs.append(p)
D = os.path.join(GTA, 'update', 'x64', 'dlcpacks')
for d in sorted(os.listdir(D)):
    for f in sorted(os.listdir(os.path.join(D, d))):
        if re.match(r'^dlc\d*\.rpf$', f.lower()):
            srcs.append(os.path.join(D, d, f))
for s in srcs:
    try: a = ff.load_rpf(s)
    except Exception: continue
    walk(a, s)
print('%d sonuc:' % len(hits))
for folder, f, n, src in sorted(set(hits)):
    rel = os.path.relpath(src, GTA)
    print('   %-40s %-24s %9d B   %s' % (folder, f, n, rel))
