--[[
    client/shop.lua — NPC etkilesimi, magaza akisi, NUI koprusu.

    Bitirim konvansiyonu: ox_target YOK -- mesafe + lib.showTextUI + E tusu
    (bitirim_724 / bitirim_otopark / bitirim_vehiclemarket ile ayni desen).

    ONIZLEME MODELI: ayri bir onizleme ped'i YOK. Oyuncunun KENDI ped'i
    kullanilir; acilista snapshot alinir, secimler dogrudan uygulanir, iptal
    edilince snapshot'a donulur. Satin alinan parcanin KALICI gorunumunun tek
    sahibi bitirim_inventory'dir -- magaza kapaninca envanter kendi halini
    uygular.
]]

local Constants = BitirimClothing.Constants
local Apply     = BitirimClothing.Apply
local Compat    = BitirimClothing.Compat
local Catalog   = BitirimClothing.Catalog
local Preview   = BitirimClothing.Preview

local shopPed, shopBlip
local textUIShown = false
local isOpen = false
local snapshot          -- magaza acilisindaki giyim durumu
local returnCoords      -- magaza acilisindaki konum
local cart = {}         -- { {category=, drawable=, texture=}, ... }

---------------------------------------------------------------------------
-- NPC + blip
---------------------------------------------------------------------------

local function spawnPed()
    local s = Config.Store
    local model = GetHashKey(s.pedModel)

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(model) then
        print('^1[bitirim_clothing] NPC modeli yuklenemedi: ' .. s.pedModel .. '^7')
        return
    end

    shopPed = CreatePed(0, model, s.coords.x, s.coords.y, s.coords.z + s.zOffset, s.coords.w, false, true)
    SetEntityInvincible(shopPed, true)
    SetBlockingOfNonTemporaryEvents(shopPed, true)
    FreezeEntityPosition(shopPed, true)
    if s.scenario then
        TaskStartScenarioInPlace(shopPed, s.scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(model)
end

local function createBlip()
    local b = Config.Blip
    if not b or not b.enabled then return end
    local s = Config.Store

    shopBlip = AddBlipForCoord(s.coords.x, s.coords.y, s.coords.z)
    SetBlipSprite(shopBlip, b.sprite)
    SetBlipColour(shopBlip, b.color)
    SetBlipScale(shopBlip, b.scale)
    SetBlipAsShortRange(shopBlip, b.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(s.label)
    EndTextCommandSetBlipName(shopBlip)
end

local function hideTextUI()
    if textUIShown then
        lib.hideTextUI()
        textUIShown = false
    end
end

---------------------------------------------------------------------------
-- Onizleme uygulama
---------------------------------------------------------------------------

local function categoryByKey(key)
    for _, c in ipairs(Config.Categories) do
        if c.key == key then return c end
    end
end

--- Secilen parcayi ped'e GECICI uygula (satin alma yok).
local function previewPiece(categoryKey, drawable, texture)
    local category = categoryByKey(categoryKey)
    if not category or not drawable then return false end

    local ped = PlayerPedId()
    texture = texture or 0

    if category.kind == 'prop' then
        return Apply.prop(ped, category.id, drawable, texture)
    end

    -- Ust giysi: kol otomatik duzeltilir (katmanli savunma).
    if category.id == Constants.Component.TOP then
        return Compat.applyTop(ped, drawable, texture)
    end

    return Apply.component(ped, category.id, drawable, texture)
end

---------------------------------------------------------------------------
-- Ac / kapa
---------------------------------------------------------------------------

local function buildPayload(ped)
    local categories = {}
    for _, c in ipairs(Config.Categories) do
        categories[#categories + 1] = {
            key = c.key, label = c.label, icon = c.icon,
            slot = c.slot, itemLabel = c.itemLabel,
            price = c.price, camera = c.camera,
        }
    end

    return {
        categories = categories,
        catalog    = Catalog.getAll(ped),
        gender     = Constants.genderKey(ped),
        currency   = Config.Currency or '$',
    }
end

local function openShop()
    if isOpen then return end

    local ped = PlayerPedId()
    snapshot     = Apply.snapshot(ped)
    returnCoords = GetEntityCoords(ped)
    cart         = {}

    -- Sabit onizleme noktasina isinla (kamera cercevelemesi buna dayaniyor).
    local p = Config.Store.previewCoords
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(ped, p.w)
    Wait(50)

    Preview.start(ped)
    isOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = buildPayload(ped) })
