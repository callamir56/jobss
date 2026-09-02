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


local FINGER_ANIM_DICT = "mp_player_int_upperfinger"
local FINGER_ANIM_CLIP = "mp_player_int_upperfinger"

local DRINK_ANIM_DICT  = "amb@world_human_drinking@coffee@male@base"
local DRINK_ANIM_CLIP  = "base"

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

local function StopFingerAnim()
    StopAnimTask(PlayerPedId(), FINGER_ANIM_DICT, FINGER_ANIM_CLIP, 1.0)
end

RegisterNetEvent("plt_departments:client:useBreathalyzer")
AddEventHandler("plt_departments:client:useBreathalyzer", function()
    local playerId, distance = Framework.GetClosestPlayer()

    if playerId ~= -1 and distance < 2.0 then
        local serverId = GetPlayerServerId(playerId)
        TriggerServerEvent("plt_departments:server:requestBreathTest", serverId)
        Framework.Notify("Requesting breath test from nearest person...", "primary")
    else
        Framework.Notify("No one nearby!", "error")
    end
end)

RegisterNetEvent("plt_departments:client:startBreathTest")
AddEventHandler("plt_departments:client:startBreathTest", function(officerId, isSubject)
    SetNuiFocus(isSubject, isSubject)
    SendNUIMessage({ action = "openBreathalyzer", officerId = officerId, isPlayer = isSubject })

    if isSubject then
        local ped = PlayerPedId()
        LoadAnimDict(FINGER_ANIM_DICT)
        TaskPlayAnim(ped, FINGER_ANIM_DICT, FINGER_ANIM_CLIP,
            8.0, -8.0, -1, 49, 0, false, false, false)
    end
end)

RegisterNetEvent("plt_departments:client:updateBreathProgress")
AddEventHandler("plt_departments:client:updateBreathProgress", function(progress, indicatorPos)
    SendNUIMessage({ action = "syncBreathProgress", progress = progress, indicatorPos = indicatorPos })
end)

RegisterNetEvent("plt_departments:client:breathTestResult")
AddEventHandler("plt_departments:client:breathTestResult", function(result, targetName)
    SendNUIMessage({ action = "showBreathResult", result = result, targetName = targetName })
end)

RegisterNetEvent("plt_departments:client:consumeAlcohol")
AddEventHandler("plt_departments:client:consumeAlcohol", function()
    local ped = PlayerPedId()

    LoadAnimDict(DRINK_ANIM_DICT)
    TaskPlayAnim(ped, DRINK_ANIM_DICT, DRINK_ANIM_CLIP,
        8.0, 8.0, 5000, 49, 0, false, false, false)

    Wait(5000)
    StopAnimTask(ped, DRINK_ANIM_DICT, DRINK_ANIM_CLIP, 1.0)

    ShakeGameplayCam("DRUNK_SHAKE", 1.0)
    SetTimeout(30000, function()
        StopGameplayCamShaking(true)
    end)
end)

RegisterNUICallback("syncBreathProgress", function(data, cb)
    TriggerServerEvent("plt_departments:server:syncBreathProgress",
        data.officerId, data.progress, data.indicatorPos)
    cb("ok")
end)

RegisterNUICallback("breathalyzerComplete", function(data, cb)
    SetNuiFocus(false, false)

    local officerId = data.officerId
    local bac = 0.0
    if data.success then
        bac = math.random(0, 25) / 100
    end

    TriggerServerEvent("plt_departments:server:sendBreathResult", officerId, bac)
    StopFingerAnim()
    cb("ok")
end)

RegisterNUICallback("closeBreathalyzer", function(data, cb)
    SetNuiFocus(false, false)
    StopFingerAnim()
    cb("ok")
end)
