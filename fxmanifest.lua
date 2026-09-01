fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'bitirim_clothing'
author 'Bitirim'
version '2.0.0'
description 'Bitirim kiyafet magazasi -- calisma ani katalog + katmanli kol uyumlulugu'
repository 'https://github.com/Zikachizumo/bitirim_clothing'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
    'qbx_core',
    'ox_inventory',
}

shared_script '@ox_lib/init.lua'

--[[
    Config hem client hem server'da okunur (fiyat dogrulamasi server'da yapilir,
    kategori listesi client'ta cizilir) -- ikisinde de yuklenmeli.
]]
shared_scripts {
    'config/config.lua',
    'config/coords.lua',
    'shared/constants.lua',
}

--[[
    SIRA ONEMLI:
      init    -> ArmsBlacklist'i doldurur; compat.lua bunu YUKLENIRKEN okuyor.
                 Once gelmezse blacklist bos kalir ve yasakli kollar suzulmez.
      apply   -> compat.applyTop bunu kullanir
      compat  -> catalog/shop'tan once
      preview -> shop'tan once
]]
client_scripts {
    'client/init.lua',
    'client/apply.lua',
    'client/compat.lua',
    'client/catalog.lua',
    'client/preview.lua',
    'client/shop.lua',
    'client/coverage.lua',
    'client/hidden.lua',
    'client/probe.lua',
    'client/capture.lua',
    'client/dump.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/capture.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/images/*.png',
    -- lib.load('data.arms_blacklist') client tarafinda bu dosyayi okuyor.
    'data/*.lua',
}
