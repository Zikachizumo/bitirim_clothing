--[[
    shared/constants.lua — GTA component/prop sabitleri ve global namespace.
    Hem client hem server'da yuklenir (shared_scripts).
]]

BitirimClothing = BitirimClothing or {}

local Constants = {}

--- Component (SetPedComponentVariation) id'leri.
Constants.Component = {
    FACE       = 0,
    MASK       = 1,
    HAIR       = 2,
    ARMS       = 3,   -- kol/eldiven -- OYUNCUYA HIC GOSTERILMEZ, otomatik secilir
    LEGS       = 4,
    BAGS       = 5,
    FEET       = 6,
    NECK       = 7,
    UNDERSHIRT = 8,
    ARMOUR     = 9,
    DECALS     = 10,
    TOP        = 11,
}

--- Prop (SetPedPropIndex) id'leri.
Constants.Prop = {
    HAT      = 0,
    GLASSES  = 1,
    EARS     = 2,
    WATCH    = 6,
    BRACELET = 7,
}

--[[
    UYGULAMA SIRASI — ic katmanlar once, TOP en son.
    Sebep: TOP uygulandiginda oyunun zorunlu-bilesen verisi ARMS'i
    etkileyebiliyor; TOP'u en sona koymak son sozu ona birakir.
]]
Constants.ComponentApplyOrder = { 8, 9, 4, 6, 3, 11 }

--[[
    YENI KARAKTER TABAN (underwear) DEGERLERI.
    Kaynak: illenium-appearance `Config.InitialPlayerClothes.Male`, gercek
    FiveM testinde dogrulandi (2026-08-20). UYDURULMADI.
    Kadin icin ayri dogrulanmis set YOK -- illenium'da erkek=kadin ayni
    tanimlanmis; degistirmeden once oyunda olc.
]]
Constants.BaseState = {
    [3]  = { drawable = 15, texture = 0 },  -- Arms
    [4]  = { drawable = 21, texture = 0 },  -- Legs
    [6]  = { drawable = 34, texture = 0 },  -- Feet (yalin ayak)
    [8]  = { drawable = 15, texture = 0 },  -- Undershirt
    [11] = { drawable = 15, texture = 0 },  -- Top
}

--[[
    Model adlari STRING olarak tutuluyor. FiveM'in backtick hash sozdizimi
    (`mp_m_freemode_01`) standart Lua DEGIL -- sozdizimi denetleyicisinden
    gecmiyor. Hash calisma aninda GetHashKey ile alinir, sonuc ayni.
]]
Constants.MODEL_MALE   = 'mp_m_freemode_01'
Constants.MODEL_FEMALE = 'mp_f_freemode_01'

--- Ped kadin freemode modeli mi?
function Constants.isFemale(ped)
    return GetEntityModel(ped) == GetHashKey(Constants.MODEL_FEMALE)
end

--- Cinsiyet anahtari ('male' / 'female') -- katalog ve blacklist bu anahtarla ayrilir.
function Constants.genderKey(ped)
    return Constants.isFemale(ped) and 'female' or 'male'
end

BitirimClothing.Constants = Constants
