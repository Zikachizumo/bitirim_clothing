--[[
    client/preview.lua — 3D onizleme kamerasi.

    Kategoriye gore cerceveleme: sapka/gozluk kafa yakin plan, ust giysi govde,
    pantolon bacak, ayakkabi ayak.

    ---------------------------------------------------------------------------
    OLCUM (2026-09-01) — asagidaki degerler artik TAHMIN DEGIL
    ---------------------------------------------------------------------------
    Uretilen bir thumbnail (hat_7.png, 256x140) piksel piksel olculdu:

      * Kafa (bere dahil) kare icinde y=52..86 arasindaydi -> kare
        yuksekliginin %24.3'u, dikey merkezi %49.3.

    Iki sonuc cikti:

    1) `z = 0.68` kafayi TAM ORTALIYOR. Yani `GetEntityCoords(ped)` bu ped icin
       ayak degil, ~lecen/pelvis hizasini donduruyor (kafa merkezi taban+0.68).
       Eski torso/legs/feet degerleri (0.45 / 0.15 / 0.02) "taban = ayak"
       varsayimiyla yazilmisti; o varsayim YANLIS. `feet = taban+0.02` aslinda
       kalca hizasi demek -- ayakkabi kareye hic girmiyordu. Asagidaki degerler
       olculen pelvis ankoruna gore yeniden turetildi.

    2) Kafa karenin sadece %24'unu dolduruyordu, hedef ~%55. Bu 2.26x yakinlasma
       demek. Mesafeyi kisaltmak yerine FOV daraltiliyor (bkz. `zoom`): 0.38 m
       mesafede burun buyur, perspektif bozulur; dar FOV portre gibi duz durur.

    `zoom` ve head degerleri olculdu; torso/legs/feet zoom'lari ayni olcegin
    turevi, yani YAKLASIK. `/kiyafetkamera` ile canli ayarlanip buraya gecmeli.
]]

local Preview = {}

local cam
local baseFov                      -- kameranin KENDI varsayilani, calisirken okunur
local currentFraming = 'torso'
local heading = 0.0

--[[
    framing = {
      z     = ped ankorundan (pelvis) yukseklik (m) -- kameranin baktigi nokta
      dist  = mesafe (m)
      pitch = kamera egimi (derece, + = yukaridan asagi bakar)
      zoom  = FOV daraltma carpani (1 = oyunun varsayilani, 2 = iki kat yakin)
    }
]]
Preview.Framing = {
    head  = { z =  0.68, dist = 0.85, pitch =  0.0, zoom = 2.25 },
    torso = { z =  0.30, dist = 1.60, pitch =  0.0, zoom = 1.80 },
    legs  = { z = -0.50, dist = 1.55, pitch =  0.0, zoom = 1.55 },
    feet  = { z = -0.85, dist = 1.00, pitch =  8.0, zoom = 2.40 },
}

local function pedAnchor(ped)
    return GetEntityCoords(ped)
end

--- zoom carpanini FOV'a cevir. baseFov calisma aninda OLCULUR, varsayilmaz.
local function applyZoom(zoom)
    if not cam or not baseFov or baseFov <= 1.0 then return end
    zoom = zoom or 1.0
    if zoom <= 0 then zoom = 1.0 end

    local halfTan = math.tan(math.rad(baseFov * 0.5)) / zoom
    SetCamFov(cam, math.deg(math.atan(halfTan)) * 2.0)
end

--- Kamerayi mevcut cerceveleme + heading'e gore konumlandir.
local function place(ped)
    if not cam then return end

    local f = Preview.Framing[currentFraming] or Preview.Framing.torso
    local base = pedAnchor(ped)
    local rad = math.rad(heading)

    local target = vec3(base.x, base.y, base.z + f.z)

    -- pitch: kamerayi hedefin uzerine kaldir, bakis noktasi sabit kalsin.
    local rise = math.tan(math.rad(f.pitch or 0.0)) * f.dist

    SetCamCoord(cam,
        base.x + math.sin(rad) * f.dist,
        base.y - math.cos(rad) * f.dist,
        base.z + f.z + rise)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    applyZoom(f.zoom)
