"""
shop.meta'nin kapsamadigi 12 parca -- ELEME ile bulundu, tahminle degil.

Bu 12 parcanin apparel hash'i shop.meta'nin 16471 kaydinin hicbirinde yok
(magazada satilmiyorlar). Cozum su kisitlarla kuruldu:
  1. Bosluk, eslenmis komsulari arasinda: hangi DLC'lerin arasina dustugu belli.
  2. O donemin KULLANILMAYAN dosyalari sayilidir (indeksten cikarildi).
  3. Oyunun bildirdigi doku sayisi ile dosyanin doku varyanti sayisi esit olmali.

Ucu birden ayni sonucu veriyor. Gozluk 23 icin ozellikle guclu: oyunun
TAMAMINDA kullanilmayan tek bir p_eyes dosyasi var.

Yine de bu bir cikarim -- render'lar oyun ici karelerle GORSEL olarak
karsilastirilip dogrulandi (verify_extra.py).
"""
import json, os

EXTRA = {
    'hat': {
        57: ('mp_m_freemode_01_p_male_apt01', 0),          # doku 1  = 1
        58: ('mp_m_freemode_01_p_male_apt01', 1),          # doku 3  = 3
        59: ('mp_m_freemode_01_p_mp_m_january2016', 0),    # doku 10 = 10
        60: ('mp_m_freemode_01_p_mp_m_january2016', 1),
        61: ('mp_m_freemode_01_p_mp_m_january2016', 2),
        62: ('mp_m_freemode_01_p_mp_m_january2016', 3),
        63: ('mp_m_freemode_01_p_mp_m_january2016', 4),
        64: ('mp_m_freemode_01_p_mp_m_valentines_02', 0),  # doku 12 = 12
    },
    'glasses': {
        23: ('mp_m_freemode_01_p_mp_m_january2016', 0),    # doku 10 = 10
    },
    'shoes': {
        17: ('mp_m_freemode_01_male_xmas', 0),             # doku 1  = 1
        39: ('mp_m_freemode_01_mp_m_xmas_03', 0),          # doku 1  = 1
        40: ('mp_m_freemode_01_mp_m_valentines_02', 0),    # doku 12 = 12
    },
}

if __name__ == '__main__':
    src, dst = 'render/map7', 'render/map8'
    os.makedirs(dst, exist_ok=True)
    for fn in os.listdir(src):
        if not fn.startswith('map_'):
            continue
        slot = fn[4:-5]
        m = json.load(open(os.path.join(src, fn)))
        added = 0
        for d, v in EXTRA.get(slot, {}).items():
            if str(d) in m:
                print('   ZATEN VAR %s %d -- atlandi' % (slot, d))
                continue
            m[str(d)] = list(v)
            added += 1
        json.dump(m, open(os.path.join(dst, fn), 'w'), indent=1)
        print('%-8s %4d giris (+%d)' % (slot, len(m), added))
    for fn in ('labels.json', 'costs.json'):
        if os.path.exists(os.path.join(src, fn)):
            json.dump(json.load(open(os.path.join(src, fn))),
                      open(os.path.join(dst, fn), 'w'), indent=1)
