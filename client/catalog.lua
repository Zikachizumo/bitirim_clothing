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

local function scanComponent(ped, componentId)
    local out = {}
    local drawableCount = GetNumberOfPedDrawableVariations(ped, componentId)
    if type(drawableCount) ~= 'number' or drawableCount <= 0 then return out end

    for d = 0, drawableCount - 1 do
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
