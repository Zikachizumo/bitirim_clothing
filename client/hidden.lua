--[[
    client/hidden.lua — GIZLENEN PARCALAR + BOSLUK GOZDEN GECIRME ARACI

    Amac: kol verisi olmayan (katman 4'e dusen) ust giysiler arasindan
    GERCEKTEN bozuk gorunenleri isaretleyip magaza katalogundan cikarmak.

    Neden hepsini birden gizlemiyoruz: 48 parcanin cogu varsayilan kolla
    sorunsuz gorunur. Korlemesine gizlemek calisan kiyafetleri de siler.
    Karar gorseldir ve KULLANICIYA aittir -- agent oyunu goremez.

    Komutlar:
      /kiyafetbosluk            gozden gecirmeyi baslat (ilk bosluga giy)
      /kiyafetbosluk s          sonraki
      /kiyafetbosluk o          onceki
      /kiyafetbosluk kol <d>    bu ust icin farkli bir kol dene
      /kiyafetbosluk gizle      bu ustu KATALOGDAN CIKAR (kalici)
      /kiyafetbosluk goster     gizlemeyi geri al
      /kiyafetbosluk cik        gozden gecirmeyi bitir, eski gorunume don
      /kiyafetgizli             gizlenenleri listele
]]

local Constants = BitirimClothing.Constants
local Apply     = BitirimClothing.Apply
local Compat    = BitirimClothing.Compat

local TOP  = Constants.Component.TOP
local ARMS = Constants.Component.ARMS

local Hidden = {}

-- cache[gender][categoryKey] = { [drawable] = true }
local cache = {}

---------------------------------------------------------------------------
-- Gizli liste
---------------------------------------------------------------------------

function Hidden.load(rows)
    cache = {}
    if type(rows) ~= 'table' then return 0 end
    local n = 0
    for _, r in ipairs(rows) do
        local g, c, d = r.gender, r.category, tonumber(r.drawable)
        if g and c and d then
            cache[g] = cache[g] or {}
            cache[g][c] = cache[g][c] or {}
            cache[g][c][d] = true
            n = n + 1
        end
    end
    return n
end

function Hidden.is(gender, categoryKey, drawable)
    local g = cache[gender]
    if not g then return false end
    local c = g[categoryKey]
    return c ~= nil and c[drawable] == true
end

function Hidden.list(gender)
    local out = {}
    for categoryKey, drawables in pairs(cache[gender] or {}) do
        local ds = {}
        for d in pairs(drawables) do ds[#ds + 1] = d end
        table.sort(ds)
        out[categoryKey] = ds
    end
    return out
end

--- Server'a yaz ve yerel cache'i guncelle.
local function setHidden(gender, categoryKey, drawable, hide, reason)
    local ok = lib.callback.await('bitirim_clothing:setHidden', false,
        gender, categoryKey, drawable, hide, reason)
    if not ok then return false end

    cache[gender] = cache[gender] or {}
    cache[gender][categoryKey] = cache[gender][categoryKey] or {}
    cache[gender][categoryKey][drawable] = hide or nil

    -- Katalog cache'i bayatladi.
    BitirimClothing.Catalog.invalidate()
    return true
end

BitirimClothing.Hidden = Hidden

---------------------------------------------------------------------------
-- Gozden gecirme oturumu
---------------------------------------------------------------------------

local review = { active = false, list = {}, index = 1, snapshot = nil }

local function currentTop()
    return review.list[review.index]
end

local function showCurrent()
    local ped = PlayerPedId()
    local d = currentTop()
    if not d then return end

    Apply.component(ped, TOP, d, 0)

    local arms, source = Compat.resolveArms(ped, d, 0)
    if arms then Apply.component(ped, ARMS, arms, 0) end

    local gender = Constants.genderKey(ped)
    print(('^2[%d/%d] ust=%d  kol=%s (%s)%s^7'):format(
        review.index, #review.list, d,
        arms and tostring(arms) or 'dokunulmadi',
        source or 'yok',
        Hidden.is(gender, 'outerwear', d) and '  ^1[GIZLI]^7' or ''))
end

local function buildGapList(ped)
    local list = {}
    local topCount = GetNumberOfPedDrawableVariations(ped, TOP) or 0
    for d = 0, topCount - 1 do
        local _, source = Compat.resolveArms(ped, d, 0)
        if source == 'default' or source == nil then
            -- Taban parcalari (magaza katalogunda olmayanlar) atlanir:
            -- oyuncu onlari zaten magazadan alamaz.
            if Compat.diagnoseTop(ped, d, 0) ~= 'no_hash' then
                list[#list + 1] = d
            end
        end
    end
    return list
end

local function startReview()
    local ped = PlayerPedId()
    review.snapshot = Apply.snapshot(ped)
    review.list = buildGapList(ped)
    review.index = 1
    review.active = true

    if #review.list == 0 then
        print('^2Bosluk yok -- her ust giysinin kolu cozulebiliyor.^7')
        review.active = false
        return
    end

    print(('^2%d bosluk parcasi gozden gecirilecek.^7'):format(#review.list))
    print('^3s=sonraki  o=onceki  kol <d>=kol dene  gizle / goster  cik^7')
    showCurrent()
end

local function endReview()
    if not review.active then return end
    review.active = false
    if review.snapshot then
        Apply.restore(PlayerPedId(), review.snapshot)
        review.snapshot = nil
    end
    print('^2Gozden gecirme bitti, eski gorunume donuldu.^7')
end

RegisterCommand('kiyafetbosluk', function(_, args)
    local okPerm = lib.callback.await('bitirim_clothing:hasDevPermission', false)
    if not okPerm then
        print('^1Yetkin yok (ace: bitirim_clothing.dev).^7')
        return
    end

    local sub = args[1]

    if not sub then
        startReview()
        return
    end

    if not review.active then
        print('^3Once /kiyafetbosluk yazip baslat.^7')
        return
    end

    local ped    = PlayerPedId()
    local gender = Constants.genderKey(ped)
    local d      = currentTop()

    if sub == 's' then
        review.index = math.min(review.index + 1, #review.list)
        showCurrent()

    elseif sub == 'o' then
        review.index = math.max(review.index - 1, 1)
        showCurrent()

    elseif sub == 'kol' then
        local arms = tonumber(args[2])
        if not arms then
            print('^3Kullanim: /kiyafetbosluk kol <drawable>^7')
            return
        end
        if Apply.component(ped, ARMS, arms, 0) then
            print(("^2kol %d uygulandi. Iyi gorunuyorsa bana soyle, DB kaydi acarim.^7"):format(arms))
        else
            print(('^1kol %d gecersiz (bu ped icin yok).^7'):format(arms))
        end

    elseif sub == 'gizle' then
        if setHidden(gender, 'outerwear', d, true, 'gorsel kusur (elle isaretlendi)') then
            print(('^1ust %d GIZLENDI -- magaza katalogunda artik gorunmeyecek.^7'):format(d))
        else
            print('^1Gizlenemedi (server hatasi).^7')
        end

    elseif sub == 'goster' then
        if setHidden(gender, 'outerwear', d, false) then
            print(('^2ust %d tekrar gorunur.^7'):format(d))
        else
            print('^1Islem basarisiz.^7')
        end

    elseif sub == 'cik' then
        endReview()

    else
        print('^3s=sonraki  o=onceki  kol <d>  gizle  goster  cik^7')
    end
end, false)

RegisterCommand('kiyafetgizli', function()
    local okPerm = lib.callback.await('bitirim_clothing:hasDevPermission', false)
    if not okPerm then return end

    local gender = Constants.genderKey(PlayerPedId())
    local all = Hidden.list(gender)

    print(('^2--- gizli parcalar (%s) ---^7'):format(gender))
    local any = false
    for categoryKey, ds in pairs(all) do
        if #ds > 0 then
            any = true
            print(('  %-11s %s'):format(categoryKey, table.concat(ds, ', ')))
        end
    end
    if not any then print('  (yok)') end
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then endReview() end
end)
