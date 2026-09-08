"""data/removed.lua'dan retile listesi uret.

Tile her zaman doku 0'dan cizilir. Ama removed.lua doku 0'i kaldirmissa
magazada gorunmeyen bir rengi tanitiyor oluruz. Kural: tile, HAYATTA KALAN
en kucuk numarali dokudan cizilmeli.
"""
import re, sys, json

CAT = {'headwear': 'hat', 'outerwear': 'jacket', 'tshirts': 'tshirt',
       'pants': 'pants', 'shoes': 'shoes', 'glasses': 'glasses'}

def parse(path):
    """-> {slot: {drawable: set(kaldirilan doku) | None}}  None = parca tamamen kalkti"""
    out, cur = {}, None
    for line in open(path, encoding='utf-8'):
        m = re.match(r'\s*(\w+)\s*=\s*\{\s*$', line)
        if m and m.group(1) in CAT:
            cur = CAT[m.group(1)]; out[cur] = {}; continue
        if cur is None:
            continue
        m = re.match(r"\s*\[(\d+)\]\s*=\s*\{(.*?)\}", line)
        if m:
            nums = [int(x) for x in re.findall(r'(?<![\w])(\d+)\s*(?=,|\})', m.group(2))]
            out[cur][int(m.group(1))] = set(nums); continue
        m = re.match(r"\s*\[(\d+)\]\s*=\s*'", line)
        if m:
            out[cur][int(m.group(1))] = None
    return out

if __name__ == '__main__':
    rules = parse(sys.argv[1])
    counts = json.load(open(sys.argv[2]))   # dump/male.json -> doku sayilari
    import os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from batch_tex import DUMPKEY
    ntex = {slot: {x['d']: int(x.get('tex') or 0) for x in counts[kind][key]}
            for slot, (kind, key) in DUMPKEY.items()}

    jobs, gone, kept = [], 0, 0
    for slot, items in sorted(rules.items()):
        for d, rem in sorted(items.items()):
            if rem is None:
                gone += 1; continue
            n = ntex.get(slot, {}).get(d, 0)
            left = [t for t in range(n) if t not in rem]
            if not left:
                gone += 1; continue
            kept += 1
            if left[0] != 0:
                jobs.append([slot, d, left[0]])
    print('kural: %d parca tamamen kalkti, %d parca kismen' % (gone, kept))
    print('tile yeniden cizilecek: %d' % len(jobs))
    for j in jobs:
        print('   %-8s %4d <- doku %d' % tuple(j))
    json.dump(jobs, open(sys.argv[3], 'w'), indent=1)
    print('yazildi: %s' % sys.argv[3])
