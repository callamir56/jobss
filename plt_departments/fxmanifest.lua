--[[
░▒▓████████▓▒░▒▓██████▓▒░       ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░  
   ░▒▓█▓▒░  ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
   ░▒▓█▓▒░  ░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
   ░▒▓█▓▒░  ░▒▓█▓▒░             ░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░  
   ░▒▓█▓▒░  ░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
   ░▒▓█▓▒░  ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
   ░▒▓█▓▒░   ░▒▓██████▓▒░       ░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓███████▓▒░  
                                                                         
 This File Leaked By TC HUB Team, Join Our Server For More
 DISCORD: - https://discord.gg/tndFR89Sye - https://t.me/+RgDxwPX3L7w2ODBk - https://tchub.st/
--]]


fx_version 'cerulean'
game 'gta5'

lua54 'yes'

description 'Department Creator made by Pluto Dev'
version '1.0.0'
author 'PLUTO'

shared_scripts {
    'shared/config.lua',
    'shared/framework.lua',
    'shared/inventory.lua'
}

client_scripts {
    'lib/client/lib.lua',
    'client/main.lua',
    'client/officer_menu.lua',
    'client/dispatch.lua',
    'client/poses.lua',
    'client/k9_menu.lua',
    'client/radar.lua',
    'client/alpr.lua',
    'client/breathalyzer.lua',
    'client/megaphone.lua',
    'client/cameras.lua',
    'client/evidence.lua',
    'client/tracker.lua',
    'client/comms.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'lib/server/lib.lua',
    'server/main.lua',
    'server/boss_menu.lua',
    'server/officer_menu.lua',
    'server/dispatch.lua',
    'server/radar.lua',
    'server/breathalyzer.lua',
    'server/megaphone.lua',
    'server/evidence.lua',
    'server/tracker.lua',
    'server/comms.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/boss_menu.css',
    'web/boss_menu.js',
    'web/vintage_boss_menu.css',
    'web/vintage_boss_menu.js',
    'web/officer_menu.css',
    'web/officer_menu.js',
    'web/dispatch.css',
    'web/dispatch.js',
    'web/poses.css',
    'web/poses.js',
    'web/k9_menu.js',
    'web/radar_setup.css',
    'web/alpr.css',
    'web/armory.css',
    'web/alpr.js',
    'web/armory.js',
    'web/breathalyzer.js',
    'web/breathalyzer.css',
    'web/cameras.css',
    'web/evidence.js',
    'web/evidence.css',
    'web/swipe_card.js',
    'web/img/*.jpg',
    'web/img/*.png',
    'web/img/*.webp'
}

escrow_ignore {
    'shared/**',
}

-- Note: the original 'dependency "/assetpacks"' (escrow leftover) was removed.
-- Required resources: es_extended, oxmysql, ox_lib, ox_target, ox_inventory

exports {
    'AddBolo',
    'UpdateBolo',
    'DeleteBolo',
    'AddWarrant',
    'UpdateWarrant',
    'DeleteWarrant',
    'GetPlayerDepartment',
    'AddMoneyToDept',
    'SendDepartmentMail',
    'IsDepartmentsReady',
    'GetDepartmentsData',
    'GetDepartmentCatalog',
    'ResolveDepartmentFromJob',
    'CuffPlayer',
    'UncuffPlayer',
    'ToggleCuffPlayer',
    'IsPlayerCuffed',
    'BreakCuffs',
    'SeizeVehicle',
    'RequestSeizeVehicle'
}

