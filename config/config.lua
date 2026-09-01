--[[
    bitirim_clothing — kategori / fiyat / slot yapilandirmasi

    DIKKAT: `slot` alanlari bitirim_inventory'nin data/bitirim_clothing.lua
    dosyasindaki `slots` tablosu anahtarlariyla BIREBIR ayni olmak zorunda.
    Farkli yazilirsa envanter satin alinan parcayi tanimaz.

    Fiyatlar oyundan alinan 2026-09-01 ekran goruntulerinden okundu.
    Satin alma sirasinda SERVER bu tablodan dogrular; client'a guvenilmez.
]]

Config = Config or {}

--- Kategori sirasi = NUI kok ekranindaki sira.
Config.Categories = {
    {
        key   = 'headwear',
        label = 'HEADWEAR',
        icon  = 'hat',
        kind  = 'prop',      id = 0,
        slot  = 'hat',
        price = 600,
        camera = 'head',
    },
    {
        key   = 'outerwear',
        label = 'OUTERWEAR',
        icon  = 'jacket',
        kind  = 'component', id = 11,
        slot  = 'jacket',
        price = 1350,
        camera = 'torso',
    },
    {
        key   = 'tshirts',
        label = 'T-SHIRTS',
        icon  = 'tshirt',
        kind  = 'component', id = 8,
        slot  = 'tshirt',
        price = 1000,
        camera = 'torso',
    },
    {
        key   = 'pants',
        label = 'PANTS',
        icon  = 'pants',
        kind  = 'component', id = 4,
        slot  = 'pants',
        price = 600,
        camera = 'legs',
    },
    {
        key   = 'shoes',
        label = 'SHOES',
        icon  = 'shoes',
        kind  = 'component', id = 6,
        slot  = 'shoes',
        price = 850,
        camera = 'feet',
    },
    {
        key   = 'glasses',
        label = 'GLASSES',
        icon  = 'glasses',
        kind  = 'prop',      id = 1,
        slot  = 'glasses',
        price = 1000,
        camera = 'head',
    },
}

--[[
    UNDERWEAR — bir slot bosaltilinca donulecek taban gorunum.
    bitirim_inventory/data/bitirim_clothing.lua -> `underwear` tablosu ile
    SENKRON TUTULMALIDIR. Degerler VPS'teki eski surumden geri alinacak;
    buraya tahminle deger yazilmaz.
]]
Config.Underwear = {
    -- TODO: VPS'teki eski config/config.lua'dan tasi (bkz. README).
}

--[[
    UST GIYSI GIYILINCE KOLUN (component 3) ALACAGI VARSAYILAN DEGER.
    Erkek degeri oyunda olculdu (135, ELDIVENLI bir parca).
    Kadin HENUZ OLCULMEDI -- olculene kadar dokunulmuyor (-1 = kola dokunma).
]]
Config.DefaultArms = {
    male   = { drawable = 135, texture = 0 },
    female = { drawable = -1,  texture = 0 },
}
