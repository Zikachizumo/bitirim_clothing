"""out/ (Legacy) ile out_enh/ (Enhanced) karelerini piksel piksel karsilastir."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, pngio

a_dir, b_dir = sys.argv[1], sys.argv[2]
rows = []
miss = []
for f in sorted(os.listdir(b_dir)):
    if not f.endswith('.png'):
        continue
    pa = os.path.join(a_dir, f)
    if not os.path.exists(pa):
        miss.append(f); continue
    A = pngio.read(pa).astype(np.float32)
    B = pngio.read(os.path.join(b_dir, f)).astype(np.float32)
    if A.shape != B.shape:
        rows.append((999.0, f, 0.0)); continue
    aa, ab = A[:, :, 3] / 255.0, B[:, :, 3] / 255.0
    # siluet farki (alfa) ve renk farki ayri olculur
    sil = float(np.abs(aa - ab).mean()) * 100
    m = np.minimum(aa, ab)[:, :, None]
    denom = float(m.sum()) or 1.0
    col = float((np.abs(A[:, :, :3] - B[:, :, :3]) * m).sum() / (denom * 3))
    rows.append((sil, f, col))
rows.sort(reverse=True)
print('%d kare karsilastirildi, %d eksik' % (len(rows), len(miss)))
print('siluet farki > %%1 olan: %d' % sum(1 for s, _, _ in rows if s > 1))
print('siluet farki > %%0.1 olan: %d' % sum(1 for s, _, _ in rows if s > 0.1))
print('\nen buyuk 40 siluet farki:')
for s, f, c in rows[:40]:
    print('   %-20s siluet %6.2f%%   renk %5.1f' % (f[:-4], s, c))
byc = sorted(rows, key=lambda r: -r[2])
print('\nen buyuk 15 renk farki:')
for s, f, c in byc[:15]:
    print('   %-20s renk %6.1f   siluet %5.2f%%' % (f[:-4], c, s))
json.dump([[f[:-4], round(s, 3), round(c, 2)] for s, f, c in rows],
          open('diffrank.json', 'w'))
