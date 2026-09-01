--[[
    bitirim_clothing — KONUMLAR

    Bu degerler OYUNDA ELLE OLCULDU (/magazakoordinat). VPS'teki calisan
    surumden 2026-09-01'de geri alindi. TAHMIN EDILMEDI — degistirmeden once
    yeniden olc.
]]

Config = Config or {}

Config.Store = {
    label    = 'Kiyafet Magazasi',
    coords   = vec4(426.97, -806.45, 28.49, 90.61),
    pedModel = 'mp_m_shopkeep_01',
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    zOffset  = 0.0,

    -- E ile magaza acilinca oyuncu BURAYA isinlanir. Sabit bir ankor sart:
    -- kamera/backdrop oyuncunun O ANKI konum+heading'ini referans aliyor,
    -- degisken olursa cerceveleme her acilista farkli cikar.
    previewCoords = vec4(429.54, -799.91, 28.49, 293.48),
}

Config.Interaction = {
    key      = 38,      -- 38 = INPUT_PICKUP = "E"
    keyLabel = 'E',
    distance = 2.0,
    helpText = 'Kiyafetlere goz atmak icin',
}

Config.Blip = {
    enabled    = true,
    sprite     = 73,
    color      = 25,
    scale      = 0.8,
    shortRange = true,
}
