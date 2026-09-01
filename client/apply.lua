--[[
    client/apply.lua — ped'e uygulama katmani (TEK native noktasi).

    Kural: gecersiz kombinasyon CLAMP EDILMEZ, reddedilir. En yakin gecerli
    degere yuvarlamak sessizce yanlis parca giydirir.
]]

local Constants = BitirimClothing.Constants
local Apply = {}

--- Bir component'i uygula. Gecersizse false doner, ped'e DOKUNULMAZ.
function Apply.component(ped, componentId, drawable, texture)
    texture = texture or 0
    if not IsPedComponentVariationValid(ped, componentId, drawable, texture) then
        return false
    end
    SetPedComponentVariation(ped, componentId, drawable, texture, 0)
    return true
end

--- Bir prop'u uygula. drawable < 0 ise prop temizlenir.
function Apply.prop(ped, propId, drawable, texture)
    if not drawable or drawable < 0 then
        ClearPedProp(ped, propId)
        return true
    end
    SetPedPropIndex(ped, propId, drawable, texture or 0, true)
    return true
end

--- Mevcut bir component'i oku.
function Apply.readComponent(ped, componentId)
    return {
        drawable = GetPedDrawableVariation(ped, componentId),
        texture  = GetPedTextureVariation(ped, componentId),
    }
end

--- Mevcut bir prop'u oku. Takili degilse drawable = -1.
function Apply.readProp(ped, propId)
    return {
        drawable = GetPedPropIndex(ped, propId),
        texture  = GetPedPropTextureIndex(ped, propId),
    }
end

--[[
    Ped'in TAM giyim durumunu oku. Magaza acilisinda snapshot almak icin;
    iptal edilince buraya geri donulur.
]]
function Apply.snapshot(ped)
    local snap = { components = {}, props = {} }
    for _, componentId in ipairs(Constants.ComponentApplyOrder) do
        snap.components[componentId] = Apply.readComponent(ped, componentId)
    end
    for _, propId in ipairs({ Constants.Prop.HAT, Constants.Prop.GLASSES }) do
        snap.props[propId] = Apply.readProp(ped, propId)
    end
    return snap
end

--[[
    Snapshot'a geri don. BEST-EFFORT, per-component: bir component
    basarisiz olursa digerleri yine de geri yuklenir.

    (Hepsi-ya-da-hicbiri rollback burada YANLIS olurdu -- tek bir basarisiz
    component, basariyla geri yuklenmis digerlerini de geri alirdi.)
]]
function Apply.restore(ped, snap)
    if type(snap) ~= 'table' then return false end
    local failed = 0

    for _, componentId in ipairs(Constants.ComponentApplyOrder) do
        local c = snap.components and snap.components[componentId]
        if c then
            if not Apply.component(ped, componentId, c.drawable, c.texture) then
                failed = failed + 1
            end
        end
    end

    for propId, p in pairs(snap.props or {}) do
        Apply.prop(ped, propId, p.drawable, p.texture)
    end

    return failed == 0, failed
end

BitirimClothing.Apply = Apply
