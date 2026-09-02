"""
Her parcanin HER DOKU VARYANTINI ayri ayri render et.

Neden: magazadaki renk secici gercek rengi gostersin. Ustelik doku varyanti
sadece rengi degil SILUETI de degistirebiliyor (olculdu: jbib_000 varyant 'a'
kolsuz atlet, varyant 'b' kollu tisort) -- yani "ayni parca farkli renk"
varsayimi yanlis.

Harf <-> indeks eslemesi:
    varyant harfleri her parcada kesintisiz a,b,c... diye gidiyor (1390
    parcanin 1390'inda dogrulandi) ve oyunun bildirdigi doku sayisi ile dosya
    sayisi 1382'sinde birebir ayni. Yani harf sirasi = doku indeksi.
    'a' = 0 ayrica bagimsiz olarak dogrulanmisti: oyun ici kareler doku 0 ile
    cekilmisti ve 'a' varyantindan render edilen parcalarla birebir tutmustu
    (bkz. verify.py, drawable 157/206/413).

Cikti: <cikti>/<slot>_<drawable>_<doku>.png -- saydam, kucuk (varsayilan 128).
Var olan dosyalari atlar, yarim kalirsa kaldigi yerden devam eder.
"""

import os
import sys
import json
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fivefury as ff
import render_ydd
import batch

# slot -> (dump bolumu, dump anahtari)
DUMPKEY = {
    'jacket': ('components', '11'), 'tshirt': ('components', '8'),
    'pants': ('components', '4'),   'shoes': ('components', '6'),
    'hat': ('props', '0'),          'glasses': ('props', '1'),
}


def game_counts(dumpfile):
    """slot -> {drawable: oyunun bildirdigi doku sayisi}"""
    dump = json.load(open(dumpfile))
    out = {}
    for slot, (kind, key) in DUMPKEY.items():
        out[slot] = {x['d']: int(x.get('tex') or 0) for x in dump[kind][key]}
    return out


def main():
    mapdir, dumpfile, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
    size = int(sys.argv[4]) if len(sys.argv) > 4 else 128
    os.makedirs(outdir, exist_ok=True)
    tmp = os.path.join(outdir, '_tmp')
    os.makedirs(tmp, exist_ok=True)

    want = batch.load_wanted(mapdir)
    counts = game_counts(dumpfile)
    print('istenen parca: %d' % len(want))

    t0 = time.time()
    ydds, ytds = {}, {}
    for src in batch.sources():
        try:
            a = ff.load_rpf(src)
        except Exception:
            continue
        batch.index_walk(a, want, ydds, ytds)
    print('indeks %.0f sn: %d ydd' % (time.time() - t0, len(ydds)))

    stats = {'yazildi': 0, 'atlandi': 0, 'dosya_yok': 0, 'hata': 0}
    yp = os.path.join(tmp, 'a.ydd')
    tp = os.path.join(tmp, 'a.ytd')

    for k, (ar, ydd_e) in sorted(ydds.items()):
        slot, drawable = want[k]
        folder, prefix, num = k
        ntex = counts.get(slot, {}).get(drawable, 0)
        if ntex <= 0:
            continue

        # Ayni harfin birden fazla kopyasi olabilir (patch + asil) ve bazi
        # kopyalar cozulemeyen formatta; hepsini tutup sirayla deniyoruz.
        by_letter = {}
        for letter, tar, te in ytds.get(k, []):
            by_letter.setdefault(letter, []).append((tar, te))

        todo = [t for t in range(ntex)
                if not os.path.exists(os.path.join(outdir, '%s_%d_%d.png' % (slot, drawable, t)))]
        stats['atlandi'] += ntex - len(todo)
        if not todo:
            continue

        try:
            open(yp, 'wb').write(ar.read_entry_standalone(ydd_e))
        except Exception as ex:
            stats['hata'] += len(todo)
            continue

        for t in todo:
            letter = chr(ord('a') + t)
            cands = by_letter.get(letter)
            if not cands:
                stats['dosya_yok'] += 1
                continue
            out = os.path.join(outdir, '%s_%d_%d.png' % (slot, drawable, t))
            want_name = '%s_diff_%03d_%s' % (prefix, num, letter)
            done = False
            for tar, te in cands:
                try:
                    open(tp, 'wb').write(tar.read_entry_standalone(te))
                    render_ydd.render(yp, tp, out, size=size, yaw=180,
                                      quiet=True, prefer=want_name,
                                      basis=render_ydd.basis_for(prefix))
                    done = True
                    break
                except Exception:
                    pass
            if done:
                stats['yazildi'] += 1
                if stats['yazildi'] % 500 == 0:
                    print('  %d yazildi  %.0f sn' % (stats['yazildi'], time.time() - t0),
                          flush=True)
            else:
                stats['hata'] += 1

    print('\nbitti: %(yazildi)d yazildi, %(atlandi)d zaten vardi, '
          '%(dosya_yok)d dosyasi yok, %(hata)d hata' % stats)
    print('sure %.0f sn' % (time.time() - t0))


if __name__ == '__main__':
    main()
