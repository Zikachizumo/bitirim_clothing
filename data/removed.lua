--[[
    data/removed.lua — MAGAZADAN CIKARILAN PARCALAR VE RENKLER

    Anahtar: cinsiyet > kategori anahtari > parca numarasi.
    Parca numarasi = oyunun drawable indeksi, magazada her tile'in sol ust
    kosesinde yaziyor. Kategoriye ozeldir: "headwear 214" ile "shoes 214"
    ayri parcalardir.

    IKI TUR KAYIT VAR:

    1) Deger METIN ise -> parca tamamen kalkar, metin sebebidir.

           [214] = 'bos',

    2) Deger TABLO ise -> sadece listelenen DOKU (renk) numaralari kalkar,
       parca kalir. Sag ustteki renk menusunde gorunen numaralar bunlar.

           [3] = { 0, 3, 4, 5, 6, 7, why = 'gorsel: dama tahtasi' },

       Yani "headwear 3'te doku 1 ve 2 kalsin, digerleri kalksin" demek.
       Bir parcanin BUTUN dokulari kalkarsa parca da listeden dusar --
       ayrica silmeye gerek yok.

    SEBEP ETIKETLERI:

    'bos'    Oyunun listesinde gorunen ama giyilince ekranda hicbir sey
             gostermeyen yer tutucular. Uydurulmadi, iki bagimsiz olcum:
               - tek dokulari 4x4 boyutunda "A8" yer tutucu
                 (gercek parcalarin dokusu 512x512 BC1/BC3)
               - /kiyafetcek kareleri bos: ayakkabi yerine ciplak ayak,
                 sapka yerine kel kafa, gozluk yok, ust giysi yok

    'dama tahtasi'
             Rockstar'in eksik-doku yer tutucusu: 64x64, iki renkli bir dama
             tahtasi. Deger METIN ise parcanin butun renkleri dama demektir.
             Tespit BAYT ESITLIGI ile yapiliyor, sezgisel degil: yer tutucu
             oyunun her yerinde AYNI DOSYA -- 64x64 BC1, 2728 bayt,
             sha1 cf8ff45d653c... Gercek bir giysi dokusu bununla bayt bayt
             ayni olamaz, yani yanlis pozitif imkansiz
             (tools/render/find_checker.py).

             503 doku, 53 parca. Bunlarin 6'sinda BUTUN renkler dama tahtasi,
             o parcalar komple cikti; kalan 47'sinde en az bir gercek renk var.

             Ayrica butun 12.651 render dama benzerligi puaniyla siralandi ve
             en yuksek 120'si tek tek incelendi: hepsi GERCEK desenli giysi
             (ekose, puantiye, zebra, balikkilcigi). Yani bayt esitliginin
             disinda kacan dama tahtasi YOK.

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
            [3]   = { 0, 3, 4, 5, 6, 7, why = 'dama tahtasi' },
            [4]   = { 2, 3, 4, 5, 6, 7, why = 'dama tahtasi' },
            [5]   = { 2, 3, 4, 5, 6, 7, why = 'dama tahtasi' },
            [8]   = 'dama tahtasi -- butun renkler',
            [9]   = { 0, 1, 2, 3, 4, 6, why = 'dama tahtasi' },
            [10]  = { 0, 1, 2, 3, 4, 6, why = 'dama tahtasi' },
            [11]  = { 0, 2, 4, 5, 7, why = 'dama tahtasi' },
            [12]  = { 3, 5, why = 'dama tahtasi' },
            [214] = 'bos',                    -- p_mp_m_2024_01 p_head_000
            [215] = 'bos',                    -- p_mp_m_2024_01 p_head_001
        },
        outerwear = {
            [0]   = { 6, 9, 10, 12, 13, 14, 15, why = 'dama tahtasi' },
            [1]   = { 2, 9, 10, 13, 15, why = 'dama tahtasi' },
            [2]   = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [4]   = { 1, 4, 5, 6, 7, 8, 9, 10, 12, 13, 15, why = 'dama tahtasi' },
            [5]   = { 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [6]   = { 2, 7, 10, why = 'dama tahtasi' },
            [8]   = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 15, why = 'dama tahtasi' },
            [9]   = { 8, 9, why = 'dama tahtasi' },
            [10]  = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [11]  = { 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 15, why = 'dama tahtasi' },
            [12]  = { 12, 13, 14, 15, why = 'dama tahtasi' },
            [13]  = { 4, 6, 7, 8, 9, 10, 11, 12, 14, 15, why = 'dama tahtasi' },
            [478] = 'bos',                    -- mp_m_2023_01 jbib_036
        },
        tshirts = {
            [0]  = { 6, 9, 10, 12, 13, 14, 15, why = 'dama tahtasi' },
            [1]  = { 2, 9, 10, 13, 15, why = 'dama tahtasi' },
            [2]  = { 6, 9, 10, 12, 13, 14, 15, why = 'dama tahtasi' },
            [3]  = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [4]  = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [5]  = { 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [8]  = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 15, why = 'dama tahtasi' },
            [9]  = { 8, 9, why = 'dama tahtasi' },
            [12] = { 12, 13, 14, 15, why = 'dama tahtasi' },
            [13] = { 4, 6, 7, 8, 9, 10, 11, 12, 14, 15, why = 'dama tahtasi' },
            [14] = { 2, 9, 10, 13, 15, why = 'dama tahtasi' },
        },
        pants = {
            [2]  = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15, why = 'dama tahtasi' },
            [4]  = { 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [6]  = { 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [8]  = { 1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, why = 'dama tahtasi' },
            [10] = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [11] = 'dama tahtasi -- butun renkler',
            [12] = { 1, 2, 3, 6, 8, 9, 10, 11, 13, 14, 15, why = 'dama tahtasi' },
            [13] = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [14] = { 2, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, why = 'dama tahtasi' },
        },
        shoes = {
            [0]  = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [2]  = { 0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 14, 15, why = 'dama tahtasi' },
            [4]  = { 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [5]  = { 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [6]  = { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, why = 'dama tahtasi' },
            [10] = { 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 13, 15, why = 'dama tahtasi' },
            [11] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 13, why = 'dama tahtasi' },
            [13] = 'dama tahtasi -- butun renkler',
            [33] = 'bos',                    -- male_apt01 feet_000
        },
        glasses = {
            [0]  = { 0, 1, 2, 3, 4, 5, 6, 7, why = 'dama tahtasi' },
            [1]  = { 0, 2, 3, 4, 5, 6, 7, why = 'dama tahtasi' },
            [6]  = 'dama tahtasi -- butun renkler',
            [11] = 'dama tahtasi -- butun renkler',
            [14] = 'dama tahtasi -- butun renkler',
            [49] = 'bos',                    -- p_mp_m_2023_01 p_eyes_002
            [50] = 'bos',                    -- p_mp_m_2023_01 p_eyes_003
        },
    },
}
