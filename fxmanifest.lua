fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ndrp_tasks'
author 'NDRP'
description 'Uppdragsystem med Lation Timeline'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'ui.html'

files {
    'ui.html',
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'lation_ui',
}
