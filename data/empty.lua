--[[
    data/empty.lua — GIYILDIGINDE HICBIR SEY GOSTERMEYEN PARCALAR

    Bunlar "gizlenmis" parcalar DEGIL (onlar icin client/hidden.lua + DB var).
    Bunlar oyunun kendi dosyalarindaki BOS YER TUTUCULAR: model dosyasi var,
    magaza listesinde gorunuyorlar, ama uzerine giyilince ekranda hicbir sey
    olmuyor.

    Nasil bulundular (tahmin degil, iki bagimsiz olcum):
      1. Dosya tarafi: bu parcalarin TEK dokusu 4x4 boyutunda "A8" formatinda
         bir yer tutucu. Gercek parcalarin dokusu 512x512 BC1/BC3.
      2. Oyun tarafi: /kiyafetcek ile alinan kareler bos cikti -- ayakkabi
         yerine ciplak ayak, sapka yerine kel kafa, gozluk yok, ust giysi yok.

    Satin alinamayacaklari icin katalogdan tamamen cikariliyorlar
    (bkz. client/catalog.lua). Boylece magazada gorseli olmayan tile kalmiyor.

    Kadin tarafi HENUZ OLCULMEDI -- kadin dump'i alinmadi, uydurulmadi.
]]

return {
    male = {
        headwear  = { [214] = true, [215] = true },  -- p_mp_m_2024_01 p_head_000/001
        outerwear = { [478] = true },                -- mp_m_2023_01   jbib_036
        shoes     = { [33]  = true },                -- male_apt01     feet_000
        glasses   = { [49]  = true, [50]  = true },  -- p_mp_m_2023_01 p_eyes_002/003
    },
}
