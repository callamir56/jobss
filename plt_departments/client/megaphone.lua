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


local megaphoneActive  = false
local megaphoneProp    = nil

local MEGAPHONE_MODEL  = -1585551192
local ANIM_DICT        = "amb@world_human_mobile_film_shocking@male@base"
local ANIM_CLIP        = "base"
local VOICE_RANGE      = 50.0

local function LoadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(10)
    end
end

local function LoadModel(model)
    while not HasModelLoaded(model) do
        RequestModel(model)
        Wait(10)
    end
end

local function SafeDeleteEntity(entity)
    if entity and type(entity) == "number" and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

local function SetMegaphoneVoiceRange()
    if GetResourceState("pma-voice") == "started" then
        pcall(function()
            exports["pma-voice"]:overrideProximityRange(VOICE_RANGE, true)
        end)
    end
end

local function ClearMegaphoneVoiceRange()
    if GetResourceState("pma-voice") == "started" then
        pcall(function()
            exports["pma-voice"]:clearProximityOverride()
        end)
    end
end

function DeactivateMegaphone()
    megaphoneActive = false

    local ped = PlayerPedId()
    ClearPedTasks(ped)

    if megaphoneProp then
        DetachEntity(megaphoneProp, true, false)
        SafeDeleteEntity(megaphoneProp)
        megaphoneProp = nil
    end

    ClearMegaphoneVoiceRange()
    Framework.Notify("Megaphone put away.", "primary")
end

function ActivateMegaphone()
    megaphoneActive = true

    local ped = PlayerPedId()

    LoadAnimDict(ANIM_DICT)
    LoadModel(MEGAPHONE_MODEL)

    local coords = GetEntityCoords(ped)
    megaphoneProp = CreateObject(MEGAPHONE_MODEL, coords.x, coords.y, coords.z, true, true, true)

    AttachEntityToEntity(
        megaphoneProp, ped,
        GetPedBoneIndex(ped, 57005),
        0.11, 0.03, 0.0,
        -100.0, 0.0, -10.0,
        true, true, false, true, 1, true
    )

    TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 8.0, -8.0, -1, 49, 0, false, false, false)

    SetMegaphoneVoiceRange()
    Framework.Notify("Using Megaphone (" .. VOICE_RANGE .. "m range). Press again to stop.", "success")

    CreateThread(function()
        while megaphoneActive do
            if not IsEntityPlayingAnim(ped, ANIM_DICT, ANIM_CLIP, 3) then
                TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            if IsPedRagdoll(ped) or IsEntityDead(ped) or LocalPlayer.state.isCuffed then
                DeactivateMegaphone()
            end

            Wait(500)
        end
    end)
end

RegisterNetEvent("plt_departments:client:toggleMegaphone")
AddEventHandler("plt_departments:client:toggleMegaphone", function()
    if megaphoneActive then
        DeactivateMegaphone()
    else
        ActivateMegaphone()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName and megaphoneActive then
        DeactivateMegaphone()
    end
end)
