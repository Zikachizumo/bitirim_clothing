--[[
    bitirim_clothing — kategori / fiyat / slot yapilandirmasi

    DIKKAT: `slot` alanlari bitirim_inventory'nin data/bitirim_clothing.lua
    dosyasindaki `slots` tablosu anahtarlariyla BIREBIR ayni olmak zorunda.
    Farkli yazilirsa envanter satin alinan parcayi tanimaz.

    Fiyatlar referans gorsellerden okundu. Satin alma sirasinda SERVER bu
    tablodan dogrular; client'a guvenilmez.

    KOL (component 3) BURADA YOK ve bilinctli olarak yok -- oyuncu kolu
    secemez, kol katmanli savunmayla otomatik belirlenir (client/compat.lua,
    docs/COMPATIBILITY.md).
]]

Config = Config or {}

Config.Currency       = '$'
Config.ItemName       = 'apparel'   -- envanterdeki generic kiyafet item'i
Config.PaymentAccount = 'cash'
Config.MaxCartItems   = 12

--- Kategori sirasi = NUI kok ekranindaki sira.
Config.Categories = {
    {
        key   = 'headwear',
        label = 'HEADWEAR',
        itemLabel = 'Sapka',
        icon  = 'hat',
        kind  = 'prop',      id = 0,
        slot  = 'hat',
        price = 600,
        camera = 'head',
    },
    {
        key   = 'outerwear',
        label = 'OUTERWEAR',
        itemLabel = 'Ust Giysi',
        icon  = 'jacket',
        kind  = 'component', id = 11,
        slot  = 'jacket',
        price = 1350,
        camera = 'torso',
    },
    {
        key   = 'tshirts',
        label = 'T-SHIRTS',
        itemLabel = 'Tisort',
        icon  = 'tshirt',
        kind  = 'component', id = 8,
        slot  = 'tshirt',
        price = 1000,
        camera = 'torso',
    },
    {
        key   = 'pants',
        label = 'PANTS',
        itemLabel = 'Pantolon',
        icon  = 'pants',
        kind  = 'component', id = 4,
        slot  = 'pants',
        price = 600,
        camera = 'legs',
    },
    {
        key   = 'shoes',
        label = 'SHOES',
        itemLabel = 'Ayakkabi',
        icon  = 'shoes',
        kind  = 'component', id = 6,
        slot  = 'shoes',
        price = 850,
        camera = 'feet',
    },
    {
        key   = 'glasses',
        label = 'GLASSES',
        itemLabel = 'Gozluk',
        icon  = 'glasses',
        kind  = 'prop',      id = 1,
        slot  = 'glasses',
        price = 1000,
        camera = 'head',
    },
}

--[[
    UNDERWEAR — bir slot bosaltilinca donulecek taban gorunum.
    Kaynak: illenium-appearance Config.InitialPlayerClothes.Male, gercek FiveM
    testinde dogrulandi (2026-08-20). bitirim_inventory'nin
    data/bitirim_clothing.lua -> `underwear` tablosuyla SENKRON TUTULMALIDIR.
]]
Config.Underwear = {
    [3]  = { drawable = 15, texture = 0 },  -- Arms
    [4]  = { drawable = 21, texture = 0 },  -- Legs
    [6]  = { drawable = 34, texture = 0 },  -- Feet (yalin ayak)
    [8]  = { drawable = 15, texture = 0 },  -- Undershirt
    [11] = { drawable = 15, texture = 0 },  -- Top
}

--[[
    KATMAN 4 — son care kol degeri.
    Erkek 135: oyunda olculdu, ELDIVENLI bir parca.
    Kadin -1: HIC OLCULMEDI -> kola dokunulmaz. Tahminle doldurulmaz;
    kadin karakterle olcup buraya gec.
]]
Config.DefaultArms = {
    male   = { drawable = 135, texture = 0 },
    female = { drawable = -1,  texture = 0 },
}

--[[
    Blacklist, katman 1'in (oyunun kendi zorunlu-bilesen verisi) cevabini da
    suzsun mu?

    false (VARSAYILAN, 2026-09-01 kullanici karari) — oyunun parca-bazli
          cevabi kazanir. Olculen gerekce: 111 kapsanmayan ustun 47'sinde oyun
          ZATEN dogru kolu soyluyordu, blacklist reddediyordu. Blacklist ise
          sadece 14..24 arasi 11 uste karsi test edilerek kurulmustu ve o
          testlerde kollar, KENDILERINI ZORUNLU KILMAYAN ustlerle eslesmisti --
          uyumsuz kolun bozuk gorunmesi zaten beklenen sey. Rockstar'in
          parca-bazli verisi, 11 ornekten yapilan genellemeden daha spesifik.
          Kapsam: %79.6 -> ~%88.3.

          GUVENLIK AGI DURUYOR: DB'nin o (ust, kol) ciftine OZEL 'rejected'
          kaydi katman 1'in cevabini yine veto eder (bkz. resolveArms ->
          isRejected). Yani koru korune guven yok; sadece KUYE blacklist
          katman 1'e uygulanmiyor. Blacklist katman 2 ve 4'te calismaya
          devam ediyor.

    true  — blacklist her katmani suzer. Daha muhafazakar ama o 47 ust tek bir
          eldivenli varsayilan kolla (135) giyilir.
]]
Config.BlacklistFiltersGameData = false
