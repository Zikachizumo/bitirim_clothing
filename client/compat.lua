--[[
    client/compat.lua — KOL (component 3) UYUMLULUGU: katmanli savunma.

    Amac: ust giysi giyildiginde omuzda ten tasmasi / seffaf mesh olusturan
    kol esleşmelerini engellemek. Oyuncu kolu HIC secmez; burada belirlenir.

    Katmanlar (ilk cevap veren kazanir):
      1  Oyunun kendi zorunlu-bilesen verisi (GetNumForcedComponents/
         GetForcedComponent) -- BUTUN ust giysileri kapsar
      2  Elle dogrulanmis uyumluluk DB'si (2613 satir, Top 14-24)
      3  Global kol blacklist -- her katmanin ciktisini SUZER
      4  Config.DefaultArms (son care)

    Detay: docs/COMPATIBILITY.md
]]

local Constants = BitirimClothing.Constants
local Compat = {}

local ARMS = Constants.Component.ARMS
local TOP  = Constants.Component.TOP

---------------------------------------------------------------------------
-- KATMAN 3 — blacklist (once tanimlanir, digerleri bunu kullanir)
---------------------------------------------------------------------------

local blacklist = { male = {}, female = {} }   -- [gender][drawable] = true

do
    local raw = BitirimClothing.ArmsBlacklist or { male = {}, female = {} }
    for _, gender in ipairs({ 'male', 'female' }) do
        for _, drawable in ipairs(raw[gender] or {}) do
            blacklist[gender][drawable] = true
        end
    end
end

--- Bu kol drawable'i global olarak yasakli mi?
function Compat.isBlacklisted(gender, drawable)
    return blacklist[gender] ~= nil and blacklist[gender][drawable] == true
end

