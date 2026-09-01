--[[
    client/probe.lua — /kiyafetprob  (v3)

    v2 SONUCU: _G taramasi 0 fonksiyon buldu, AMA
    GetShopPedApparelVariantComponentCount calisiyor (top 17 -> count=2).
    Cikarim: FiveM native'leri gercek global DEGIL, __index ile istege bagli
    cozuluyor. pairs(_G) onlari gormuyor; _G['Ad'] goruyor.
    => Listeleyemeyiz, ISIMLE YOKLARIZ.

    v3 iki seyi olcer:

    (1) ADAY ISIMLER — okuyucu native'in gercek adi hangisi?

    (2) ARGUMAN SEKLI — asil hipotez:
        GetNumForcedComponents'a MODEL hash'i veriyoruz (v1 boyle yapti,
        bitirim_inventory de boyle yapiyor) ve 544/544 sifir dondu.
        Ya native model degil, GetHashNameForComponent'ten gelen APPAREL
        COMPONENT HASH'ini bekliyorsa? Bu dogruysa hem bizim 0/544'u hem de
        envanterin kol duzeltmesinin hic calismamasini tek basina aciklar.

    SADECE OKUR.
]]

local Constants = BitirimClothing.Constants
local TOP  = Constants.Component.TOP
local ARMS = Constants.Component.ARMS

--- v1'de gecerli hash + count > 0 dondugu DOGRULANAN ornekler.
local SAMPLES = { 17, 21, 24, 40, 100, 400, 543 }

--- Okuyucu olabilecek isimler. Varlik testi: _G[ad] ~= nil (bu calisiyor).
local CANDIDATES = {
    'GetVariantComponent',
    'GetVariantProp',
    'GetShopPedApparelVariantComponent',
    'GetShopPedApparelVariantComponentAtIndex',
    'GetShopPedApparelVariantPropAtIndex',
    'GetShopPedApparelForcedComponentCount',
    'GetShopPedApparelForcedComponentAtIndex',
    'GetShopPedApparelForcedComponent',
    'GetShopPedComponent',
    'GetShopPedProp',
    'GetShopPedComponentAtIndex',
    'GetForcedComponent',
    'GetNumForcedComponents',
    'GetForcedComponentAtIndex',
    'GetNumForcedPropComponents',
    'GetShopPedQueryComponent',
    'GetShopPedQueryComponentIndex',
    'GetPedComponentVariationData',
}

local function fmtReturns(...)
    local n = select('#', ...)
    if n == 0 then return '(donus yok)' end
    local parts = {}
    for i = 1, math.min(n, 6) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    return ('%d deger: %s'):format(n, table.concat(parts, ', '))
end

--- Bir cagriyi guvenle dene, sonucu metin olarak dondur. Ayrica donus
--- sayisini bildirir (>1 ise ise yarar aday).
local function tryCall(fn, ...)
    local res = table.pack(pcall(fn, ...))
    if not res[1] then
        return ('^1HATA: %s^7'):format(tostring(res[2])), 0
    end
    return fmtReturns(table.unpack(res, 2, res.n)), res.n - 1
end

