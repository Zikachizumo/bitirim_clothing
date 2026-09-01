"""
ESLEMEYI KANITLA: eslenen bir drawable'i dosyadan render et.

Oyundan cekilmis ayni numarali thumbnail ile yan yana konunca esleme dogru mu
gorulur. Yanlissa tamamen baska bir giysi cikar -- yani bu test sessiz kalmaz.
"""

import os
import re
import sys
import json

import fivefury as ff

GTA = r'D:\SteamLibrary\steamapps\common\Grand Theft Auto V Enhanced'
DLC = os.path.join(GTA, 'update', 'x64', 'dlcpacks')


def find_files(folder, prefix, num):
    """Bir drawable'in .ydd'sini ve doku .ytd'lerini arsivlerden cikar."""
    ydd_pat = re.compile(r'^%s_%03d_[a-z]\.ydd$' % (prefix, num))
    ytd_pat = re.compile(r'^%s_diff_%03d_([a-z])(?:_.*)?\.ytd$' % (prefix, num))

    sources = [os.path.join(GTA, 'x64v.rpf')]
    sources += [os.path.join(DLC, d, 'dlc.rpf') for d in sorted(os.listdir(DLC))]

    ydd, ytds = None, {}
    for src in sources:
        if not os.path.exists(src):
            continue
        try:
            a = ff.load_rpf(src)
        except Exception:
            continue
        for e in list(a.iter_entries()):
            s = str(getattr(e, 'path', ''))
            if not s.lower().endswith('.rpf') or 'cdimage' not in s.lower():
                continue
            try:
                n = a.load_nested_archive(e)
            except Exception:
                continue
            if n is None:
                continue
            for e2 in n.iter_entries():
                s2 = str(getattr(e2, 'path', ''))
                parts = s2.split('/')
                if len(parts) < 2 or parts[-2].lower() != folder:
                    continue
                f = parts[-1]
                if ydd is None and ydd_pat.match(f):
                    ydd = (n.read_entry_standalone(e2), s2, src)
                m = ytd_pat.match(f)
                if m and m.group(1) not in ytds:
                    ytds[m.group(1)] = (n.read_entry_standalone(e2), s2)
        if ydd and ytds:
            break
    return ydd, ytds


def main():
    mapping_arg = sys.argv[1]        # "folder:prefix:num"
    out_dir = sys.argv[2]
    folder, prefix, num = mapping_arg.split(':')
    num = int(num)

    ydd, ytds = find_files(folder, prefix, num)
    if not ydd:
        print('  .ydd BULUNAMADI: %s / %s_%03d' % (folder, prefix, num))
        return
    print('  ydd : %s   (%s)' % (ydd[1], os.path.basename(ydd[2])))
    for k in sorted(ytds):
        print('  ytd %s: %s' % (k, ytds[k][1]))

    os.makedirs(out_dir, exist_ok=True)
    yp = os.path.join(out_dir, '_tmp.ydd')
    open(yp, 'wb').write(ydd[0])

    letter = sorted(ytds)[0]
    tp = os.path.join(out_dir, '_tmp.ytd')
    open(tp, 'wb').write(ytds[letter][0])

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import render_ydd
    out = os.path.join(out_dir, '%s_%s_%03d.png' % (folder[-14:], prefix, num))
    render_ydd.render(yp, tp, out, size=512, yaw=180)


if __name__ == '__main__':
    main()
