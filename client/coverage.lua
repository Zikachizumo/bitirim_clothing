--[[
    client/coverage.lua — OLCUM KOMUTLARI (developer araci)

    /kiyafetkapsam  Katman 1'in (oyunun kendi zorunlu-bilesen verisi) kac ust
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
local ARMS = Constants.Component.ARMS

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
    local model  = GetEntityModel(ped)
    local gender = Constants.genderKey(ped)

    if not GetNumForcedComponents or not GetForcedComponent then
        print('^1[bitirim_clothing] GetNumForcedComponents/GetForcedComponent bu FiveM surumunde YOK.^7')
        print('^1Katman 1 kullanilamaz -- katman 2 (DB) ve 4 (varsayilan) ile sinirlisin.^7')
        return
    end

    local topCount = GetNumberOfPedDrawableVariations(ped, TOP) or 0
    if topCount <= 0 then
        print('^1[bitirim_clothing] Ust giysi (component 11) taranamadi.^7')
        return
    end

    local withGameData, blacklistedAnswer, viaDb, uncovered = 0, 0, 0, 0
    local gaps = {}

    for d = 0, topCount - 1 do
        local rawAnswer, cleanAnswer = nil, nil

        local ok, count = pcall(GetNumForcedComponents, model, TOP, d, 0)
        if ok and type(count) == 'number' and count > 0 then
            for i = 0, count - 1 do
                local ok2, _, enumValue, componentType = pcall(GetForcedComponent, model, TOP, d, i)
                if ok2 and componentType == ARMS and type(enumValue) == 'number' and enumValue >= 0 then
                    rawAnswer = enumValue
                    if not Compat.isBlacklisted(gender, enumValue) then
                        cleanAnswer = enumValue
                        break
                    end
                end
            end
        end

        if cleanAnswer then
            withGameData = withGameData + 1
        else
            if rawAnswer then blacklistedAnswer = blacklistedAnswer + 1 end
            -- Oyun cevap vermedi (veya cevabi blacklist'te): DB'ye bakiliyor.
            local arms, source = Compat.resolveArms(ped, d, 0)
            if arms and source == 'db' then
                viaDb = viaDb + 1
            else
                uncovered = uncovered + 1
                if #gaps < 40 then gaps[#gaps + 1] = d end
            end
        end
    end

    local pct = function(n) return topCount > 0 and (n / topCount * 100.0) or 0.0 end

    print('^2================ KIYAFET KAPSAM OLCUMU ================^7')
    print(('cinsiyet            : %s'):format(gender))
    print(('taranan ust giysi   : %d'):format(topCount))
    print(('^2katman 1 (oyun)     : %d  (%%%.1f)^7'):format(withGameData, pct(withGameData)))
    print(('   -> cevap blacklistte: %d'):format(blacklistedAnswer))
    print(('^3katman 2 (DB)       : %d  (%%%.1f)^7'):format(viaDb, pct(viaDb)))
    print(('^1kapsanmayan         : %d  (%%%.1f)^7'):format(uncovered, pct(uncovered)))
    print(('toplam kapsam       : %%%.1f'):format(pct(withGameData + viaDb)))
    if #gaps > 0 then
        print(('kapsanmayan ilk %d ust: %s'):format(#gaps, table.concat(gaps, ', ')))
    end
    print('^2======================================================^7')
    print('Not: "kapsanmayan" olanlar Config.DefaultArms ile giyilir.')
    print('Bu sayi dusukse elle tarama GEREKSIZ; yuksekse sadece bu listedekiler taranir.')
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