end

local function closeShop(restore)
    if not isOpen then return end
    isOpen = false

    local ped = PlayerPedId()

    if restore and snapshot then
        Apply.restore(ped, snapshot)
    end

    Preview.stop()

    if returnCoords then
        SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false)
    end

    -- HER kapanista kesinlikle cagrilmali, yoksa oyuncu kilitli kalir.
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    snapshot, returnCoords, cart = nil, nil, {}
end

---------------------------------------------------------------------------
-- NUI callback'leri
---------------------------------------------------------------------------

RegisterNUICallback('selectCategory', function(data, cb)
    local category = categoryByKey(data.category)
    if category then
        Preview.setFraming(PlayerPedId(), category.camera)
    end
    cb({ ok = true })
end)

RegisterNUICallback('selectItem', function(data, cb)
    local ok = previewPiece(data.category, tonumber(data.drawable), tonumber(data.texture))
    cb({ ok = ok == true })
end)

RegisterNUICallback('rotate', function(data, cb)
    Preview.rotate(PlayerPedId(), tonumber(data.delta) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('addToCart', function(data, cb)
    local category = categoryByKey(data.category)
    if not category then return cb({ ok = false }) end

    cart[#cart + 1] = {
        category = category.key,
        drawable = tonumber(data.drawable),
        texture  = tonumber(data.texture) or 0,
    }
    cb({ ok = true, count = #cart })
end)

RegisterNUICallback('removeFromCart', function(data, cb)
    local index = tonumber(data.index)
    if index and cart[index] then table.remove(cart, index) end
    cb({ ok = true, count = #cart })
end)

RegisterNUICallback('checkout', function(_, cb)
    if #cart == 0 then
        return cb({ success = false, reason = 'Sepet bos.' })
    end

    -- Fiyat ve satin alma TAMAMEN server'da dogrulanir; client tutar yollamaz.
    local result = lib.callback.await('bitirim_clothing:buy', false, cart)

    if result and result.success then
        cart = {}
        -- Satin alindi: kalici gorunumu envanter uygular, magaza snapshot'a
        -- DONMEZ (restore = false).
        closeShop(false)
    end

    cb(result or { success = false, reason = 'Sunucu yanit vermedi.' })
end)

RegisterNUICallback('close', function(_, cb)
    closeShop(true)
    cb({ ok = true })
end)

---------------------------------------------------------------------------
-- Etkilesim dongusu
---------------------------------------------------------------------------

CreateThread(function()
    local s = Config.Store
    local center = vec3(s.coords.x, s.coords.y, s.coords.z)
    local interactDist = Config.Interaction.distance

    while true do
        local sleep = 1000

        if not isOpen then
            local dist = #(GetEntityCoords(PlayerPedId()) - center)
            if dist < 15.0 then
                sleep = 0
                if dist <= interactDist then
                    if not textUIShown then
                        lib.showTextUI(
                            ('[%s] %s'):format(Config.Interaction.keyLabel, Config.Interaction.helpText),
                            { position = 'left-center' }
                        )
                        textUIShown = true
                    end
                    if IsControlJustReleased(0, Config.Interaction.key) then
                        hideTextUI()
                        openShop()
                    end
                else
                    hideTextUI()
                end
            else
                hideTextUI()
            end
        else
            sleep = 0
            -- ESC ile kapanma
            if IsControlJustReleased(0, 200) then
                closeShop(true)
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    spawnPed()
    createBlip()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then closeShop(true) end
    hideTextUI()
    if shopPed and DoesEntityExist(shopPed) then DeletePed(shopPed) end
    if shopBlip then RemoveBlip(shopBlip) end
end)

--- Karakter/cinsiyet degisiminde katalog cache'ini dusur.
RegisterNetEvent('qbx_core:client:playerLoaded', function()
    Catalog.invalidate()
end)
