--[[
    client/probe.lua — /kiyafetprob  (v2)

    v1 SONUCU (2026-09-01, mp_m_freemode_01, b3788):
      Zincir A (GetNumForcedComponents) : 12/12 ornekte 0, p3=0..3 hepsi 0 -> OLU
      Zincir B : GetHashNameForComponent GERCEK hash donduruyor ve
                 GetShopPedApparelVariantComponentCount 1-2 KAYIT bildiriyor
                 -- yani VERI ORADA. Ama okuyucu native
                 `GetShopPedApparelVariantComponentAtIndex` YOK.

    v2'nin isi: okuyucunun GERCEK adini bulmak. Adi tahmin etmek yerine
    _G taranir (FiveM native'leri Lua'da global) -- boylece "hangi isimler
    gercekten var" sorusu olculerek cevaplanir.

    SADECE OKUR.
]]

local Constants = BitirimClothing.Constants
local TOP  = Constants.Component.TOP
local ARMS = Constants.Component.ARMS

--- v1'de gecerli hash + count > 0 dondugu dogrulanan ornekler.
local SAMPLES = { 17, 21, 24, 40, 100, 400, 543 }

---------------------------------------------------------------------------
-- 1) _G taramasi — ilgili isimleri bul
---------------------------------------------------------------------------

local function scanGlobals()
    local hits = {}
    for k, v in pairs(_G) do
        if type(k) == 'string' and type(v) == 'function' then
            local lower = k:lower()
            if lower:find('variant') or lower:find('shopped') or lower:find('forcedcomponent') then
                hits[#hits + 1] = k
            end
        end
    end
    table.sort(hits)
    return hits
end

---------------------------------------------------------------------------
-- 2) Aday okuyucularin her birini (hash, index) ile dene
---------------------------------------------------------------------------

--- Bir fonksiyonun donusunu okunur metne cevir (en fazla 5 deger).
local function fmtReturns(...)
    local n = select('#', ...)
    if n == 0 then return '(donus yok)' end
    local parts = {}
    for i = 1, math.min(n, 5) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    return table.concat(parts, ', ')
end

--- Aday okuyucu mu? Adinda variant/component gecen, count OLMAYAN fonksiyonlar.
local function looksLikeReader(name)
    local lower = name:lower()
    if lower:find('count') then return false end
    return lower:find('variant') ~= nil
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

    local ped = PlayerPedId()

    print('^2============ NATIVE PROB v2 ============^7')

    -- 1) Gercekte hangi isimler var?
    local names = scanGlobals()
    print(('^2--- _G icinde variant/shopped/forcedcomponent gecen %d fonksiyon ---^7'):format(#names))
    for _, n in ipairs(names) do
        print('  ' .. n)
    end

    -- 2) Ornek bir hash al (v1'de calistigi dogrulanan bir ust giysiden).
    local sampleHash
    for _, d in ipairs(SAMPLES) do
        local okH, h = pcall(GetHashNameForComponent, ped, TOP, d, 0)
        if okH and h and h ~= 0 then
            local okC, c = pcall(GetShopPedApparelVariantComponentCount, h)
            if okC and type(c) == 'number' and c > 0 then
                sampleHash = h
                print('')
                print(('^2ornek: top %d  hash=%s  count=%d^7'):format(d, tostring(h), c))
                break
            end
        end
    end

    if not sampleHash then
        print('^1Gecerli hash+count bulunamadi -- v1 sonucuyla celisiyor, tekrar bak.^7')
        return
    end

    -- 3) Aday okuyuculari sirayla dene.
    print('')
    print('^2--- aday okuyucular (hash, 0) ile cagriliyor ---^7')
    local worked = {}
    for _, n in ipairs(names) do
        if looksLikeReader(n) then
            local res = table.pack(pcall(_G[n], sampleHash, 0))
            if res[1] then
                local text = fmtReturns(table.unpack(res, 2, res.n))
                print(('  ^2%-46s -> %s^7'):format(n, text))
                if res.n > 2 then worked[#worked + 1] = n end
            else
                print(('  ^1%-46s -> HATA: %s^7'):format(n, tostring(res[2])))
            end
        end
    end

    -- 4) Ise yarayan okuyucuyla butun ornekleri coz.
    if #worked == 0 then
        print('')
        print('^1Hicbir aday okuyucu birden fazla deger dondurmedi.^7')
        print('^3Yukaridaki _G listesini bana yapistir -- dogru adi oradan secerim.^7')
        return
    end

    local reader = worked[1]
    print('')
    print(('^2--- "%s" ile ornekler cozuluyor ---^7'):format(reader))
    local armsHits = 0
    for _, d in ipairs(SAMPLES) do
        local okH, h = pcall(GetHashNameForComponent, ped, TOP, d, 0)
        if okH and h and h ~= 0 then
            local okC, c = pcall(GetShopPedApparelVariantComponentCount, h)
            if okC and type(c) == 'number' and c > 0 then
                local line, arms = {}, nil
                for i = 0, c - 1 do
                    local r = table.pack(pcall(_G[reader], h, i))
                    if r[1] then
                        -- Donus sirasi bilinmiyor; HEPSINI bas ki desen gorulsun.
                        line[#line + 1] = '{' .. fmtReturns(table.unpack(r, 2, r.n)) .. '}'
                        -- componentType == 3 (ARMS) aranan deger.
                        for k = 2, r.n do
                            if r[k] == ARMS and type(r[k - 1]) == 'number' then
                                arms = arms or r[k - 1]
                            end
                        end
                    end
                end
                if arms then armsHits = armsHits + 1 end
                print(('  top %-4d %s%s'):format(d, table.concat(line, ' '),
                    arms and ('  ^2-> KOL=%d^7'):format(arms) or ''))
            end
        end
    end

    print('')
    print(('^2kol cevabi veren ornek: %d/%d^7'):format(armsHits, #SAMPLES))
    print('^2========================================^7')
end, false)
