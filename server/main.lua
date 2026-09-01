--[[
    server/main.lua — SATIN ALMA OTORITESI + uyumluluk kurallarinin dagitimi.

    Guvenlik ilkesi (bitirim_724 ile ayni): client'tan yalnizca "hangi kategori
    + hangi drawable/texture" gelir. Fiyat SERVER'da config'ten okunur;
    client'in yolladigi hicbir tutar dikkate alinmaz.
]]

local Constants = BitirimClothing.Constants

---------------------------------------------------------------------------
-- Uyumluluk kurallari — DB'den bir kez okunur, bellekte tutulur
---------------------------------------------------------------------------

local rulesCache = {}
local rulesLoaded = false

local function loadRules()
    local ok, rows = pcall(MySQL.query.await, [[
        SELECT from_component, from_drawable, from_texture,
               to_component, to_drawable, to_texture,
               status, priority
        FROM bitirim_clothing_compatibility_rules
    ]])

    if not ok or type(rows) ~= 'table' then
        print('^3[bitirim_clothing] Uyumluluk tablosu okunamadi -- katman 2 devre disi.^7')
        print('^3data/compatibility_rules.sql dosyasini iceri aktarmayi unutma.^7')
        rulesCache, rulesLoaded = {}, true
        return 0
    end

    rulesCache = rows
    rulesLoaded = true
    print(('^2[bitirim_clothing] %d uyumluluk kurali yuklendi.^7'):format(#rows))
    return #rows
end

--[[
    DIKKAT: Bu onbellek SADECE resource start'ta doluyor. DB'ye dogrudan SQL
    yazilirsa (or. compatibility_rules.sql geri yuklemesi) bellek OTOMATIK
    senkron OLMAZ -- `refresh` + `restart bitirim_clothing` sart.
]]
lib.callback.register('bitirim_clothing:getRules', function()
    if not rulesLoaded then loadRules() end
    return rulesCache
end)

---------------------------------------------------------------------------
-- Developer komut yetkisi
---------------------------------------------------------------------------

--[[
    `IsPlayerAceAllowed` SADECE server native'idir. Client'ta cagirmak
    "attempt to call a nil value" verir -- bu yuzden yetki burada sorulur.
]]
lib.callback.register('bitirim_clothing:hasDevPermission', function(source)
    return IsPlayerAceAllowed(source, 'bitirim_clothing.dev')
end)

---------------------------------------------------------------------------
-- Satin alma
---------------------------------------------------------------------------

local function categoryByKey(key)
    for _, c in ipairs(Config.Categories) do
        if c.key == key then return c end
    end
end

--- Odemeyi guvenle cek (bitirim_724 deseni).
local function takeMoney(player, account, total, reason)
    local balance = (player.PlayerData.money and player.PlayerData.money[account]) or 0
    if balance < total then return false, 'Yeterli paran yok.' end
    if not player.Functions.RemoveMoney(account, total, reason) then
        return false, 'Odeme alinamadi.'
    end
    return true
end

--[[
    Bir sepet satirini bitirim_inventory'nin bekledigi metadata'ya cevir.

    Format bitirim_inventory/modules/bitirim/equipment_server.lua ->
    resolvePiece'in YENI ve tercih edilen bicimidir:
      item 'apparel' + metadata.wear = { slot, drawable, texture }
    `wear.slot` anahtarlari envanterin data/bitirim_clothing.lua > slots
    tablosuyla BIREBIR ayni olmak zorunda.
]]
local function buildMetadata(category, drawable, texture)
    return {
        wear = {
            slot     = category.slot,
            drawable = drawable,
            texture  = texture,
        },
        label    = category.itemLabel or category.label,
        imageurl = ('nui://bitirim_clothing/web/images/%s_%d.png'):format(category.slot, drawable),
    }
end

lib.callback.register('bitirim_clothing:buy', function(source, cart)
    local src = source

    if type(cart) ~= 'table' or #cart == 0 then
        return { success = false, reason = 'Sepet bos.' }
    end
    if #cart > (Config.MaxCartItems or 12) then
        return { success = false, reason = 'Sepette cok fazla parca var.' }
    end

    -- 1) Her satiri dogrula ve tutari SERVER'da hesapla.
    local lines, total = {}, 0
    for _, entry in ipairs(cart) do
        local category = categoryByKey(entry.category)
        if not category then
            return { success = false, reason = 'Gecersiz kategori.' }
        end

        local drawable = tonumber(entry.drawable)
        local texture  = tonumber(entry.texture) or 0
        if not drawable or drawable < 0 or drawable % 1 ~= 0
           or texture < 0 or texture % 1 ~= 0 then
            return { success = false, reason = 'Gecersiz parca.' }
        end

        lines[#lines + 1] = {
            category = category,
            drawable = drawable,
            texture  = texture,
        }
        total = total + category.price
    end

    -- 2) Oyuncu
    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        return { success = false, reason = 'Oyuncu bulunamadi.' }
    end

    -- 3) Envanterde yer var mi?
    local itemName = Config.ItemName or 'apparel'
    if not exports.ox_inventory:CanCarryItem(src, itemName, #lines) then
        return { success = false, reason = 'Envanterinde yeterli yer yok.' }
    end

    -- 4) Parayi cek
    local account = Config.PaymentAccount or 'cash'
    local ok, reason = takeMoney(player, account, total, 'bitirim_clothing-purchase')
    if not ok then
        return { success = false, reason = reason }
    end

    -- 5) Parcalari ver. Bir tanesi bile eklenemezse TAMAMI iade edilir.
    local given = 0
    for _, line in ipairs(lines) do
        local metadata = buildMetadata(line.category, line.drawable, line.texture)
        local added = exports.ox_inventory:AddItem(src, itemName, 1, metadata)
        if added then
            given = given + 1
        else
            break
        end
    end

    if given < #lines then
        -- Kismi basarisizlik: verilenleri geri al, parayi tam iade et.
        player.Functions.AddMoney(account, total, 'bitirim_clothing-refund')
        print(('^1[bitirim_clothing] src=%d satin alma basarisiz (%d/%d verildi), odeme iade edildi.^7')
            :format(src, given, #lines))
        return { success = false, reason = 'Parcalar verilemedi, odeme iade edildi.' }
    end

    print(('[bitirim_clothing] satin alma src=%d parca=%d tutar=%d'):format(src, #lines, total))
    return { success = true, total = total, count = #lines }
end)

---------------------------------------------------------------------------
-- GIZLENEN PARCALAR
---------------------------------------------------------------------------

--[[
    Kol verisi olmayan ve GORSEL OLARAK bozuk oldugu elle dogrulanan parcalar
    burada tutulur ve katalogdan cikarilir. Karar gorseldir; bu tablo sadece
    kullanicinin verdigi karari kalici kilar.
]]
local function ensureHiddenTable()
    local ok = pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS bitirim_clothing_hidden (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            gender VARCHAR(8) NOT NULL,
            category VARCHAR(32) NOT NULL,
            drawable SMALLINT UNSIGNED NOT NULL,
            reason VARCHAR(191) NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_hidden (gender, category, drawable)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    if not ok then
        print('^3[bitirim_clothing] bitirim_clothing_hidden tablosu olusturulamadi.^7')
    end
    return ok
end

lib.callback.register('bitirim_clothing:getHidden', function()
    local ok, rows = pcall(MySQL.query.await,
        'SELECT gender, category, drawable FROM bitirim_clothing_hidden')
    if not ok or type(rows) ~= 'table' then return {} end
    return rows
end)

lib.callback.register('bitirim_clothing:setHidden', function(source, gender, category, drawable, hide, reason)
    -- Yetki: gizleme katalogu kalici olarak degistirir, ACE sart.
    if not IsPlayerAceAllowed(source, 'bitirim_clothing.dev') then return false end

    if type(gender) ~= 'string' or type(category) ~= 'string' then return false end
    drawable = tonumber(drawable)
    if not drawable or drawable < 0 or drawable % 1 ~= 0 then return false end
    if gender ~= 'male' and gender ~= 'female' then return false end

    local ok
    if hide then
        ok = pcall(MySQL.query.await, [[
            INSERT INTO bitirim_clothing_hidden (gender, category, drawable, reason)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE reason = VALUES(reason)
        ]], { gender, category, drawable, reason })
    else
        ok = pcall(MySQL.query.await, [[
            DELETE FROM bitirim_clothing_hidden
            WHERE gender = ? AND category = ? AND drawable = ?
        ]], { gender, category, drawable })
    end

    if ok then
        print(('[bitirim_clothing] gizleme %s: %s/%s/%d (src=%d)')
            :format(hide and 'eklendi' or 'kaldirildi', gender, category, drawable, source))
    end
    return ok == true
end)

---------------------------------------------------------------------------
-- Baslangic
---------------------------------------------------------------------------

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ensureHiddenTable()
    loadRules()
end)
