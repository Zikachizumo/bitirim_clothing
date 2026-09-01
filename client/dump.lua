--[[
    client/dump.lua — KATALOG DOKUMU

    Amac: dosya <-> calisma zamani indeksi eslemesini KANITLAMAK.

    Neden gerekli: GTA giysileri x64v.rpf + 92 DLC paketine dagilmis durumda ve
    her paket kendi icinde 0'dan numaraliyor. Oyunun verdigi tek liste bunlarin
    birlesimi. Eslemeyi cevrimdisi cozmek icin uc yol denendi, ucu de tutmadi:
      * dosya adi hash'lemek (71.847 aday isim) -- eslesme yok
      * .ymt compInfos hash'leri (176 ymt)      -- eslesme yok
      * dlclist.xml sirasiyla sayilari toplamak -- toplamlar tutmuyor
    Sayi tutsa bile "17 numara su dosya" demis olmuyoruz. O yuzden olcuyoruz.

    Toplanan: her drawable icin doku sayisi + apparel hash. Doku sayilari
    dizisi bir parmak izi; dosyalardan cikarilan ayni diziyle hizalanarak
    esleme kuruluyor.

    Komut: /kiyafetdok      -> web/dump/<cinsiyet>.json
]]

local Constants = BitirimClothing.Constants

-- Magazada kullanilan bilesenler + birkac komsu (kol/uppr eslemesi icin lazim)
local COMPONENTS = { 3, 4, 6, 8, 11 }
local PROPS      = { 0, 1, 2, 6, 7 }

local function safeHash(ped, comp, d, t)
    if not GetHashNameForComponent then return 0 end
    local ok, h = pcall(GetHashNameForComponent, ped, comp, d, t or 0)
    return (ok and type(h) == 'number') and h or 0
end

local function safePropHash(ped, prop, d, t)
    if not GetHashNameForProp then return 0 end
    local ok, h = pcall(GetHashNameForProp, ped, prop, d, t or 0)
    return (ok and type(h) == 'number') and h or 0
end

RegisterCommand('kiyafetdok', function()
    local okPerm = lib.callback.await('bitirim_clothing:hasDevPermission', false)
    if not okPerm then
        print('^1Yetkin yok (ace: bitirim_clothing.dev).^7')
        return
    end

    local ped    = PlayerPedId()
    local gender = Constants.genderKey(ped)

    local out = { gender = gender, components = {}, props = {} }

    for _, comp in ipairs(COMPONENTS) do
        local n = GetNumberOfPedDrawableVariations(ped, comp) or 0
        local list = {}
        for d = 0, n - 1 do
            list[#list + 1] = {
                d = d,
                tex = GetNumberOfPedTextureVariations(ped, comp, d) or 0,
                valid = IsPedComponentVariationValid(ped, comp, d, 0) and 1 or 0,
                hash = safeHash(ped, comp, d, 0),
            }
        end
        out.components[tostring(comp)] = list
        print(('^2[dok] component %d: %d drawable^7'):format(comp, n))
        Wait(0)
    end

    for _, prop in ipairs(PROPS) do
        local n = GetNumberOfPedPropDrawableVariations(ped, prop) or 0
        local list = {}
        for d = 0, n - 1 do
            list[#list + 1] = {
                d = d,
                tex = GetNumberOfPedPropTextureVariations(ped, prop, d) or 0,
                hash = safePropHash(ped, prop, d, 0),
            }
        end
        out.props[tostring(prop)] = list
        print(('^2[dok] prop %d: %d drawable^7'):format(prop, n))
        Wait(0)
    end

    local payload = json.encode(out)
    print(('^3[dok] %d bayt gonderiliyor...^7'):format(#payload))

    local ok, err = lib.callback.await('bitirim_clothing:saveDump', false, gender, payload)
    if ok then
        print(('^2[dok] yazildi: web/dump/%s.json^7'):format(gender))
        print('^3Dosyayi bana ilet, esleme kurulacak.^7')
    else
        print(('^1[dok] basarisiz: %s^7'):format(tostring(err)))
    end
end, false)