end

--- Onizlemeyi baslat. Oyuncunun heading'i ankor alinir.
function Preview.start(ped)
    if cam then Preview.stop() end

    heading = GetEntityHeading(ped) + 180.0
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    -- Varsayilan FOV'u SABIT KABUL ETMIYORUZ, kameradan okuyoruz.
    local ok, fov = pcall(GetCamFov, cam)
    baseFov = (ok and type(fov) == 'number' and fov > 1.0) and fov or nil

    place(ped)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 400, true, true)
end

function Preview.stop()
    if not cam then return end
    RenderScriptCams(false, true, 400, true, true)
    DestroyCam(cam, true)
    cam, baseFov = nil, nil
end

--- Kategoriye gore cerceveyi degistir.
function Preview.setFraming(ped, framing)
    if not Preview.Framing[framing] then return end
    currentFraming = framing
    place(ped)
end

--- Karakteri dondur (fare surukleme NUI'den gelir).
function Preview.rotate(ped, delta)
    heading = (heading + delta) % 360.0
    place(ped)
end

function Preview.isActive() return cam ~= nil end

---------------------------------------------------------------------------
-- Ayar komutu — cerceveleme degerlerini oyunda olcmek icin
---------------------------------------------------------------------------

local function dumpFraming()
    print('^3Mevcut degerler:^7')
    for name, f in pairs(Preview.Framing) do
        print(('  %-6s z=%+.2f dist=%.2f pitch=%.1f zoom=%.2f')
            :format(name, f.z, f.dist, f.pitch, f.zoom or 1.0))
    end
end

RegisterCommand('kiyafetkamera', function(_, args)
    -- Cekim surerken kamerayi kurcalamak butun kareleri bozuyor (yasandi:
    -- 1200+ kare oyun kamerasiyla cekildi). Is bitene kadar reddet.
    local capture = BitirimClothing.Capture
    if capture and capture.isRunning() then
        print('^1Thumbnail cekimi suruyor -- kamera simdi degistirilemez.^7')
        print('^3Once /kiyafetcekdur ile durdur.^7')
        return
    end

    local framing = args[1]

    -- Magaza disinda da ayar yapabilmek icin kamerayi tek basina ac/kapa.
    if framing == 'kapat' then
        Preview.stop()
        print('^2Onizleme kamerasi kapatildi.^7')
        return
    end

    if not Preview.Framing[framing] then
        print('^3Kullanim: /kiyafetkamera <head|torso|legs|feet> [z] [mesafe] [pitch] [zoom]^7')
        print('^3          /kiyafetkamera kapat^7')
        dumpFraming()
        return
    end

    local z, dist, pitch, zoom =
        tonumber(args[2]), tonumber(args[3]), tonumber(args[4]), tonumber(args[5])

    if z then Preview.Framing[framing].z = z end
    if dist then Preview.Framing[framing].dist = dist end
    if pitch then Preview.Framing[framing].pitch = pitch end
    if zoom then Preview.Framing[framing].zoom = zoom end

    local ped = PlayerPedId()
    if not Preview.isActive() then Preview.start(ped) end
    Preview.setFraming(ped, framing)

    local f = Preview.Framing[framing]
    print(('^2%s -> z=%+.2f dist=%.2f pitch=%.1f zoom=%.2f^7')
        :format(framing, f.z, f.dist, f.pitch, f.zoom or 1.0))
    print('^2Begendigin degerleri bana soyle, client/preview.lua > Preview.Framing icine gecireyim.^7')
    print('^3Bitince: /kiyafetkamera kapat^7')
end, false)

BitirimClothing.Preview = Preview
