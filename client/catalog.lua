--[[
    client/catalog.lua — KATALOG TARAMASI (calisma aninda, oyunun kendi verisi)

    Kiyafet listesi elle YAZILMAZ. Oyunun ped'inde kac drawable/texture varsa
    o taranir. Boylece:
      - sunucu hangi DLC'leri yukluyorsa magazada tam olarak o cikar
      - yeni DLC gelince katalog kendini gunceller
      - sabit liste eskimez

    Sayim fonksiyonlari ped'i DEGISTIRMEZ (sadece sorgu), bu yuzden oyuncunun
    kendi ped'inde guvenle calisir -- gorunumde titreme olmaz.
]]

local Constants = BitirimClothing.Constants
local Catalog = {}

-- cache[gender][categoryKey] = { { d = drawable, t = { texture, ... } }, ... }
local cache = {}

---------------------------------------------------------------------------
-- Tarama
---------------------------------------------------------------------------

--[[
    TABAN DEGERI KATALOGA GIRMEZ.

    Her component'in bir "hicbir sey giyilmemis" drawable'i var
    (Constants.BaseState: ust=15, tisort=15, pantolon=21, ayakkabi=34).
    Bunlar giysi degil, ciplak taban. Rockstar bunlara yer tutucu doku vermis:
    magazada YESIL DAMA TAHTASI olarak goruluyordu (jbib drawable 15).
    Satin alinabilir bir urun de degiller.
]]
local function isBaseState(componentId, drawable)
    local base = Constants.BaseState[componentId]
    return base ~= nil and base.drawable == drawable
end

--[[
    CIKARILAN PARCALAR DA KATALOGA GIRMEZ.

    Iki tur: giyilince hicbir sey gostermeyen bos yer tutucular ve oyun icinde
    gorsel olarak bozuk oldugu icin elle cikarilanlar. Liste ve sebepleri
    data/removed.lua'da.
]]
local removedItems = {}
do
    local ok, data = pcall(lib.load, 'data.removed')
    if ok and type(data) == 'table' then
        removedItems = data
    else
        print('^3[bitirim_clothing] data/removed.lua yuklenemedi -- cikarilan parcalar katalogda kalacak.^7')
    end
end

local function isRemoved(gender, categoryKey, drawable)
    local g = removedItems[gender]
    local c = g and g[categoryKey]
    return c ~= nil and c[drawable] ~= nil
end

local function scanComponent(ped, componentId)
    local out = {}
    local drawableCount = GetNumberOfPedDrawableVariations(ped, componentId)
    if type(drawableCount) ~= 'number' or drawableCount <= 0 then return out end

    for d = 0, drawableCount - 1 do
      if not isBaseState(componentId, d) then
        local textures = {}
        local textureCount = GetNumberOfPedTextureVariations(ped, componentId, d) or 0
        for t = 0, textureCount - 1 do
            -- KATMAN 0: gecersiz kombinasyon kataloga HIC girmez.
            if IsPedComponentVariationValid(ped, componentId, d, t) then
                textures[#textures + 1] = t
            end
        end
        if #textures > 0 then
            out[#out + 1] = { d = d, t = textures }
        end
      end
    end

    return out
end

local function scanProp(ped, propId)
    local out = {}
    local drawableCount = GetNumberOfPedPropDrawableVariations(ped, propId)
    if type(drawableCount) ~= 'number' or drawableCount <= 0 then return out end

    for d = 0, drawableCount - 1 do
        local textures = {}
        local textureCount = GetNumberOfPedPropTextureVariations(ped, propId, d) or 0
        -- Prop'lar icin IsPedComponentVariationValid muadili YOK; texture
        -- sayisi 0 ise o drawable kullanilamaz demektir.
        for t = 0, textureCount - 1 do
            textures[#textures + 1] = t
        end
        if #textures > 0 then
            out[#out + 1] = { d = d, t = textures }
        end
    end

    return out
end

---------------------------------------------------------------------------
-- Genel API
---------------------------------------------------------------------------

--- Bir kategoriyi tara (cache'liyse cache'ten doner).
function Catalog.get(ped, category)
    local gender = Constants.genderKey(ped)
    cache[gender] = cache[gender] or {}

    local hit = cache[gender][category.key]
    if hit then return hit end

    local result
    if category.kind == 'prop' then
        result = scanProp(ped, category.id)
    else
        result = scanComponent(ped, category.id)
    end

    --[[
        GIZLENEN PARCALARI DUS. Bunlar, kol verisi olmayan ve gorsel olarak
        bozuk oldugu ELLE dogrulanan parcalardir (bkz. client/hidden.lua).
        Lazy erisim: Hidden modulu bu dosyadan sonra yuklenmis olabilir.
    ]]
    local Hidden = BitirimClothing.Hidden
    local kept = {}
    for _, entry in ipairs(result) do
        local drop = isRemoved(gender, category.key, entry.d)
                  or (Hidden ~= nil and Hidden.is(gender, category.key, entry.d))
        if not drop then
            kept[#kept + 1] = entry
        end
    end
    result = kept

    --[[
        Parcanin GERCEK adini ekle (GTA'nin magaza verisinden, bkz.
        client/labels.lua). Cozulemeyenler nil kalir ve NUI kategori adina
        duser -- yani hicbir tile adsiz gorunmez.
    ]]
    local Labels = BitirimClothing.Labels
    if Labels then Labels.decorate(category.slot, result) end

    cache[gender][category.key] = result
    return result
end

--- Butun kategorileri tara. Donus: { [categoryKey] = { {d=,t={}}, ... } }
function Catalog.getAll(ped)
    local out = {}
    for _, category in ipairs(Config.Categories) do
        out[category.key] = Catalog.get(ped, category)
    end
    return out
end

--- Kategori basina parca sayisi -- raporlama/olcum icin.
function Catalog.counts(ped)
    local out, totalDrawables, totalTextures = {}, 0, 0
    for _, category in ipairs(Config.Categories) do
        local list = Catalog.get(ped, category)
        local textures = 0
        for _, entry in ipairs(list) do textures = textures + #entry.t end
        out[category.key] = { drawables = #list, textures = textures }
        totalDrawables = totalDrawables + #list
        totalTextures  = totalTextures + textures
    end
    out._total = { drawables = totalDrawables, textures = totalTextures }
    return out
end

--- Cinsiyet degisirse (karakter degisimi) cache'i dusur.
function Catalog.invalidate()
    cache = {}
end

BitirimClothing.Catalog = Catalog
