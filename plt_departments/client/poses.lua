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


local spawnedProps   = {}
local isAnimPlaying  = false
local currentPoseId  = nil
local poseKeybinds   = {}

local keyControlMap = {
    ["1"] = 157, ["2"] = 158, ["3"] = 160,
    ["4"] = 164, ["5"] = 165, ["6"] = 159,
    ["7"] = 161, ["8"] = 162, ["9"] = 163,
    ["0"] = 37,
}

function LoadKeybinds()
    local stored = GetResourceKvpString("plt_poses_keybinds")
    if stored then
        poseKeybinds = json.decode(stored)
    else
        poseKeybinds = {}
    end
end

function SaveKeybinds()
    SetResourceKvp("plt_poses_keybinds", json.encode(poseKeybinds))
end

function SafeDeleteEntity(entity)
    if entity and type(entity) == "number" and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

function StopAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)

    for _, prop in pairs(spawnedProps) do
        SafeDeleteEntity(prop)
    end

    spawnedProps  = {}
    isAnimPlaying = false
    currentPoseId = nil
end
exports("StopAnimation", StopAnimation)

function SpawnAndAttachProp(ped, modelName, bone, placement, secondPropName, secondBone, secondPlacement)
    
    local function AttachProp(propModel, propBone, propPlacement)
        local hash = GetHashKey(propModel)
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(0) end

        local coords = GetEntityCoords(ped)
        local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)

        AttachEntityToEntity(
            obj, ped,
            GetPedBoneIndex(ped, propBone),
            propPlacement[1], propPlacement[2], propPlacement[3],
            propPlacement[4], propPlacement[5], propPlacement[6],
            true, true, false, true, 1, true
        )

        table.insert(spawnedProps, obj)
        SetModelAsNoLongerNeeded(hash)
    end

    if modelName then
        AttachProp(modelName, bone, placement)
    end

    if secondPropName then
        AttachProp(secondPropName, secondBone, secondPlacement)
    end
end

function PlayPose(poseId)
    local poseData = Config.Animations[poseId] or Config.AnimPoses[poseId]
    if not poseData then return end

    if isAnimPlaying and currentPoseId == poseId then
        StopAnimation()
        return
    end

    StopAnimation()

    local ped = PlayerPedId()

    RequestAnimDict(poseData.dict)
    while not HasAnimDictLoaded(poseData.dict) do Wait(0) end

    SpawnAndAttachProp(
        ped,
        poseData.prop,           poseData.bone,           poseData.placement,
        poseData.secondProp,     poseData.secondPropBone,  poseData.secondPropPlacement
    )

    TaskPlayAnim(
        ped, poseData.dict, poseData.anim,
        8.0, -8.0, -1,
        poseData.flag or 49,
        0, false, false, false
    )

    isAnimPlaying = true
    currentPoseId = poseId
end
exports("PlayPose", PlayPose)

RegisterCommand("animposes", function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = "openPoses",
        animations = Config.AnimPoses,
        keybinds   = poseKeybinds,
    })
end, false)

RegisterNUICallback("closePoses", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("playPose", function(data, cb)
    PlayPose(data.id)
    cb("ok")
end)

RegisterNUICallback("setKeybind", function(data, cb)
    local poseId = data.id
    local key    = data.key

    for boundId, boundKey in pairs(poseKeybinds) do
        if boundKey == key then
            poseKeybinds[boundId] = nil
        end
    end

    if poseId then
        poseKeybinds[poseId] = key
    end

    SaveKeybinds()
    cb("ok")
end)

RegisterNUICallback("stopPose", function(data, cb)
    StopAnimation()
    cb("ok")
end)

CreateThread(function()
    LoadKeybinds()

    while true do
        Wait(0)

        if not IsPauseMenuActive() then
            
            for poseId, key in pairs(poseKeybinds) do
                local control = keyControlMap[key]
                if control and IsControlJustPressed(0, control) then
                    PlayPose(poseId)
                end
            end

            if IsControlJustPressed(0, 73) and isAnimPlaying then
                StopAnimation()
            end
        end
    end
end)

