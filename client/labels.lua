--[[
    client/labels.lua — parcalarin GERCEK adlari

    Magazada her sey "Ust Giysi" / "Sapka" yaziyordu. GTA'nin kendi magaza
    verisinde her parcanin bir metin etiketi var (data/labels.lua, kaynak
    shop.meta > textLabel). Bunlar GXT anahtari; oyunda cozuluyor.

    Cozulemeyenler (temel oyun parcalari, eksik ceviri) kategori adina duser --
    yani hicbir tile adsiz kalmaz.
]]

local Labels = {}

local keys = {}
local cache = {}

local ok, data = pcall(lib.load, 'data.labels')
if ok and type(data) == 'table' then
    keys = data
else
    print('^3[bitirim_clothing] data/labels.lua yuklenemedi -- parca adlari kategori adini kullanacak.^7')
end

--[[
    GXT anahtarini coz.

    GetLabelText tanimsiz anahtar icin ya anahtarin kendisini ya 'NULL' doner;
    ikisi de kullanici icin anlamsiz, o yuzden nil donuyoruz ve cagiran taraf
    kategori adina dusuyor.
]]
local function resolve(key)
    if not key then return nil end

    local hit = cache[key]
    if hit ~= nil then
        return hit ~= false and hit or nil
    end

    local okCall, text = pcall(GetLabelText, key)
    if not okCall or type(text) ~= 'string' then
        cache[key] = false
        return nil
    end

    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' or text == 'NULL' or text == key then
        cache[key] = false
        return nil
    end

    cache[key] = text
    return text
end

--- slot + drawable -> parca adi, yoksa nil.
function Labels.get(slot, drawable)
    local m = keys[slot]
    return m and resolve(m[drawable]) or nil
end

--- Katalog girdilerine ad ekle (yerinde degistirir).
function Labels.decorate(slot, list)
    for _, entry in ipairs(list) do
        entry.name = Labels.get(slot, entry.d)
    end
    return list
end

--- Kac etiket gercekten cozulebiliyor -- olcum icin.
function Labels.stats()
    local total, resolved = 0, 0
    for _, m in pairs(keys) do
        for _, key in pairs(m) do
            total = total + 1
            if resolve(key) then resolved = resolved + 1 end
        end
    end
    return resolved, total
end

BitirimClothing.Labels = Labels

RegisterCommand('kiyafetadlar', function()
    local resolved, total = Labels.stats()
    print(('^2[adlar] %d/%d GXT anahtari cozulebiliyor (%%%.1f)^7')
        :format(resolved, total, total > 0 and 100.0 * resolved / total or 0))
    for _, c in ipairs(Config.Categories) do
        local sample = {}
        local m = keys[c.slot] or {}
        for d, key in pairs(m) do
            if #sample < 3 then
                sample[#sample + 1] = ('%d=%s'):format(d, resolve(key) or ('?' .. key))
            end
        end
        print(('   %-10s %s'):format(c.key, table.concat(sample, '  ')))
    end
end, false)
