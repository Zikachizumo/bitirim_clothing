"""
Ana tile gorselini BASKA bir doku varyantindan uret.

Neden gerekli: tile gorseli her zaman doku 0'dan ('a' varyanti) uretiliyordu.
Bazi parcalarda doku 0 dama tahtasi cikti ve katalogdan cikarildi -- o zaman
tile'in kendisi de dama tahtasi gosteriyor. Bu arac o parcalar icin tile'i
HAYATTA KALAN ilk dokudan yeniden cizer.

Girdi: JSON listesi [[slot, drawable, doku], ...]
"""
import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fivefury as ff
import render_ydd
import batch

def main():
    mapdir, listfile, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
    size = int(sys.argv[4]) if len(sys.argv) > 4 else 512
    jobs = json.load(open(listfile))
    if isinstance(jobs, dict):
        jobs = jobs['retile']
    tmp = os.path.join(outdir, '_tmp'); os.makedirs(tmp, exist_ok=True)

    want = batch.load_wanted(mapdir)
    ydds, ytds = {}, {}
    t0 = time.time()
    for src in batch.sources():
        try: a = ff.load_rpf(src)
        except Exception: continue
        batch.index_walk(a, want, ydds, ytds)
    print('indeks %.0f sn' % (time.time() - t0))

    rev = {v: k for k, v in want.items()}
    yp, tp = os.path.join(tmp, 'a.ydd'), os.path.join(tmp, 'a.ytd')
    ok = 0
    for slot, drawable, tex in jobs:
        k = rev.get((slot, drawable))
        if k is None or k not in ydds:
            print('  ATLANDI %s %d' % (slot, drawable)); continue
        folder, prefix, num = k
        letter = chr(ord('a') + tex)
        ar, ydd_e = ydds[k]
        open(yp, 'wb').write(ar.read_entry_standalone(ydd_e))
        out = os.path.join(outdir, '%s_%d.png' % (slot, drawable))
        done = False
        for L, tar, te in ytds.get(k, []):
            if L != letter: continue
            try:
                open(tp, 'wb').write(tar.read_entry_standalone(te))
                render_ydd.render(yp, tp, out, size=size, yaw=180, quiet=True,
                                  prefer='%s_diff_%03d_%s' % (prefix, num, letter))
                done = True; break
            except Exception as ex:
                print('  HATA %s %d doku %d: %s' % (slot, drawable, tex, ex))
        if done:
            ok += 1
            print('  %s_%d <- doku %d' % (slot, drawable, tex))
    print('%d/%d tile yeniden uretildi' % (ok, len(jobs)))

if __name__ == '__main__':
    main()
