--[[
    server/capture.lua — THUMBNAIL YAZMA

    Client kareyi cektirir, burasi diske yazar.

    Zincir DOGRULANDI (VPS'teki `screencapture` resource'u, fxmanifest'inde
    `provide 'screenshot-basic'`):
        exports.screencapture:serverCapture(source, options, cb, dataType)
    dataType 'base64' -> cb'ye "data:image/png;base64,...." data URI'si gelir.

    Ayri bir HTTP alici GEREKMIYOR: base64 burada cozulup SaveResourceFile ile
    dogrudan web/images/ altina yaziliyor.
]]

local RESOURCE = GetCurrentResourceName()

---------------------------------------------------------------------------
-- base64 cozucu
---------------------------------------------------------------------------

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local lookup = {}
for i = 1, #B64 do lookup[B64:sub(i, i)] = i - 1 end

local function b64decode(data)
    data = data:gsub('[^A-Za-z0-9+/=]', '')
    local out = {}

    for i = 1, #data, 4 do
        local c1, c2, c3, c4 = data:sub(i, i), data:sub(i + 1, i + 1),
                               data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
        local n1, n2 = lookup[c1], lookup[c2]
        if not n1 or not n2 then break end

        local n3 = (c3 ~= '=' and c3 ~= '') and lookup[c3] or nil
        local n4 = (c4 ~= '=' and c4 ~= '') and lookup[c4] or nil

        out[#out + 1] = string.char((n1 << 2) | (n2 >> 4))
        if n3 then out[#out + 1] = string.char(((n2 & 0x0F) << 4) | (n3 >> 2)) end
        if n3 and n4 then out[#out + 1] = string.char(((n3 & 0x03) << 6) | n4) end
    end

    return table.concat(out)
end

---------------------------------------------------------------------------
-- Yakalama + yazma
---------------------------------------------------------------------------

--[[
    Bir kare cek ve web/images/<name>.png olarak yaz.
    Donus: true / false, hata mesaji.

    `name` client'tan geliyor -- DOSYA YOLU OLARAK GUVENSIZ kabul edilir,
    sadece [a-z0-9_] kalibina uyanlar kabul edilir (path traversal koruma).
]]
lib.callback.register('bitirim_clothing:captureThumb', function(source, name, maxSize)
    if not IsPlayerAceAllowed(source, 'bitirim_clothing.dev') then
        return false, 'yetki yok'
    end

    if type(name) ~= 'string' or not name:match('^[a-z0-9_]+$') then
        return false, 'gecersiz dosya adi'
    end

    maxSize = tonumber(maxSize) or 256
    if maxSize < 32 or maxSize > 1024 then maxSize = 256 end

    local done, ok, err = false, false, nil

    local callOk = pcall(function()
        exports.screencapture:serverCapture(source, {
            encoding  = 'png',
            maxWidth  = maxSize,
            maxHeight = maxSize,
        }, function(data)
            if type(data) ~= 'string' or #data < 32 then
                ok, err, done = false, 'bos veri', true
                return
            end

            -- "data:image/png;base64,...." on ekini at
            local payload = data:match('^data:[^,]*,(.+)$') or data
            local binary  = b64decode(payload)

            if #binary < 64 then
                ok, err, done = false, 'cozulen veri cok kucuk', true
                return
            end

            local path = ('web/images/%s.png'):format(name)
            SaveResourceFile(RESOURCE, path, binary, #binary)

            --[[
                SaveResourceFile'in DONUS DEGERINE GUVENMIYORUZ.
                Olculdu (2026-09-01): 221 thumbnail diske sorunsuz yazildi ama
                cagri `true` donmedi ve hepsi "basarisiz" raporlandi. Tek
                guvenilir kanit dosyayi geri okumak.
            ]]
            local check = LoadResourceFile(RESOURCE, path)
            if check and #check == #binary then
                ok, err, done = true, nil, true
            else
                ok, err, done = false, 'diske yazilamadi', true
            end
        end, 'base64')
    end)

    if not callOk then
        return false, 'screencapture export cagrilamadi'
    end

    -- Yanit bekle (en fazla 10sn)
    local deadline = GetGameTimer() + 10000
    while not done and GetGameTimer() < deadline do Wait(25) end

    if not done then return false, 'zaman asimi' end
    return ok, err
end)

--[[
    Katalog dokumunu diske yaz (bkz. client/dump.lua).
    Icerik client'tan geliyor ama sadece ACE yetkili biri cagirabiliyor ve
    dosya adi cinsiyetle sinirli -- serbest yol adi kabul edilmiyor.
]]
lib.callback.register('bitirim_clothing:saveDump', function(source, gender, payload)
    if not IsPlayerAceAllowed(source, 'bitirim_clothing.dev') then
        return false, 'yetki yok'
    end
    if gender ~= 'male' and gender ~= 'female' then
        return false, 'gecersiz cinsiyet'
    end
    if type(payload) ~= 'string' or #payload < 32 then
        return false, 'bos veri'
    end

    local path = ('web/dump/%s.json'):format(gender)
    SaveResourceFile(RESOURCE, path, payload, #payload)

    -- Donus degerine guvenmiyoruz (bkz. yukaridaki not), geri okuyoruz.
    local check = LoadResourceFile(RESOURCE, path)
    if check and #check == #payload then
        print(('[bitirim_clothing] katalog dokumu yazildi: %s (%d bayt)'):format(path, #payload))
        return true
    end
    return false, 'diske yazilamadi'
end)

--- Bir thumbnail zaten var mi? (Client diski goremez, server bakar.)
lib.callback.register('bitirim_clothing:thumbExists', function(_, name)
    if type(name) ~= 'string' or not name:match('^[a-z0-9_]+$') then return false end
    local content = LoadResourceFile(RESOURCE, ('web/images/%s.png'):format(name))
    return content ~= nil and #content > 64
end)
