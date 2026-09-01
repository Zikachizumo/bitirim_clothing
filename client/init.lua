--[[
    client/init.lua — veri yukleme. compat.lua'DAN ONCE calismali.

    fxmanifest'teki client_scripts sirasi onemli:
      constants -> init (blacklist) -> apply -> compat -> catalog -> preview
      -> shop -> coverage
    compat.lua, yuklenirken BitirimClothing.ArmsBlacklist'i okuyor; burada
    doldurulmazsa blacklist bos kalir ve yasakli kollar suzulmez.
]]

BitirimClothing = BitirimClothing or {}

-- Global kol blacklist'i (64 erkek drawable, canli test edilmis).
local ok, data = pcall(lib.load, 'data.arms_blacklist')
if ok and type(data) == 'table' then
    BitirimClothing.ArmsBlacklist = data
else
    BitirimClothing.ArmsBlacklist = { male = {}, female = {} }
    print('^1[bitirim_clothing] data/arms_blacklist.lua yuklenemedi -- katman 3 devre disi.^7')
end

--[[
    Uyumluluk kurallarini server'dan cek (katman 2).
    Basarisiz olursa magaza CALISMAYA DEVAM EDER; sadece katman 2 devre disi
    kalir ve kol secimi katman 1 (oyun verisi) + katman 4 (varsayilan) ile
    yapilir. Sessizce yanlis calismaktansa eksik calisir.
]]
CreateThread(function()
    Wait(1000)   -- server'in loadRules'u bitirmesine pay birak

    local rows = lib.callback.await('bitirim_clothing:getRules', false)
    if type(rows) ~= 'table' then
        print('^3[bitirim_clothing] Uyumluluk kurallari alinamadi -- katman 2 devre disi.^7')
        return
    end

    local indexed = BitirimClothing.Compat.loadRules(rows)
    print(('^2[bitirim_clothing] %d uyumluluk kurali indekslendi (Top->Arms).^7'):format(indexed))
end)

--[[
    Gizlenen parcalar (katalogdan cikarilacaklar). Basarisiz olursa magaza
    calismaya devam eder, sadece hicbir parca gizlenmez.
]]
CreateThread(function()
    Wait(1200)
    local rows = lib.callback.await('bitirim_clothing:getHidden', false)
    if type(rows) ~= 'table' then
        print('^3[bitirim_clothing] Gizli parca listesi alinamadi.^7')
        return
    end
    local n = BitirimClothing.Hidden.load(rows)
    if n > 0 then
        print(('^2[bitirim_clothing] %d gizli parca yuklendi.^7'):format(n))
        BitirimClothing.Catalog.invalidate()
    end
end)
