--[[
    client/capture.lua — THUMBNAIL TOPLU URETIMI

    Grid'deki her parca icin bir PNG uretir. Kare OYUNCUNUN EKRANINDAN alinir,
    o yuzden is calisirken oyuncu sahneyi degistirmemeli.

    Adlandirma NUI'nin bekledigi sema: web/images/<slot>_<drawable>.png
    (or. jacket_12.png). Envantere yazilan metadata.imageurl de ayni dosyayi
    gosteriyor -- parca magazada ve envanterde AYNI gorseli tasiyor.

    Komutlar:
      /kiyafetcek [kategori] [baslangic]   uretimi baslat
      /kiyafetcek ... yenile               var olanlari da yeniden cek
      /kiyafetcekdur                       durdur
      /kiyafetnokta                        bulundugun yerin koordinatini yaz

    Kategori verilmezse HEPSI sirayla uretilir. `baslangic` yarida kalan isi
    kaldigi yerden surdurmek icin (drawable indeksi).

    SINIR: arka plan magazanin ic mekani. Temiz/duz bir backdrop v2 isi;
    su haliyle parca net gorunuyor ama arka plan sade degil.
]]

local Constants = BitirimClothing.Constants
local Apply     = BitirimClothing.Apply
local Compat    = BitirimClothing.Compat
local Catalog   = BitirimClothing.Catalog
local Preview   = BitirimClothing.Preview

local TOP = Constants.Component.TOP

--[[
    Kare oyun ekranindan geliyor, yani 16:9. 512 -> 512x280 civari.
    NUI tile'i kare oldugu icin CSS `object-fit: cover` yanlardan kirpiyor;
    dikey cozunurluk tam korunuyor.
]]
local THUMB_SIZE = 512

local job = { running = false, cancel = false }

local function categoryByKey(key)
    for _, c in ipairs(Config.Categories) do
        if c.key == key then return c end
    end
end

--- Parcayi ped'e uygula (ust giysi ise kol da cozulur).
local function applyPiece(ped, category, drawable, texture)
    if category.kind == 'prop' then
        return Apply.prop(ped, category.id, drawable, texture)
    end
    if category.id == TOP then
        return Compat.applyTop(ped, drawable, texture)
    end
    return Apply.component(ped, category.id, drawable, texture)
end

--- Ekrani sadelestir: HUD kapali, NUI kapali.
local function cleanScreen(on)
    DisplayRadar(not on)
    if on then
        HideHudAndRadarThisFrame()
    end
end

local function captureCategory(ped, category, startAt, force)
    local list = Catalog.get(ped, category)
    if #list == 0 then
        print(('^3[cek] %s: katalog bos, atlandi^7'):format(category.key))
        return 0, 0
    end

    Preview.setFraming(ped, category.camera)
    Wait(300)

    local written, skipped = 0, 0

    for i, entry in ipairs(list) do
        if job.cancel then break end
        if entry.d >= (startAt or 0) then
            local name = ('%s_%d'):format(category.slot, entry.d)

            local exists = not force and lib.callback.await('bitirim_clothing:thumbExists', false, name)
            if exists then
                skipped = skipped + 1
            else
                local texture = entry.t[1] or 0
                if applyPiece(ped, category, entry.d, texture) then
                    -- Ped'in yeni parcayi cizmesi icin birkac kare bekle.
                    Wait(160)

                    local ok, err = lib.callback.await('bitirim_clothing:captureThumb', false, name, THUMB_SIZE)
                    if ok then
                        written = written + 1
                    else
                        print(('^1[cek] %s basarisiz: %s^7'):format(name, tostring(err)))
                    end
                else
                    print(('^3[cek] %s uygulanamadi, atlandi^7'):format(name))
                end
            end

            if i % 25 == 0 then
                print(('^2[cek] %s  %d/%d  (yazilan %d, atlanan %d)^7')
                    :format(category.key, i, #list, written, skipped))
            end
        end
    end

    return written, skipped
end

RegisterCommand('kiyafetcek', function(_, args)
    if job.running then
        print('^3Zaten calisiyor. Durdurmak icin /kiyafetcekdur^7')
        return
    end

    local okPerm = lib.callback.await('bitirim_clothing:hasDevPermission', false)
    if not okPerm then
        print('^1Yetkin yok (ace: bitirim_clothing.dev).^7')
        return
    end

    -- 'yenile' argumani var olan PNG'leri de yeniden cektirir (cerceveleme
    -- degistiginde eski kareler yeni olanlarla uyumsuz kaliyor).
    local force, rest = false, {}
    for _, a in ipairs(args) do
        if a == 'yenile' then force = true else rest[#rest + 1] = a end
    end

    local only    = rest[1]
    local startAt = tonumber(rest[2]) or 0

    local targets = {}
    if only then
        local c = categoryByKey(only)
        if not c then
            print('^3Kategori bulunamadi. Gecerli: headwear outerwear tshirts pants shoes glasses^7')
            return
        end
        targets[1] = c
    else
        targets = Config.Categories
    end

    job.running, job.cancel = true, false

    CreateThread(function()
        local ped = PlayerPedId()
        local snapshot = Apply.snapshot(ped)

        -- Sabit onizleme noktasina gec (kamera cerceveleri buna dayaniyor).
        -- Config.CaptureCoords tanimliysa cekim ORASI'da yapilir. Arka planin
        -- daha sade oldugu bir nokta bulunursa /kiyafetnokta ile olcup buraya
        -- yazilabilir; tanimsizsa magazanin onizleme noktasi kullanilir.
        local p = Config.CaptureCoords or Config.Store.previewCoords
        local back = GetEntityCoords(ped)
        SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
        SetEntityHeading(ped, p.w)
        Wait(300)
        Preview.start(ped)

        CreateThread(function()
            while job.running do cleanScreen(true) Wait(0) end
            cleanScreen(false)
        end)

        local totalW, totalS = 0, 0
        print(('^2[cek] baslidi -- %d kategori^7'):format(#targets))

        for _, category in ipairs(targets) do
            if job.cancel then break end
            local w, s = captureCategory(ped, category, startAt, force)
            totalW, totalS = totalW + w, totalS + s
            print(('^2[cek] %s bitti: %d yazildi, %d zaten vardi^7'):format(category.key, w, s))
        end

        -- Toparla
        job.running = false
        Preview.stop()
        Apply.restore(ped, snapshot)
        SetEntityCoords(ped, back.x, back.y, back.z, false, false, false, false)

        print(('^2[cek] %s -- toplam %d yazildi, %d zaten vardi^7')
            :format(job.cancel and 'DURDURULDU' or 'TAMAMLANDI', totalW, totalS))
        if totalW > 0 then
            print("^3Yeni dosyalarin NUI icinde gorunmesi icin: refresh + restart bitirim_clothing^7")
        end
    end)
end, false)

--[[
    Bulunulan noktayi Config.CaptureCoords formatinda yazdirir.
    Cekim icin daha sade arka planli bir yer secmek isteyince kullanilir.
]]
RegisterCommand('kiyafetnokta', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    print(('^2Config.CaptureCoords = vec4(%.2f, %.2f, %.2f, %.2f)^7')
        :format(c.x, c.y, c.z, GetEntityHeading(ped)))
end, false)

RegisterCommand('kiyafetcekdur', function()
    if not job.running then
        print('^3Calisan is yok.^7')
        return
    end
    job.cancel = true
    print('^3Durduruluyor...^7')
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        job.cancel, job.running = true, false
    end
end)