RegisterCommand('kiyafetprob', function()
    local ok = lib.callback.await('bitirim_clothing:hasDevPermission', false)
    if not ok then
        print('^1[bitirim_clothing] Yetkin yok (ace: bitirim_clothing.dev).^7')
        return
    end

    local ped   = PlayerPedId()
    local model = GetEntityModel(ped)

    print('^2============ NATIVE PROB v3 ============^7')

    -- Ornek hash al
    local sampleDrawable, sampleHash, sampleCount
    for _, d in ipairs(SAMPLES) do
        local okH, h = pcall(GetHashNameForComponent, ped, TOP, d, 0)
        if okH and h and h ~= 0 then
            local okC, c = pcall(GetShopPedApparelVariantComponentCount, h)
            if okC and type(c) == 'number' and c > 0 then
                sampleDrawable, sampleHash, sampleCount = d, h, c
                break
            end
        end
    end

    if not sampleHash then
        print('^1Gecerli hash bulunamadi -- v1 ile celisiyor.^7')
        return
    end
    print(('^2ornek: top %d  hash=%s  count=%d^7'):format(sampleDrawable, tostring(sampleHash), sampleCount))

    ---------------------------------------------------------------------
    -- 1) HIPOTEZ: forced-component native'leri MODEL degil HASH bekliyor
    ---------------------------------------------------------------------
    print('')
    print('^2--- 1) GetNumForcedComponents: model mi, apparel hash mi? ---^7')
    local t
    t = tryCall(GetNumForcedComponents, model)                     print(('  (model)              -> %s'):format(t))
    t = tryCall(GetNumForcedComponents, sampleHash)                print(('  ^3(apparel hash)       -> %s^7'):format(t))
    t = tryCall(GetNumForcedComponents, sampleHash, 0)             print(('  (hash, 0)            -> %s'):format(t))
    t = tryCall(GetNumForcedComponents, sampleHash, TOP, sampleDrawable, 0)
    print(('  (hash, 11, d, 0)     -> %s'):format(t))

    print('')
    print('^2--- GetForcedComponent arguman sekilleri ---^7')
    t = tryCall(GetForcedComponent, sampleHash, 0)                 print(('  ^3(hash, 0)            -> %s^7'):format(t))
    t = tryCall(GetForcedComponent, sampleHash, TOP)               print(('  (hash, 11)           -> %s'):format(t))
    t = tryCall(GetForcedComponent, model, TOP, sampleDrawable, 0) print(('  (model, 11, d, 0)    -> %s'):format(t))

    ---------------------------------------------------------------------
    -- 2) ADAY OKUYUCU ISIMLERI
    ---------------------------------------------------------------------
    print('')
    print('^2--- 2) aday isimler: var mi + (hash, 0) cagrisi ---^7')
    local best, bestN = nil, 1
    for _, name in ipairs(CANDIDATES) do
        local fn = _G[name]
        if fn == nil then
            print(('  ^1%-44s YOK^7'):format(name))
        else
            local text, n = tryCall(fn, sampleHash, 0)
            print(('  ^2%-44s^7 -> %s'):format(name, text))
            if n > bestN then best, bestN = name, n end
        end
    end

    ---------------------------------------------------------------------
    -- 3) En cok deger donduren okuyucuyla butun ornekleri coz
    ---------------------------------------------------------------------
    if not best then
        print('')
        print('^1Hicbir aday birden fazla deger dondurmedi.^7')
        print('^3Yukaridaki tablonun tamamini yapistir.^7')
        return
    end

    print('')
    print(('^2--- 3) "%s" ile ornekler (%d deger donduruyor) ---^7'):format(best, bestN))
    local reader = _G[best]
    local hits = 0
    for _, d in ipairs(SAMPLES) do
        local okH, h = pcall(GetHashNameForComponent, ped, TOP, d, 0)
        if okH and h and h ~= 0 then
            local okC, c = pcall(GetShopPedApparelVariantComponentCount, h)
            if okC and type(c) == 'number' and c > 0 then
                local parts, arms = {}, nil
                for i = 0, c - 1 do
                    local r = table.pack(pcall(reader, h, i))
                    if r[1] then
                        parts[#parts + 1] = '{' .. fmtReturns(table.unpack(r, 2, r.n)) .. '}'
                        -- ARMS(3) hangi konumda cikiyor bilmiyoruz: komsu
                        -- sayiyi aday kol drawable'i say, ham cikti zaten basili.
                        for k = 2, r.n do
                            if r[k] == ARMS and type(r[k - 1]) == 'number' then
                                arms = arms or r[k - 1]
                            end
                        end
                    end
                end
                if arms then hits = hits + 1 end
                print(('  top %-4d %s%s'):format(d, table.concat(parts, ' '),
                    arms and ('  ^2-> KOL=%d^7'):format(arms) or ''))
            end
        end
    end
    print('')
    print(('^2kol cevabi veren ornek: %d/%d^7'):format(hits, #SAMPLES))
    print('^2========================================^7')
end, false)
