--[[
    client/preview.lua — 3D onizleme kamerasi.

    Kategoriye gore cerceveleme (referans gorseller): sapka/gozluk kafa yakin
    plan, ust giysi govde, pantolon bacak, ayakkabi ayak.

    ONEMLI: Asagidaki yukseklik/mesafe degerleri BASLANGIC DEGERLERIDIR,
    oyunda olculmedi. `/kiyafetkamera` komutuyla canli ayarlanip son degerler
    config'e gecirilmelidir. Tahmini deger olarak isaretli kalmalari bilincli --
    "olculmus" gibi sunulmuyorlar.
]]

local Preview = {}

local cam
local currentFraming = 'torso'
local heading = 0.0

--[[
    framing = { z = ped tabanindan yukseklik (m), dist = mesafe (m),
                pitch = kamera egimi (derece) }
]]
Preview.Framing = {
    head  = { z = 0.68, dist = 0.85, pitch =  -2.0 },
    torso = { z = 0.45, dist = 1.60, pitch =  -4.0 },
    legs  = { z = 0.15, dist = 1.55, pitch =   2.0 },
    feet  = { z = 0.02, dist = 1.00, pitch =  12.0 },
}

local function pedAnchor(ped)
    local base = GetEntityCoords(ped)
    return base
end

--- Kamerayi mevcut cerceveleme + heading'e gore konumlandir.
local function place(ped)
    if not cam then return end

    local f = Preview.Framing[currentFraming] or Preview.Framing.torso
    local base = pedAnchor(ped)
    local rad = math.rad(heading)

    local target = vec3(base.x, base.y, base.z + f.z)
    local camPos = vec3(
        base.x + math.sin(rad) * f.dist,
        base.y - math.cos(rad) * f.dist,
        base.z + f.z
    )

    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, target.x, target.y, target.z)
end

--- Onizlemeyi baslat. Oyuncunun heading'i ankor alinir.
function Preview.start(ped)
    if cam then Preview.stop() end

    heading = GetEntityHeading(ped) + 180.0
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    place(ped)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 400, true, true)
end

function Preview.stop()
    if not cam then return end
    RenderScriptCams(false, true, 400, true, true)
    DestroyCam(cam, true)
    cam = nil
end

--- Kategoriye gore cerceveyi degistir (yumusak gecis RenderScriptCams ile).
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

RegisterCommand('kiyafetkamera', function(_, args)
    local framing = args[1]
    local z, dist, pitch = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])

    if not Preview.Framing[framing] then
        print('^3Kullanim: /kiyafetkamera <head|torso|legs|feet> <z> <mesafe> [pitch]^7')
        print('^3Mevcut degerler:^7')
        for name, f in pairs(Preview.Framing) do
            print(('  %-6s z=%.2f dist=%.2f pitch=%.1f'):format(name, f.z, f.dist, f.pitch))
        end
        return
    end

    if z then Preview.Framing[framing].z = z end
    if dist then Preview.Framing[framing].dist = dist end
    if pitch then Preview.Framing[framing].pitch = pitch end

    local f = Preview.Framing[framing]
    print(('^2%s -> z=%.2f dist=%.2f pitch=%.1f^7'):format(framing, f.z, f.dist, f.pitch))
    print('^2Begendigin degerleri client/preview.lua > Preview.Framing icine gecir.^7')

    if Preview.isActive() then
        Preview.setFraming(PlayerPedId(), framing)
    end
end, false)

BitirimClothing.Preview = Preview
