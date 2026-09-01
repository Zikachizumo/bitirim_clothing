--[[
    client/probe.lua — /kiyafetprob

    NEDEN VAR: /kiyafetkapsam olcumu katman 1'in 544 ust giysinin HICBIRINDE
    cevap vermedigini gosterdi (0/544, 2026-09-01). Yani
    GetNumForcedComponents/GetForcedComponent bu sunucuda (FiveM b3788,
    GTA V Enhanced) freemode ped'ler icin veri dondurmuyor.

    Bu komut, "hangi native zinciri gercekten veri veriyor?" sorusunu
    OLCEREK cevaplar -- tahminle degil. Her aday zincir:
      1) native GERCEKTEN var mi (global nil mi degil mi)
      2) cagrilinca patliyor mu (pcall)
      3) sifirdan buyuk bir sonuc donuyor mu
    ucu de ayri ayri raporlanir.

    SADECE OKUR: ped'e hicbir sey uygulanmaz, DB'ye hicbir sey yazilmaz.
]]

local Constants = BitirimClothing.Constants
local TOP  = Constants.Component.TOP
local ARMS = Constants.Component.ARMS

--- Test edilecek ust giysiler: aralik boyunca yayilmis ornekler + DB'de
--- VERIFIED kaydi oldugunu BILDIGIMIZ 14..24 araligindan birkaci
--- (bunlar kontrol grubu: dogru zincir bunlarda kesin cevap vermeli).
local SAMPLES = { 0, 1, 5, 14, 17, 21, 24, 40, 100, 250, 400, 543 }

local function nativeExists(name)
    return _G[name] ~= nil
end

local function reportNatives()
    print('^2--- native varlik kontrolu ---^7')
    local names = {
        'GetNumForcedComponents',
        'GetForcedComponent',
        'GetHashNameForComponent',
        'GetShopPedApparelVariantComponentCount',
        'GetShopPedApparelVariantComponentAtIndex',
        'GetShopPedApparelVariantPropCount',
        'GetShopPedApparelVariantPropAtIndex',
        'GetShopPedComponent',
        'GetNumForcedComponentsForPedComponent',
        'SetPedPreloadVariationData',
    }
    for _, n in ipairs(names) do
        print(('  %-45s %s'):format(n, nativeExists(n) and '^2VAR^7' or '^1YOK^7'))
    end
end

---------------------------------------------------------------------------
-- Zincir A — mevcut yaklasim (GetNumForcedComponents), p3 varyasyonlariyla
---------------------------------------------------------------------------

local function chainA(model, drawable)
    if not GetNumForcedComponents then return 'native yok' end
    local out = {}
    for p3 = 0, 3 do
        local ok, count = pcall(GetNumForcedComponents, model, TOP, drawable, p3)
        if not ok then
            out[#out + 1] = ('p3=%d:HATA'):format(p3)
        else
            out[#out + 1] = ('p3=%d:%s'):format(p3, tostring(count))
        end
    end
    return table.concat(out, '  ')
end

---------------------------------------------------------------------------
-- Zincir B — shop ped apparel (GetHashNameForComponent -> variant component)
---------------------------------------------------------------------------

local function chainB(ped, drawable, texture)
    if not GetHashNameForComponent then return 'GetHashNameForComponent yok', nil end
    if not GetShopPedApparelVariantComponentCount then return 'VariantComponentCount yok', nil end

    local okH, hash = pcall(GetHashNameForComponent, ped, TOP, drawable, texture or 0)
    if not okH then return 'GetHashNameForComponent HATA', nil end
    if not hash or hash == 0 then return ('hash=%s (bos)'):format(tostring(hash)), nil end

    local okC, count = pcall(GetShopPedApparelVariantComponentCount, hash)
    if not okC then return ('hash=%s  Count HATA'):format(tostring(hash)), nil end
    if type(count) ~= 'number' or count <= 0 then
        return ('hash=%s  count=%s'):format(tostring(hash), tostring(count)), nil
    end

    -- Kol (componentType == 3) cevabi var mi?
    local armsFound
    local detail = {}
    if GetShopPedApparelVariantComponentAtIndex then
        for i = 0, count - 1 do
            local okI, nameHash, enumValue, componentType =
                pcall(GetShopPedApparelVariantComponentAtIndex, hash, i)
            if okI then
                detail[#detail + 1] = ('[%s/%s]'):format(tostring(componentType), tostring(enumValue))
                if componentType == ARMS and type(enumValue) == 'number' and enumValue >= 0 then
                    armsFound = armsFound or enumValue
                end
            else
                detail[#detail + 1] = '[HATA]'
            end
        end
    end

    return ('hash=%s  count=%d  %s'):format(tostring(hash), count, table.concat(detail, ' ')), armsFound
end

---------------------------------------------------------------------------
-- Komut
---------------------------------------------------------------------------

RegisterCommand('kiyafetprob', function()
    local ok = lib.callback.await('bitirim_clothing:hasDevPermission', false)
    if not ok then
        print('^1[bitirim_clothing] Yetkin yok (ace: bitirim_clothing.dev).^7')
        return
    end

    local ped   = PlayerPedId()
    local model = GetEntityModel(ped)

    print('^2================ NATIVE PROB ================^7')
    print(('cinsiyet: %s   model: %s'):format(Constants.genderKey(ped), tostring(model)))
    reportNatives()

    print('')
    print('^2--- Zincir A: GetNumForcedComponents(model, 11, drawable, p3) ---^7')
    for _, d in ipairs(SAMPLES) do
        print(('  top %-4d %s'):format(d, chainA(model, d)))
    end

    print('')
    print('^2--- Zincir B: GetHashNameForComponent -> ShopPedApparelVariantComponent ---^7')
    local bHits = 0
    for _, d in ipairs(SAMPLES) do
        local line, arms = chainB(ped, d, 0)
        if arms then bHits = bHits + 1 end
        print(('  top %-4d %s%s'):format(d, line, arms and ('  ^2-> KOL=%d^7'):format(arms) or ''))
    end

    print('')
    print(('^2Zincir B kol cevabi veren ornek: %d/%d^7'):format(bHits, #SAMPLES))
    print('^3Not: 14..24 arasindakiler kontrol grubu -- DB de o araligi biliyor.^7')
    print('^2=============================================^7')
end, false)
