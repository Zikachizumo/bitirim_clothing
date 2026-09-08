"""removed.lua'dan gen9 parcalarini cikar (magazaya geri gelsinler).

Bunlar Legacy'de 497 baytlik bos kabuktu, o yuzden kare gorselleri bostu ve
kullanici listesinde "kaldir" isaretlenmisti. Enhanced'ta gercek mesh var.
"""
import re, sys, json

CAT = {'hat': 'headwear', 'jacket': 'outerwear', 'tshirt': 'tshirts',
       'pants': 'pants', 'shoes': 'shoes', 'glasses': 'glasses'}

def main(path, items):
    want = {}
    for slot, nums in items.items():
        want.setdefault(CAT[slot], set()).update(nums)
    out, cur, removed = [], None, []
    for line in open(path, encoding='utf-8').read().split('\n'):
        m = re.match(r'\s*(\w+)\s*=\s*\{\s*$', line)
        if m and m.group(1) in want.values() or (m and m.group(1) in CAT.values()):
            cur = m.group(1)
        m = re.match(r"\s*\[(\d+)\]\s*=\s*'([^']*)'", line)
        if m and cur in want and int(m.group(1)) in want[cur]:
            removed.append((cur, int(m.group(1)), m.group(2)))
            continue
        out.append(line)
    open(path, 'w', encoding='utf-8').write('\n'.join(out))
    print('%d satir cikarildi' % len(removed))
    from collections import Counter
    print('  kategori:', dict(Counter(c for c, _, _ in removed)))
    print('  sebep   :', dict(Counter(r for _, _, r in removed)))
    miss = {c: sorted(want[c] - {n for cc, n, _ in removed if cc == c}) for c in want}
    miss = {c: v for c, v in miss.items() if v}
    print('  BULUNAMAYAN:', miss if miss else 'yok')
    return len(removed)

if __name__ == '__main__':
    items = json.load(open(sys.argv[2]))
    main(sys.argv[1], items)
