--[[
    client/coverage.lua — OLCUM KOMUTLARI (developer araci)

    /kiyafetkapsam  Her ust giysinin kolunun HANGI KATMANDAN cozuldugunu sayar.
                    giysiyi kapsadigini olcer. Bu sayi, elle gorsel taramaya
                    devam etmeye deger mi sorusunu cevaplar.
    /kiyafetsay     Katalog taramasinin kategori basina kac parca buldugunu yazar.

    Ikisi de SADECE OKUR -- ped'e hicbir sey uygulanmaz, DB'ye hicbir sey yazilmaz.

    YETKI: `IsPlayerAceAllowed` client'ta YOK (sadece server native'i). Bu yuzden
    yetki her komutta server'a sorulur -- client'ta cagirmak "attempt to call a
    nil value" hatasi verir.
]]

local Constants = BitirimClothing.Constants
local Catalog   = BitirimClothing.Catalog
local Compat    = BitirimClothing.Compat

local TOP  = Constants.Component.TOP

local function allowed()
    local ok = lib.callback.await('bitirim_clothing:hasDevPermission', false)
    if not ok then
        print('^1[bitirim_clothing] Bu komut icin yetkin yok (ace: bitirim_clothing.dev).^7')
    end
    return ok
end

---------------------------------------------------------------------------
-- /kiyafetkapsam
---------------------------------------------------------------------------

RegisterCommand('kiyafetkapsam', function()
    if not allowed() then return end

    local ped    = PlayerPedId()
    local gender = Constants.genderKey(ped)

    local topCount = GetNumberOfPedDrawableVariations(ped, TOP) or 0
    if topCount <= 0 then
        print('^1[bitirim_clothing] Ust giysi (component 11) taranamadi.^7')
        return
    end

    --[[
        Katman mantigi BURADA TEKRARLANMAZ -- dogrudan Compat.resolveArms
        cagrilir ve donen kaynak etiketine gore sayilir. Boylece olcum ile
        magazanin gercek davranisi asla ayrisamaz.
    ]]
    local n = { game = 0, db = 0, default = 0, none = 0 }
    local gaps = {}

    for d = 0, topCount - 1 do
        local _, source = Compat.resolveArms(ped, d, 0)
        local key = source or 'none'
        n[key] = (n[key] or 0) + 1
        if key == 'default' or key == 'none' then
            if #gaps < 40 then gaps[#gaps + 1] = d end
        end
    end

    local pct = function(v) return topCount > 0 and (v / topCount * 100.0) or 0.0 end

    print('^2================ KIYAFET KAPSAM OLCUMU ================^7')
    print(('cinsiyet            : %s'):format(gender))
    print(('taranan ust giysi   : %d'):format(topCount))
    print(('^2katman 1 (oyun)     : %d  (%%%.1f)^7'):format(n.game, pct(n.game)))
    print(('^3katman 2 (DB)       : %d  (%%%.1f)^7'):format(n.db, pct(n.db)))
    print(('^1katman 4 (varsayilan): %d  (%%%.1f)^7'):format(n.default, pct(n.default)))
    print(('^1kola hic dokunulmaz : %d  (%%%.1f)^7'):format(n.none, pct(n.none)))
    print(('gercek kapsam (1+2) : %%%.1f'):format(pct(n.game + n.db)))
    if #gaps > 0 then
        print(('kapsanmayan ilk %d ust: %s'):format(#gaps, table.concat(gaps, ', ')))
    end
    print('^2======================================================^7')
end, false)

---------------------------------------------------------------------------
-- /kiyafetsay
---------------------------------------------------------------------------

RegisterCommand('kiyafetsay', function()
    if not allowed() then return end

    local ped = PlayerPedId()
    local counts = Catalog.counts(ped)

    print('^2================ KATALOG SAYIMI ================^7')
    print(('cinsiyet: %s'):format(Constants.genderKey(ped)))
    for _, category in ipairs(Config.Categories) do
        local c = counts[category.key]
        print(('%-11s %5d parca  (%d renk varyanti)'):format(category.label, c.drawables, c.textures))
    end
    print(('%-11s %5d parca  (%d renk varyanti)'):format('TOPLAM', counts._total.drawables, counts._total.textures))
    print('^2===============================================^7')
end, false)
