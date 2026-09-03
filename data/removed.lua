--[[
    data/removed.lua — MAGAZADAN CIKARILAN PARCALAR VE RENKLER

    ============================================================
    SU AN BOS -- BUTUN CIKARMALAR IPTAL EDILDI (2026-09-03)
    ============================================================

    Istek: "Liste 0-1-2-3 diye sonuna kadar gitsin, hicbir eksik kiyafet
    olmasin, tum kategorilerde."

    Onceki dosya 610 parcayi katalogdan dusuruyordu. Dagilimi olculdu:

        592  'gorsel: kullanici listesi'          <- elle secilenler
          7  'bos'
          6  'dama tahtasi -- butun renkler'
          5  'gorsel: duz renkli levha, giysi silueti yok'
          1  '4x4 yer tutucu doku -- tek rengi bu'

    Ayrica 35 parcada sadece belirli renkler kisitlanmisti (33 dama tahtasi,
    2 gorsel, 1 yer tutucu doku).

    Outerwear'da 544 parcanin 272'si cikarilmisti; magaza bu yuzden 0 ve 1
    yerine 2'den basliyordu.

    ORIJINAL LISTE KAYBOLMADI:
      - data/removed_ORIJINAL.lua.bak  (bu klasorde, birebir kopya)
      - git gecmisi                    (git show HEAD:data/removed.lua)

    GERI ALMAK ICIN:
        cp data/removed_ORIJINAL.lua.bak data/removed.lua
        restart bitirim_clothing

    NOT: client/catalog.lua icindeki isBaseState filtresi de ayni istek
    dogrultusunda kapatildi -- o da her kategoride bir numara atliyordu
    (ust 15, tisort 15, pantolon 21, ayakkabi 34).

    ------------------------------------------------------------
    Dosyanin ORIJINAL bicimi (geri yazarken sema bu):

    Anahtar: cinsiyet > kategori anahtari > parca numarasi.

      1) Deger METIN ise -> parca tamamen kalkar, metin sebebidir.
             [214] = 'bos',
      2) Deger TABLO ise -> sadece listelenen DOKU numaralari kalkar.
             [3] = { 0, 3, 4, 5, 6, 7, why = 'gorsel: dama tahtasi' },
    ------------------------------------------------------------
]]

return {}
