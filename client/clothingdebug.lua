--[[
    client/clothingdebug.lua  --  /kiyafethata  (GECICI TESHIS)

    Talimat madde 16 + 18: bir component icin "ben set ettim" degil "oyunda
    GERCEKTEN ne oldu" read-back'i. Collection native'leriyle okur, boylece
    custom addon (collection) vs vanilla (global) ayrimi da gorunur.

    Kullanim:
      /kiyafethata            -> component 11 (ust giysi) durumu
      /kiyafethata 3          -> component 3 (kol/uppr)
      /kiyafethata 11 bcc_m   -> ayrica bcc_m collection'inin component 11'de
                                 kac drawable/texture'i var, VAR MI onu yazar

    Sadece OKUR. Isi bitince bu dosyayi ve fxmanifest'teki satirini sil.
]]

local function line(...) print(('[KIYAFETHATA] ' .. ('%s '):rep(select('#', ...))):format(...)) end

RegisterCommand('kiyafethata', function(_, args)
    local ped = PlayerPedId()
    local comp = tonumber(args[1]) or 11
    local askCollection = args[2]  -- ornek: bcc_m

    line('==== component', comp, '====')

    -- Su an ne giyili -- once GLOBAL, sonra COLLECTION read-back.
    local gDraw = GetPedDrawableVariation(ped, comp)
    local gTex  = GetPedTextureVariation(ped, comp)
    line('global drawable =', gDraw)
    line('global texture  =', gTex)
    line('global drawable count =', GetNumberOfPedDrawableVariations(ped, comp))
    line('global texture  count =', GetNumberOfPedTextureVariations(ped, comp, gDraw))

    -- Collection read-back: seçili varyant hangi collection'in local kacinci'si?
    if GetPedDrawableVariationCollectionName then
        local colName  = GetPedDrawableVariationCollectionName(ped, comp)
        local colLocal = GetPedDrawableVariationCollectionLocalIndex(ped, comp)
        line('selected collection      =', (colName ~= nil and colName ~= '') and colName or '(bos/vanilla)')
        line('selected collection local=', colLocal)
    else
        line('collection native YOK (bu artifact surumunde)')
    end

    -- Kayitli tum collection'lar ve component icin drawable sayilari.
    if GetPedCollectionsCount then
        local n = GetPedCollectionsCount(ped)
        line('kayitli collection sayisi =', n)
        for i = 0, n - 1 do
            local name = GetPedCollectionName(ped, i)
            local cnt  = GetNumberOfPedCollectionDrawableVariations(ped, comp, name)
            line(('  collection[%d] = %-24s comp %d drawable = %d'):format(i, name, comp, cnt))
        end
    else
        line('GetPedCollectionsCount native YOK')
    end

    -- Kullanici belirli bir collection sordu mu?
    if askCollection and GetNumberOfPedCollectionDrawableVariations then
        local d = GetNumberOfPedCollectionDrawableVariations(ped, comp, askCollection)
        line(('SORULAN collection %q: comp %d drawable = %d'):format(askCollection, comp, d))
        if d > 0 then
            local t = GetNumberOfPedCollectionTextureVariations(ped, comp, askCollection, 0)
            line(('  local drawable 0 -> texture = %d'):format(t))
        else
            line('  -> bu collection oyunda KAYITLI DEGIL (0 drawable)')
        end
    end
end, false)
