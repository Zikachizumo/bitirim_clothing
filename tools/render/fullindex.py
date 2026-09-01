"""
TUM arsivleri FILTRESIZ gez, giysi dosyalarinin tam indeksini cikar.

Neden filtresiz: onceki tarama '_giysi_arsivi' ad filtresiyle iniyordu ve
mptuner/mpbattle/mpheist4/mpsecurity klasorlerini hic bulamamisti. Filtre
parmak izi yontemi icin gerekliydi (fazla doku diziyi bozuyordu); artik
esleme shop.meta'dan geliyor, yani fazladan dosya gormek ZARARSIZ.

Cikti: index.json = {klasor: {tur: {numara: {"tex": [harfler], "arc": id}}}}
       arcs.json  = {id: "kaynak > yol > yol"}
"""
import os, re, sys, json, time
from collections import defaultdict
import fivefury as ff

GTA = os.environ.get("GTA_DIR", r"D:SteamLibrarysteamappsmmonGrand Theft Auto V Enhanced")
DLC = os.path.join(GTA, 'update', 'x64', 'dlcpacks')

YDD      = re.compile(r'^([a-z_]+?)_(\d{3})_[a-z]\.ydd$')
YTD      = re.compile(r'^([a-z_]+?)_diff_(\d{3})_([a-z])(?:_.*)?\.ytd$')
PROP_YDD = re.compile(r'^(p_[a-z]+)_(\d{3})\.ydd$')
PROP_YTD = re.compile(r'^(p_[a-z]+)_diff_(\d{3})_([a-z])\.ytd$')

idx  = defaultdict(lambda: defaultdict(lambda: {'ydd': None, 'tex': {}}))
arcs = {}
seen_arc = 0

def scan(a, label, depth=0):
    global seen_arc
    aid = str(seen_arc); seen_arc += 1
    arcs[aid] = label
    nested = []
    for e in a.iter_entries():
        s = str(getattr(e, 'path', '')); low = s.lower()
        parts = s.split('/')
        fname = parts[-1]
        folder = parts[-2].lower() if len(parts) > 1 else ''
        if low.endswith('.ydd'):
            m = YDD.match(fname) or PROP_YDD.match(fname)
            if m:
                idx[folder][m.group(1) + '/' + m.group(2)]['ydd'] = aid
        elif low.endswith('.ytd'):
            m = YTD.match(fname) or PROP_YTD.match(fname)
            if m:
                idx[folder][m.group(1) + '/' + m.group(2)]['tex'][m.group(3)] = aid
        elif low.endswith('.rpf') and depth < 4:
            nested.append((e, low.rsplit('/', 1)[-1]))
    for e, nm in nested:
        try:
            n = a.load_nested_archive(e)
        except Exception:
            continue
        if n is not None:
            scan(n, label + '>' + nm, depth + 1)

srcs  = [(os.path.join(GTA, 'x64%s.rpf' % c), 'x64%s.rpf' % c) for c in 'abcdefghijklmnopqrstuvw']
srcs += [(os.path.join(GTA, 'update', f), f) for f in ('update.rpf', 'update2.rpf')]
# BIR PAKETTE BIRDEN FAZLA dlc*.rpf OLABILIR. mpbattle/mpheist4/mpsecurity/
# mptuner erkek giysilerini dlc1.rpf / dlc2.rpf'te tutuyor; sadece dlc.rpf'e
# bakmak bu 4 paketin butun erkek giysilerini kaciriyordu (132 parca).
for d in sorted(os.listdir(DLC)):
    for f in sorted(os.listdir(os.path.join(DLC, d))):
        if re.match(r'^dlc\d*\.rpf$', f.lower()):
            srcs.append((os.path.join(DLC, d, f), '%s/%s' % (d, f)))

t0 = time.time()
for p, label in srcs:
    if not os.path.exists(p):
        continue
    try:
        a = ff.load_rpf(p)
    except Exception as ex:
        print('%-24s acilamadi: %s' % (label, ex), flush=True); continue
    before = len(idx)
    scan(a, label)
    print('%-24s %6.1fs  klasor toplam %d (+%d)' % (label, time.time() - t0, len(idx), len(idx) - before), flush=True)

out = {f: {k: {'ydd': v['ydd'], 'tex': v['tex']} for k, v in m.items()} for f, m in idx.items()}
json.dump(out,  open('index.json', 'w'))
json.dump(arcs, open('arcs.json', 'w'))
print('BITTI  %d klasor  %d arsiv  %.1fs' % (len(out), len(arcs), time.time() - t0), flush=True)