---------------------------------------------------------------------------
-- KATMAN 2 — DB kural onbellegi (server'dan gelir)
---------------------------------------------------------------------------

--[[
    verified[topDrawable][topTexture][armsDrawable] = priority
    rejected[topDrawable][topTexture][armsDrawable] = true
    topTexture -1 = "texture belirtilmemis" (DB sentinel'i).
]]
local rules = { verified = {}, rejected = {}, loaded = false }

local function bucket(tbl, drawable, texture)
    tbl[drawable] = tbl[drawable] or {}
    tbl[drawable][texture] = tbl[drawable][texture] or {}
    return tbl[drawable][texture]
end

--- Server'dan gelen ham satirlari indeksle.
function Compat.loadRules(rows)
    rules.verified, rules.rejected, rules.loaded = {}, {}, false
    if type(rows) ~= 'table' then return 0 end

    local n = 0
    for _, r in ipairs(rows) do
        -- Sadece Top(11) -> Arms(3) satirlari bizi ilgilendiriyor.
        if tonumber(r.from_component) == TOP and tonumber(r.to_component) == ARMS then
            local fd = tonumber(r.from_drawable)
            local ft = tonumber(r.from_texture) or -1
            local td = tonumber(r.to_drawable)
            if fd and td then
                if r.status == 'verified' then
                    bucket(rules.verified, fd, ft)[td] = tonumber(r.priority) or 0
                elseif r.status == 'rejected' then
                    bucket(rules.rejected, fd, ft)[td] = true
                end
                n = n + 1
            end
        end
    end

    rules.loaded = true
    return n
end

function Compat.rulesLoaded() return rules.loaded end

--[[
    CAKISMA POLITIKASI: REJECTED > VERIFIED.
    Ayni (top, texture, arms) icin hem verified hem rejected varsa parca
    uygulanmaz. DB unique key bunu normalde engeller; yine de savunma var.
]]
local function isRejected(topDrawable, topTexture, armsDrawable)
    for _, tex in ipairs({ topTexture, -1 }) do
        local b = rules.rejected[topDrawable] and rules.rejected[topDrawable][tex]
        if b and b[armsDrawable] then return true end
    end
    return false
end

--- Katman 2: DB'den en dusuk priority'li, reddedilmemis, blacklist disi kol.
local function fromDatabase(gender, topDrawable, topTexture)
    local best, bestPriority

    -- Once tam texture eslesmesi, sonra "texture belirtilmemis" (-1) satirlari.
    for _, tex in ipairs({ topTexture, -1 }) do
        local candidates = rules.verified[topDrawable] and rules.verified[topDrawable][tex]
        if candidates then
            for armsDrawable, priority in pairs(candidates) do
                if not isRejected(topDrawable, topTexture, armsDrawable)
                   and not Compat.isBlacklisted(gender, armsDrawable)
                   and (bestPriority == nil or priority < bestPriority) then
                    best, bestPriority = armsDrawable, priority
                end
            end
        end
        if best then return best end
    end

    return nil
end

---------------------------------------------------------------------------
-- KATMAN 1 — oyunun kendi zorunlu-bilesen verisi
---------------------------------------------------------------------------

--[[
    Oyun, her ust giysi icin hangi kolun zorunlu oldugunu kendi verisinde
    tutuyor. Dogru zincir OLCULEREK bulundu (/kiyafetprob v3, 2026-09-01):

      hash  = GetHashNameForComponent(ped, 11, drawable, texture)
      count = GetNumForcedComponents(hash)          --> or. top 17 icin 2
      GetForcedComponent(hash, i)                    --> nameHash, enumValue, componentType
                                                         componentType == 3 ise enumValue = KOL drawable'i

    KRITIK: GetNumForcedComponents MODEL hash'ini DEGIL, apparel component
    hash'ini bekliyor. Model verilince 0 donduruyor (sessizce, hata vermeden)
    -- 544/544 sifir kapsam bundandi. Olculen kanit:
        (model)        -> 0
        (apparel hash) -> 2
    AYNI HATA bitirim_inventory/modules/bitirim/equipment_client.lua:71'de de
    var; oranin kol duzeltmesi de bu yuzden hic calismamis olmali.

    GetVariantComponent BENZER ama BASKA veridir (componentType 8/9/11 =
    undershirt/yelek/ust) -- kol vermez, karistirma.
]]
local function fromGameData(ped, gender, topDrawable, topTexture)
    if not GetHashNameForComponent or not GetNumForcedComponents or not GetForcedComponent then
        return nil
    end

    -- Hash texture'a da bagli: ayni drawable'in farkli renginin zorunlu kolu
    -- farkli olabilir.
    local okH, hash = pcall(GetHashNameForComponent, ped, TOP, topDrawable, topTexture or 0)
    if not okH or not hash or hash == 0 then return nil end

    local okC, count = pcall(GetNumForcedComponents, hash)
    if not okC or type(count) ~= 'number' or count <= 0 then return nil end

    -- Blacklist katman 1'i de suzsun mu? (Config.BlacklistFiltersGameData)
    local filter = Config.BlacklistFiltersGameData
    if filter == nil then filter = true end

    for i = 0, count - 1 do
        local okF, _, enumValue, componentType = pcall(GetForcedComponent, hash, i)
        if okF and componentType == ARMS and type(enumValue) == 'number' and enumValue >= 0 then
            if not (filter and Compat.isBlacklisted(gender, enumValue)) then
                return enumValue
            end
        end
    end

    return nil
end

---------------------------------------------------------------------------
-- COZUM
---------------------------------------------------------------------------

--[[
    Bir ust giysi icin dogru kolu coz.
    Donus: drawable (number) veya nil, ve kaynak etiketi ('game'/'db'/'default').
    nil donerse KOLA HIC DOKUNULMAZ (uydurma deger uygulanmaz).
]]
function Compat.resolveArms(ped, topDrawable, topTexture)
    local gender = Constants.genderKey(ped)
    topTexture = topTexture or 0

    local fromGame = fromGameData(ped, gender, topDrawable, topTexture)
    if fromGame and not isRejected(topDrawable, topTexture, fromGame) then
        return fromGame, 'game'
    end

    local fromDb = fromDatabase(gender, topDrawable, topTexture)
    if fromDb then return fromDb, 'db' end

    local default = (Config.DefaultArms or {})[gender]
    if default and default.drawable and default.drawable >= 0
       and not Compat.isBlacklisted(gender, default.drawable) then
        return default.drawable, 'default'
    end

    return nil, nil
end

--[[
    Ust giysiyi uygula ve kolu otomatik duzelt.
    Kol cozulemezse ust yine uygulanir, kola dokunulmaz -- kullanicinin
    mevcut kolu uydurma bir degerle ezilmez.
]]
function Compat.applyTop(ped, drawable, texture)
    local Apply = BitirimClothing.Apply
    if not Apply.component(ped, TOP, drawable, texture) then
        return false, 'gecersiz ust giysi'
    end

    local arms, source = Compat.resolveArms(ped, drawable, texture)
    if arms then
        Apply.component(ped, ARMS, arms, 0)
    end

    return true, source
end

BitirimClothing.Compat = Compat
