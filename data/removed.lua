--[[
    data/removed.lua — MAGAZADAN CIKARILAN PARCALAR

    Anahtar: cinsiyet > kategori anahtari > parca numarasi.
    Parca numarasi = oyunun drawable indeksi, magazada her tile'in kosesinde
    yaziyor. Kategoriye ozeldir: "headwear 214" ile "shoes 214" ayri parcalar.

    Deger, cikarilma SEBEBI (serbest metin). Filtreleme sadece "kayit var mi"
    diye bakar, bkz. client/catalog.lua.

    Iki tur sebep var:

    'bos'    Oyunun listesinde gorunen ama giyilince ekranda hicbir sey
             gostermeyen yer tutucular. Uydurulmadi, iki bagimsiz olcum:
               - tek dokulari 4x4 boyutunda "A8" yer tutucu
                 (gercek parcalarin dokusu 512x512 BC1/BC3)
               - /kiyafetcek kareleri bos: ayakkabi yerine ciplak ayak,
                 sapka yerine kel kafa, gozluk yok, ust giysi yok

    'gorsel' Oyun icinde GORSEL OLARAK bozuk oldugu icin cikarilanlar.
             Bu karar tamamen kullaniciya ait -- agent oyunu goremez.
             Sebep alanina ne gorundugu kisaca yazilir.

    Bu dosya DB'deki gizleme tablosundan (client/hidden.lua) ayridir: burasi
    kalici ve kod ile gelen liste, orasi oyun ici arac ile isaretlenenler.

    Kadin tarafi HENUZ OLCULMEDI -- kadin dump'i alinmadi, uydurulmadi.
]]

return {
    male = {
        headwear = {
            [214] = 'bos',   -- p_mp_m_2024_01 p_head_000
            [215] = 'bos',   -- p_mp_m_2024_01 p_head_001
        },
        outerwear = {
            [478] = 'bos',   -- mp_m_2023_01 jbib_036
        },
        shoes = {
            [33]  = 'bos',   -- male_apt01 feet_000
        },
        glasses = {
            [49]  = 'bos',   -- p_mp_m_2023_01 p_eyes_002
            [50]  = 'bos',   -- p_mp_m_2023_01 p_eyes_003
        },
        tshirts = {},
        pants   = {},
    },
}
