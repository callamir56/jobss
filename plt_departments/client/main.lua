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


if not PLTLibClient or not PLTLibClient.RegisterCoreCallbacks then
    error("plt_departments client lib missing: lib/client/lib.lua")
end

local departmentBlips   = {}   
local targetZones       = {}   
local vehicleDeleteZones = {}  
local officerBlips      = {}   

local armoryNodeId      = nil  
local savedOutfit       = nil  
local isUniformActive   = false 
local debugMarkersOn    = false 
local currentDoorHint   = nil  

local k9BedObjects      = {}   
local interactionPeds   = {}   
local macintoshObject   = nil  

local pendingOutfitList = {}

PLTLibClient.RegisterCoreCallbacks()

function GetTargetSystem()
    local cfg = tostring(Config and Config.Target or ""):lower()
    if cfg == "qb-target" or cfg == "qb_target" then return "qb-target" end
    if cfg == "ox_target" or cfg == "ox-target" then return "ox_target" end
    if GetResourceState("ox_target") == "started"  then return "ox_target" end
    if GetResourceState("qb-target") == "started"  then return "qb-target" end
    return "ox_target"
end

function GetSpeedUnit()
    local unit = tostring(Config and Config.SpeedUnit or "kmh"):lower()
    return unit == "mph" and "MPH" or "KM/H"
end

function GetNotificationSystem()
    local sys = tostring(Config and Config.NotificationSystem or "nui"):lower()
    if sys == "esx" then return "esx" end
    return sys == "ox_lib" and "ox_lib" or "nui"
end

function NormaliseNotifyType(rawType)
    local types = { primary = "inform", error = "error", success = "success" }
    local key = tostring(rawType or ""):lower()
    return types[key] or "inform"
end

function PushLocaleToNUI()
    SendNUIMessage({
        action       = "updateLocale",
        translations = PLTGetLocaleTable(),
        speedUnit    = GetSpeedUnit(),
    })
end
PLTPushLocaleToNUI = PushLocaleToNUI

function ESXShowNotification(message)
    -- ESX native notification (es_extended)
    if ESX and type(ESX.ShowNotification) == "function" then
        local ok = pcall(function() ESX.ShowNotification(message) end)
        if ok then return true end
    end
    if GetResourceState("es_extended") == "started" then
        TriggerEvent("esx:showNotification", message)
        return true
    end
    return false
end

function SendNotification(message, notifyType, titleOverride)
    if not Config or not Config.ShowNotifications then return end

    local title
    if titleOverride then
        title = titleOverride
    elseif notifyType == "error" then
        title = T("attention_title")
    elseif notifyType == "success" then
        title = T("success_title")
    elseif notifyType == "primary" then
        title = T("info_title")
    else
        title = T("notification_title")
    end

    local system = GetNotificationSystem()

    if system == "esx" then
        if ESXShowNotification(message) then return end
    elseif system == "ox_lib" then
        local ok = pcall(function()
            exports.ox_lib:notify({
                title       = title,
                description = message,
                type        = NormaliseNotifyType(notifyType),
            })
        end)
        if ok then return end
    end

    SendNUIMessage({ action = "showNotification", title = title, message = message })
end

function SafeDeleteEntity(entity)
    if entity and type(entity) == "number" and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

function RotationToDirection(rotation)
    local rad = { x = math.pi / 180 * rotation.x, y = math.pi / 180 * rotation.y, z = math.pi / 180 * rotation.z }
    local cosX = math.abs(math.cos(rad.x))
    return {
        x = -math.sin(rad.z) * cosX,
        y =  math.cos(rad.z) * cosX,
        z =  math.sin(rad.x),
    }
end

function RaycastFromCamera(distance)
    local rot    = GetGameplayCamRot(2)
    local origin = GetGameplayCamCoord()
    local dir    = RotationToDirection(rot)
    local dest   = vector3(
        origin.x + dir.x * distance,
        origin.y + dir.y * distance,
        origin.z + dir.z * distance
    )

    local ped    = PlayerPedId()
    local entity = ped
    if IsPedInAnyVehicle(ped, false) then
        entity = GetVehiclePedIsIn(ped, false)
    end

    local handle = _ENV["StartExpensiveSynchronousShapeTestLosProbe"](
        origin.x, origin.y, origin.z,
        dest.x,   dest.y,   dest.z,
        -1, entity, 0
    )
    local _, hit, hitCoords, _, hitEntity = GetShapeTestResult(handle)
    return hit, hitCoords, hitEntity
end

function Draw3DText(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

function TitleCase(str)
    return (str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

function ResolveNodeLabel(labelKey, fallbackKey, forceName)
    if not labelKey or labelKey == "" then return T(fallbackKey) end

    local lower = labelKey:lower()
    local newPrefixes = {
        "new location", "new department", "new boss",
        "new vehicle",  "new armory",     "new door",
        "new rank",     "new permission",
    }
    for _, prefix in ipairs(newPrefixes) do
        if lower:find(prefix) then
            return T(fallbackKey)
        end
    end

    if lower == fallbackKey:lower() then return T(fallbackKey) end
    if forceName then return T(labelKey) end

    return T(labelKey) .. " (" .. T(fallbackKey) .. ")"
end

function SaveCivilianOutfit()
    local ped = PlayerPedId()
    savedOutfit = {}

    for slot = 0, 11 do
        savedOutfit[slot] = {
            drawable = GetPedDrawableVariation(ped, slot),
            texture  = GetPedTextureVariation(ped, slot),
            palette  = GetPedPaletteVariation(ped, slot),
        }
    end

    savedOutfit.props = {}
    for slot = 0, 7 do
        savedOutfit.props[slot] = {
            drawable = GetPedPropIndex(ped, slot),
            texture  = GetPedPropTextureIndex(ped, slot),
        }
    end
end

function IsPlayerAlive()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return false end
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then return false end

    local state = LocalPlayer and LocalPlayer.state
    if state and (state.dead or state.isDead or state.inlaststand) then
        return false
    end
    return true
end

function RestoreCivilianOutfit()
    if not IsPlayerAlive() then
        isUniformActive = true
        return false
    end

    local ped = PlayerPedId()
    if not savedOutfit then
        isUniformActive = false
        return false
    end

    for slot = 0, 11 do
        local comp = savedOutfit[slot]
        if comp then
            SetPedComponentVariation(ped, slot, comp.drawable, comp.texture, comp.palette)
        end
    end

    for slot = 0, 7 do
        local prop = savedOutfit.props and savedOutfit.props[slot]
        if prop then
            if prop.drawable == -1 then
                ClearPedProp(ped, slot)
            else
                SetPedPropIndex(ped, slot, prop.drawable, prop.texture, true)
            end
        end
    end

    savedOutfit      = nil
    isUniformActive  = false
    return true
end

CreateThread(function()
    while true do
        Wait(1000)
        if isUniformActive and IsPlayerAlive() then
            RestoreCivilianOutfit()
        end
    end
end)

DepartmentData  = { nodes = {}, links = {} }
LocalPlayerJob  = { dept = "none", grade = 0, onDuty = false }

function GetLocalPlayerJob()      return LocalPlayerJob end
function GetLocalPlayerOnDuty()   return LocalPlayerJob.onDuty end
function GetLocalPlayerDept()     return LocalPlayerJob.dept end
function GetLocalPlayerGrade()    return LocalPlayerJob.grade end

__cE0 = GetLocalPlayerJob
__cE1 = GetLocalPlayerOnDuty
__cE2 = GetLocalPlayerDept
__cE3 = GetLocalPlayerGrade

function UpdateLocalPlayerJob(membersData)
    local playerData = Framework.GetPlayerData()
    if not playerData then return end

    local citizenId = playerData.citizenid
    if not citizenId then return end

    local record = membersData[citizenId]
    if not record then
        for _, entry in pairs(membersData) do
            if entry.name == playerData.name then
                record = entry
                break
            end
        end
    end

    local wasOnDuty = LocalPlayerJob.onDuty

    if record then
        LocalPlayerJob.dept   = record.dept   or "none"
        LocalPlayerJob.grade  = record.grade  or 0
        LocalPlayerJob.onDuty = record.onDuty or false
    else
        LocalPlayerJob.dept   = "none"
        LocalPlayerJob.grade  = 0
        LocalPlayerJob.onDuty = false
    end

    if Framework.Type == "esx"
        and LocalPlayerJob.dept ~= "none"
        and not LocalPlayerJob.onDuty
        and playerData.job and playerData.job.onduty
    then
        LocalPlayerJob.onDuty = true
    end

    if wasOnDuty and not LocalPlayerJob.onDuty then
        RestoreCivilianOutfit()
        for _, blip in pairs(officerBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        officerBlips = {}
    end
end
UpdateLocalPlayerJob = UpdateLocalPlayerJob  

CreateThread(function()
    while true do
        Wait(0)
        
    end
end)

local function ClearAllTargetZones()
    local targetSystem = GetTargetSystem()

    if targetSystem == "qb-target" then
        for key in pairs(targetZones) do
            if type(key) == "string" and key:find("plt_dept_") then
                pcall(function() exports["qb-target"]:RemoveZone(key) end)
            end
        end
    elseif targetSystem == "ox_target" then
        for _, zoneRef in pairs(targetZones) do
            if type(zoneRef) == "number" or type(zoneRef) == "string" then
                pcall(function() exports.ox_target:removeZone(zoneRef) end)
            end
        end
    end
    targetZones = {}
end

local function TriggerOptionEvent(option, data)
    if option.type == "client" then
        TriggerEvent(option.event, data or option)
    else
        TriggerServerEvent(option.event, data or option)
    end
end

local function BuildOxOptions(options, interactDistance)
    local out = {}
    for _, opt in ipairs(options) do
        table.insert(out, {
            icon        = opt.icon,
            label       = opt.label,
            distance    = interactDistance,
            canInteract = opt.canInteract,
            onSelect    = function() TriggerOptionEvent(opt) end,
        })
    end
    return out
end

local function BuildQBOptions(options)
    local out = {}
    for _, opt in ipairs(options) do
        table.insert(out, {
            type        = opt.type or "client",
            event       = opt.event or "",
            icon        = opt.icon,
            label       = opt.label,
            canInteract = opt.canInteract,
            action      = function()
                if opt.event and opt.event ~= "" then
                    TriggerOptionEvent(opt)
                end
            end,
        })
    end
    return out
end

local function MakeCanInteractCheck(locType, jobName)
    return function()
        local pd = Framework.GetPlayerData()
        if not pd then return false end

        local onDuty = (LocalPlayerJob and LocalPlayerJob.onDuty) or false

        if not onDuty and pd.job and pd.job.onduty then
            onDuty = true
        end

        local currentDept = (LocalPlayerJob and LocalPlayerJob.dept) or "none"

        if currentDept == "none" and pd.job and pd.job.name then
            local fwJob = tostring(pd.job.name):lower()
            local deptFwJob = tostring(GetFrameworkJobFromNodeId(jobName) or ""):lower()
            if fwJob == "" or deptFwJob == "" or fwJob ~= deptFwJob then
                return false
            end
        elseif tostring(currentDept) ~= tostring(jobName) then
            return false
        end

        local dutyRequired = { duty=true, garage=true, helipad=true, impound=true, stash=true }
        if dutyRequired[locType] then return onDuty end
        return true
    end
end

local function ApplyLocTypeIcon(options, locType)
    if #options == 0 then return end
    local icons = {
        duty      = "fas fa-user-shield",
        stash     = "fas fa-box-open",
        garage    = "fas fa-car",
        helipad   = "fas fa-helicopter",
        armory    = "fas fa-gun",
        impound   = "fas fa-truck-pickup",
        boss_menu = "fas fa-briefcase",
    }
    if icons[locType] then options[1].icon = icons[locType] end
end

function RegisterTargetZone(nodeId, locType, coords, label, jobName, entityOverride)
    if not coords or not coords.x then return end

    local zoneKey     = "plt_dept_" .. nodeId .. "_" .. locType
    local targetSystem = GetTargetSystem()
    local displayLabel = TitleCase(locType:gsub("_", " "))
    local interactDist = 3.0

    if targetZones[zoneKey] then
        if targetSystem == "ox_target" then
            pcall(function() exports.ox_target:removeZone(targetZones[zoneKey]) end)
        elseif targetSystem == "qb-target" then
            pcall(function() exports["qb-target"]:RemoveZone(zoneKey) end)
        end
        targetZones[zoneKey] = nil
    end

    local canInteract = MakeCanInteractCheck(locType, jobName)

    local baseOption = {
        type        = "client",
        event       = "plt_departments:c1",
        icon        = "fas fa-hand-pointer",
        label       = ResolveNodeLabel(label, locType, false),
        locType     = locType,
        job         = jobName,
        nodeId      = nodeId,
        coords      = coords,
        canInteract = canInteract,
    }

    local options = {}

    if locType == "wardrobe_node" then
        table.insert(options, {
            type = "client", event = "plt_departments:client:ApplyUniform",
            icon = "fas fa-tshirt", label = T("put_on_uniform"),
            nodeId = nodeId, canInteract = canInteract,
        })
        table.insert(options, {
            type = "client", event = "plt_departments:client:RestoreCivilian",
            icon = "fas fa-user", label = T("take_off_uniform"),
            canInteract = canInteract,
        })
    elseif locType == "k9" then
        table.insert(options, {
            type = "client", event = "plt_departments:client:SpawnK9",
            icon = "fas fa-dog", label = T("spawn_k9"),
            nodeId = nodeId, job = jobName, canInteract = canInteract,
        })
        table.insert(options, {
            type = "client", event = "plt_departments:client:RemoveK9",
            icon = "fas fa-times", label = T("remove_k9"),
            canInteract = canInteract,
        })
    else
        table.insert(options, baseOption)
    end

    ApplyLocTypeIcon(options, locType)

    if entityOverride and DoesEntityExist(entityOverride) then
        if targetSystem == "ox_target" then
            exports.ox_target:addLocalEntity(entityOverride, BuildOxOptions(options, interactDist))
        elseif targetSystem == "qb-target" then
            exports["qb-target"]:AddTargetEntity(entityOverride, {
                options  = BuildQBOptions(options),
                distance = interactDist,
            })
        end
        return
    end

    if targetSystem == "ox_target" then
        local zoneId = exports.ox_target:addSphereZone({
            coords   = vector3(coords.x, coords.y, coords.z),
            radius   = 1.2,
            debug    = false,
            options  = BuildOxOptions(options, interactDist),
            distance = interactDist,
        })
        targetZones[zoneKey] = zoneId

    elseif targetSystem == "qb-target" then
        local heading = coords.h or 0.0
        exports["qb-target"]:AddBoxZone(zoneKey,
            vector3(coords.x, coords.y, coords.z),
            1.5, 1.5,
            {
                name     = zoneKey,
                heading  = heading,
                debugPoly = false,
                minZ     = coords.z - 1.0,
                maxZ     = coords.z + 1.0,
                useZ     = true,
            },
            { options = BuildQBOptions(options), distance = interactDist }
        )
        targetZones[zoneKey] = true
    end
end

function RemoveSafeEntity(entity)
    SafeDeleteEntity(entity)
end

function RemoveMacintosh(coordsOverride)
    SafeDeleteEntity(macintoshObject)
    macintoshObject = nil

    if coordsOverride then
        local nearby = GetClosestObjectOfType(
            coordsOverride.x, coordsOverride.y, coordsOverride.z,
            2.0, -1853013031, false, false, false
        )
        SafeDeleteEntity(nearby)
    end
end
RemoveMacintosh = RemoveMacintosh

function RemoveK9Beds()
    for key, entity in pairs(k9BedObjects) do
        if type(entity) == "number" then SafeDeleteEntity(entity) end
        k9BedObjects[key] = "canceled"
    end
end
RemoveK9Beds = RemoveK9Beds

function RemoveInteractionPeds()
    for _, entity in pairs(interactionPeds) do
        if type(entity) == "number" then SafeDeleteEntity(entity) end
    end
    interactionPeds = {}
    
    esxProximityPeds = {}
end
RemoveInteractionPeds = RemoveInteractionPeds

esxProximityPeds = {}

function SpawnMacintosh(coords)
    RemoveMacintosh(coords)
    if not coords then return end

    if type(coords) == "vector3" then
        coords = { x = coords.x, y = coords.y, z = coords.z }
    end

    local modelHash = -1853013031

    CreateThread(function()
        RequestModel(modelHash)
        local attempts = 0
        while not HasModelLoaded(modelHash) and attempts < 100 do
            Wait(10)
            attempts = attempts + 1
        end

        if HasModelLoaded(modelHash) then
            local obj = CreateObject(modelHash,
                coords.x, coords.y, coords.z - 1.0, false, false, false)

            local heading = tonumber(coords.h or coords.w) or 0.0

            local function ApplyHeading()
                SetEntityHeading(obj, heading)
                SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
            end

            PlaceObjectOnGroundProperly(obj)
            ApplyHeading()
            Wait(0)
            ApplyHeading()
            Wait(75)
            ApplyHeading()
            Wait(150)
            ApplyHeading()

            FreezeEntityPosition(obj, true)
            SetEntityInvincible(obj, true)
            macintoshObject = obj
        end
    end)
end

function SpawnK9Bed(nodeId, coords, jobName, label)
    if not coords then return end

    if k9BedObjects[nodeId] then
        if type(k9BedObjects[nodeId]) == "number" then
            SafeDeleteEntity(k9BedObjects[nodeId])
        end
    end

    local existingProp = GetClosestObjectOfType(
        coords.x, coords.y, coords.z, 2.0, -1109800045, false, false, false)
    SafeDeleteEntity(existingProp)

    k9BedObjects[nodeId] = "loading"

    local modelHash = -1109800045
    local heading   = tonumber(coords.h or coords.w) or 0.0

    CreateThread(function()
        RequestModel(modelHash)
        local attempts = 0
        while not HasModelLoaded(modelHash) and attempts < 100 do
            Wait(10)
            attempts = attempts + 1
        end

        if not HasModelLoaded(modelHash) then
            if k9BedObjects[nodeId] == "loading" then
                k9BedObjects[nodeId] = nil
            end
            return
        end

        local obj = CreateObject(modelHash,
            coords.x, coords.y, coords.z - 1.0, false, false, false)

        SetEntityHeading(obj, heading)
        SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
        PlaceObjectOnGroundProperly(obj)
        SetEntityHeading(obj, heading)
        SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
        Wait(0)
        SetEntityHeading(obj, heading)
        SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
        Wait(75)
        SetEntityHeading(obj, heading)
        SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
        Wait(150)
        SetEntityHeading(obj, heading)
        SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)

        if k9BedObjects[nodeId] == "loading" then
            k9BedObjects[nodeId] = obj
            if jobName then
                RegisterTargetZone(nodeId, "k9", coords, label or "K9 Unit", jobName)
            end
        else
            SafeDeleteEntity(obj)
        end
    end)
end

function SpawnInteractionPed(nodeId, locType, coords, label, jobName, pedModelHash)
    if not coords then return end

    local pedKey = tostring(nodeId) .. "_" .. tostring(locType)

    if interactionPeds[pedKey] then
        if type(interactionPeds[pedKey]) == "number" then
            SafeDeleteEntity(interactionPeds[pedKey])
        end
    end

    local existingPed = GetClosestPed(coords.x, coords.y, coords.z, 1.5, false, false, false, false, -1)
    if existingPed ~= 0 and not IsPedAPlayer(existingPed) then
        SafeDeleteEntity(existingPed)
    end

    interactionPeds[pedKey] = "loading"

    local model   = pedModelHash or 1581098148
    local heading = coords.h or 0.0

    CreateThread(function()
        RequestModel(model)
        local attempts = 0
        while not HasModelLoaded(model) and attempts < 500 do
            Wait(10)
            attempts = attempts + 1
        end

        if not HasModelLoaded(model) then
            if interactionPeds[pedKey] == "loading" then
                interactionPeds[pedKey] = nil
            end
            SetModelAsNoLongerNeeded(model)
            return
        end

        local ped = CreatePed(4, model, coords.x, coords.y, coords.z, heading or 0.0, false, false)

        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetEntityInvincible(ped, true)
            SetPedDefaultComponentVariation(ped)
            SetEntityVisible(ped, true, false)
            SetEntityAlpha(ped, 255, false)
            FreezeEntityPosition(ped, true)
            SetEntityHeading(ped, (heading or 0.0) + 0.0)

            if interactionPeds[pedKey] == "loading" then
                interactionPeds[pedKey] = ped
                RegisterTargetZone(nodeId, locType, coords, label, jobName, ped)
            else
                SafeDeleteEntity(ped)
            end
        else
            if interactionPeds[pedKey] == "loading" then
                interactionPeds[pedKey] = nil
            end
        end

        SetModelAsNoLongerNeeded(model)
    end)
end

function SetArmoryNodeId(nodeId)
    armoryNodeId = nodeId
end
PLTSetArmoryNodeId = SetArmoryNodeId

function RefreshBlipsAndZones(data)
    if not data or not data.nodes or #data.nodes == 0 then return end

    DepartmentData = data

    for _, blip in pairs(departmentBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    departmentBlips  = {}
    vehicleDeleteZones = {}

    ClearAllTargetZones()
    RemoveK9Beds()
    RemoveInteractionPeds()
    PushLocaleToNUI()

    local deptIds = {}
    for _, node in ipairs(data.nodes) do
        if node.type == "department" then
            deptIds[node.id] = node.id
        end
    end

    for _, node in ipairs(data.nodes) do

        if node.type == "department" and node.coords then
            local blip = AddBlipForCoord(node.coords.x, node.coords.y, node.coords.z)
            SetBlipSprite(blip, node.blipId or 60)
            SetBlipColour(blip, node.blipColor or 1)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            local blipName = (node.blipName and node.blipName ~= "") and node.blipName or node.label
            AddTextComponentString(ResolveNodeLabel(blipName, "Department", true))
            EndTextCommandSetBlipName(blip)
            departmentBlips[node.id] = blip
        end

        if node.type == "k9" and node.coords then
            local dept = GetDepartmentForNode(node.id, data)
            SpawnK9Bed(node.id, node.coords, dept, node.label)
        end

        if node.type == "location" then
            local dept = GetDepartmentForNode(node.id, data)

            if node.coordsList then
                for subType, subCoords in pairs(node.coordsList) do
                    if dept then
                        local interactType = (node.interactionTypes and node.interactionTypes[subType]) or node.interactionType or "zone"
                        if interactType == "ped" then
                            SpawnInteractionPed(node.id, subType, subCoords, node.label, dept,
                                node.pedType == "sheriff" and -1320879687 or
                                node.pedType == "fib"     and -306416314  or 1581098148)
                        else
                            RegisterTargetZone(node.id, subType, subCoords, node.label, dept)
                        end
                    end
                end
            elseif node.coords then
                local interactType = node.interactionType or "zone"
                if interactType == "ped" then
                    SpawnInteractionPed(node.id, node.type, node.coords, node.label, dept)
                else
                    RegisterTargetZone(node.id, node.type, node.coords, node.label, dept)
                end
            end
        end

        if node.type == "boss_menu" then
            local coords = node.coords or (node.coordsList and node.coordsList.boss_menu)
            local dept   = coords and GetDepartmentForNode(node.id, data)
            if dept and coords then
                local interactType = (node.interactionTypes and node.interactionTypes.boss_menu) or node.interactionType or "zone"
                if interactType == "ped" then
                    SpawnInteractionPed(node.id, "boss_menu", coords, node.label or "Boss Menu", dept,
                        node.pedType == "sheriff" and -1320879687 or 1581098148)
                else
                    RegisterTargetZone(node.id, "boss_menu", coords, node.label or "Boss Menu", dept)
                end
            end
        end

        if node.type == "armory" then
            local coords = node.coords or (node.coordsList and node.coordsList.armory)
            local dept   = coords and GetDepartmentForNode(node.id, data)
            if dept and coords then
                local interactType = (node.interactionTypes and node.interactionTypes.armory) or node.interactionType or "zone"
                if interactType == "ped" then
                    SpawnInteractionPed(node.id, "armory", coords, node.label, dept,
                        node.pedType == "sheriff" and -1320879687 or 1581098148)
                else
                    RegisterTargetZone(node.id, "armory", coords, node.label, dept)
                end
            end
        end

        if node.type == "wardrobe" then
            local coords = node.coords or (node.coordsList and node.coordsList.wardrobe)
            local dept   = coords and GetDepartmentForNode(node.id, data)
            if dept and coords then
                local interactType = (node.interactionTypes and node.interactionTypes.wardrobe) or node.interactionType or "zone"
                if interactType == "ped" then
                    SpawnInteractionPed(node.id, "wardrobe_node", coords, node.label, dept,
                        node.pedType == "sheriff" and -1320879687 or 1581098148)
                else
                    RegisterTargetZone(node.id, "wardrobe_node", coords, node.label, dept)
                end
            end
        end

        if node.type == "evidence" then
            local coords = node.coords or (node.coordsList and node.coordsList.evidence)
            local dept   = coords and GetDepartmentForNode(node.id, data)
            if dept and coords then
                local interactType = (node.interactionTypes and node.interactionTypes.evidence) or node.interactionType or "zone"
                if interactType == "ped" then
                    SpawnInteractionPed(node.id, "evidence", coords, node.label or "Evidence Locker", dept,
                        node.pedType == "sheriff" and -1320879687 or 1581098148)
                else
                    RegisterTargetZone(node.id, "evidence", coords, node.label or "Evidence Locker", dept)
                end
            end
        end

        if node.type == "vehicle" or node.type == "helipad" then
            local dept = GetDepartmentForNode(node.id, data)
            if node.deletePoints then
                for _, pt in ipairs(node.deletePoints) do
                    if dept then
                        table.insert(vehicleDeleteZones, {
                            coords   = pt,
                            job      = dept,
                            vehicles = node.vehicles or {},
                        })
                    end
                end
            end
        end
    end
end
RefreshBlipsAndZones = RefreshBlipsAndZones

RegisterNetEvent("plt_departments:client:UpdateOfficerBlips")
AddEventHandler("plt_departments:client:UpdateOfficerBlips", function(officerList)
    if not LocalPlayerJob.onDuty then
        for _, blip in pairs(officerBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        officerBlips = {}
        return
    end

    local myServerId = GetPlayerServerId(PlayerId())
    local seenIds    = {}

    for _, officer in ipairs(officerList) do
        local serverId = tonumber(officer.source)
        if serverId ~= myServerId then
            local idKey = tostring(serverId)
            seenIds[idKey] = true

            if not officerBlips[idKey] then
                
                local blip = AddBlipForCoord(officer.coords.x, officer.coords.y, officer.coords.z)
                SetBlipSprite(blip, 1)
                SetBlipColour(blip, officer.color or 1)
                SetBlipScale(blip, 0.7)
                SetBlipAsShortRange(blip, false)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(officer.name)
                EndTextCommandSetBlipName(blip)
                officerBlips[idKey] = blip
            else
                
                SetBlipCoords(officerBlips[idKey], officer.coords.x, officer.coords.y, officer.coords.z)
                SetBlipColour(officerBlips[idKey], officer.color or 1)
            end
        end
    end

    for idKey, blip in pairs(officerBlips) do
        if not seenIds[idKey] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            officerBlips[idKey] = nil
        end
    end
end)

RegisterNetEvent("plt_departments:client:Notify")
AddEventHandler("plt_departments:client:Notify", SendNotification)

RegisterNetEvent("plt_departments:client:SyncJobs")
AddEventHandler("plt_departments:client:SyncJobs", function(departmentPayload)
    RefreshBlipsAndZones(departmentPayload)
    Framework.TriggerCallback("plt_departments:server:GetData", function(serverData)
        UpdateLocalPlayerJob(serverData.members)
        SendNUIMessage({
            action      = "syncData",
            data        = serverData.departments,
            finances    = serverData.finances,
            balances    = serverData.balances,
            members     = serverData.members,
        })
    end)
end)

RegisterNetEvent("plt_departments:client:SyncMembers")
AddEventHandler("plt_departments:client:SyncMembers", function(membersData)
    MemberData = membersData
    UpdateLocalPlayerJob(membersData)
    SendNUIMessage({ action = "syncData", members = membersData })
end)

RegisterNetEvent("plt_departments:client:Interact")
AddEventHandler("plt_departments:client:Interact", function(data)
    if PLTLibClient and PLTLibClient.HandleInteract then
        PLTLibClient.HandleInteract(data)
    end
end)

RegisterNetEvent("plt_departments:c1")
AddEventHandler("plt_departments:c1", function(data)
    if PLTLibClient and PLTLibClient.HandleInteract then
        PLTLibClient.HandleInteract(data)
    end
end)

CreateThread(function()
    Wait(1500)
    while true do
        local pd = Framework.GetPlayerData()
        if pd and pd.citizenid then break end
        Wait(100)
    end
    TriggerServerEvent("plt_departments:s0")
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded")
AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
    TriggerServerEvent("plt_departments:s0")
end)

RegisterNetEvent("esx:playerLoaded")
AddEventHandler("esx:playerLoaded", function()
    TriggerServerEvent("plt_departments:s0")
end)

RegisterNetEvent("plt_departments:client:ApplyUniform")
AddEventHandler("plt_departments:client:ApplyUniform", function(data)
    local nodeId = data.nodeId
    Framework.TriggerCallback("plt_departments:server:GetData", function(serverData)
        local targetNode = nil
        for _, node in ipairs(serverData.departments.nodes) do
            if node.id == nodeId then
                targetNode = node
                break
            end
        end

        if not targetNode or not targetNode.outfits then return end

        local rankKey   = "rank_" .. LocalPlayerJob.grade
        local outfitSet = targetNode.outfits[rankKey]
        if not outfitSet then
            Framework.Notify(T("no_outfits_rank"), "error")
            return
        end

        if type(outfitSet) == "table" and not outfitSet[1] then
            outfitSet = { outfitSet }
        end

        if #outfitSet > 1 then
            pendingOutfitList = outfitSet
            SetNuiFocus(true, true)
            PushLocaleToNUI()
            SendNUIMessage({ action = "openOutfitSelection", outfits = outfitSet })
        elseif #outfitSet == 1 then
            ApplyOutfit(outfitSet[1])
        else
            Framework.Notify(T("no_outfits_rank"), "error")
        end
    end)
end)

function ApplyOutfit(outfit)
    local ped = PlayerPedId()
    if not savedOutfit then SaveCivilianOutfit() end

    local components = {
        mask=1, hair=2, arms=3, pants=4, bags=5, shoes=6,
        accessory=7, undershirt=8, vest=9, decals=10, top=11,
    }
    for name, slot in pairs(components) do
        local comp = outfit[name]
        if comp then
            SetPedComponentVariation(ped, slot, comp.item or 0, comp.texture or 0, 0)
        end
    end

    local props = { hat=0, glasses=1, ears=2, watch=6, bracelet=7 }
    for name, slot in pairs(props) do
        local prop = outfit[name]
        if prop then
            if prop.item == -1 then
                ClearPedProp(ped, slot)
            else
                SetPedPropIndex(ped, slot, prop.item, prop.texture or 0, true)
            end
        end
    end

    Framework.Notify(T("uniform_applied"), "success")
end
ApplyOutfit = ApplyOutfit

__cN0 = function(data, cb)
    SetNuiFocus(false, false)
    local selected = pendingOutfitList[data.index + 1]
    if selected then ApplyOutfit(selected) end
    pendingOutfitList = {}
    cb("ok")
end

__cN1 = function(data, cb)
    SetNuiFocus(false, false)
    pendingOutfitList = {}
    cb("ok")
end

RegisterNetEvent("plt_departments:client:RestoreCivilian")
AddEventHandler("plt_departments:client:RestoreCivilian", function()
    RestoreCivilianOutfit()
    Framework.Notify(T("civilian_clothes_restored"), "primary")
end)

__cN2 = function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent("plt_departments:s3")
    cb("ok")
end

__cN3 = function(data, cb)
    if PLTLibClient and PLTLibClient.HandleSpawnVehicle then
        return PLTLibClient.HandleSpawnVehicle(data, cb)
    end
    cb("ok")
end

__cN4 = function(data, cb) SetNuiFocus(false, false) cb("ok") end
__cN5 = function(data, cb) SetNuiFocus(false, false) cb("ok") end

__cN6 = function(data, cb)
    local qty = tonumber(data.quantity) or 1
    TriggerServerEvent("plt_departments:s4", data.name, data.type, armoryNodeId, qty)
    cb("ok")
end

__cN7 = function(data, cb)
    TriggerServerEvent("plt_departments:s9", data)
    cb("ok")
end

__cN8 = function(data, cb)
    SetNuiFocus(false, false)

    data.locType = data.locType or data.type or "location"

    if data.type == "k9" and data.locType == "bed" then
        local existing = k9BedObjects[data.nodeId]
        if existing then
            SafeDeleteEntity(existing)
            k9BedObjects[data.nodeId] = "canceled"
        end
    end

    if data.interactionType == "ped" then
        local pedKey = tostring(data.nodeId or "unknown") .. "_" .. tostring(data.locType)
        SafeDeleteEntity(interactionPeds[pedKey])
        interactionPeds[pedKey] = nil
    end

    CreateThread(function()
        local previewEntity = nil
        local previewHeading = 0.0

        local nodeData = nil
        if DepartmentData and DepartmentData.nodes and data.nodeId then
            for _, node in ipairs(DepartmentData.nodes) do
                if tostring(node.id) == tostring(data.nodeId) then
                    nodeData = node
                    break
                end
            end
        end

        if data.type == "k9" then
            if data.locType == "bed" then
                local model = -1109800045
                RequestModel(model)
                while not HasModelLoaded(model) do Wait(0) end

                previewEntity = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
                if nodeData and nodeData.coords and nodeData.coords.h ~= nil then
                    previewHeading = tonumber(nodeData.coords.h) or 0.0
                else
                    previewHeading = GetEntityHeading(PlayerPedId())
                end
            elseif data.locType == "spawn" then
                local model = 1126154828
                RequestModel(model)
                while not HasModelLoaded(model) do Wait(0) end

                previewEntity = CreatePed(28, model, 0.0, 0.0, 0.0, 0.0, false, false)
                if nodeData and nodeData.spawnCoords and nodeData.spawnCoords.h ~= nil then
                    previewHeading = tonumber(nodeData.spawnCoords.h) or 0.0
                else
                    previewHeading = GetEntityHeading(PlayerPedId())
                end
            end
        elseif data.interactionType == "ped" then
            local model = 1581098148
            RequestModel(model)
            while not HasModelLoaded(model) do Wait(0) end

            previewEntity = CreatePed(4, model, 0.0, 0.0, 0.0, 0.0, false, false)
            SetEntityInvincible(previewEntity, true)
            FreezeEntityPosition(previewEntity, true)
        elseif data.locType == "spawn" or data.locType == "impound_spawn" or data.locType == "delete" then
            local model = data.type == "helipad" and 353883353 or 2046537925
            RequestModel(model)
            while not HasModelLoaded(model) do Wait(0) end

            previewEntity = CreateVehicle(model, 0.0, 0.0, 0.0, 0.0, false, false)
        end

        if previewEntity then
            SetEntityAlpha(previewEntity, 150, false)
            SetEntityCollision(previewEntity, false, false)
        end

        SendNUIMessage({ action = "togglePlacementHelp", visible = true,
            header        = T("placement_header"),
            confirmLabel  = T("confirm_placement"),
            rotateLabel   = T("rotate_placement"),
        })

        local currentRotation = previewHeading
        local placed = false

        while not placed do
            Wait(0)
            local hit, hitCoords, _ = RaycastFromCamera(20.0)

            if previewEntity and hit then
                SetEntityCoords(previewEntity, hitCoords.x, hitCoords.y, hitCoords.z, false, false, false, false)
                SetEntityHeading(previewEntity, currentRotation)
            end

            if IsControlPressed(0, 44) then currentRotation = (currentRotation + 1.0) % 360.0 end
            if IsControlPressed(0, 46) then currentRotation = (currentRotation - 1.0) % 360.0 end

            if IsControlJustPressed(0, 38) and hit then
                local finalCoords = {
                    x = hitCoords.x, y = hitCoords.y, z = hitCoords.z,
                    h = currentRotation,
                }

                if DepartmentData and DepartmentData.nodes then
                    for _, node in ipairs(DepartmentData.nodes) do
                        if tostring(node.id) == tostring(data.nodeId) then
                            if data.type == "k9" then
                                if data.locType == "bed" then
                                    node.coords = finalCoords
                                    local dept = GetDepartmentForNode(node.id, DepartmentData)
                                    SpawnK9Bed(node.id, node.coords, dept, node.label)
                                elseif data.locType == "spawn" then
                                    node.spawnCoords = finalCoords
                                end
                            elseif data.locType then
                                if node.type == "location" then
                                    node.coordsList = node.coordsList or {}
                                    node.coordsList[data.locType] = finalCoords
                                else
                                    node.coords = finalCoords
                                end
                            else
                                node.coords = finalCoords
                            end
                            break
                        end
                    end
                end

                SendNUIMessage({ action = "togglePlacementHelp", visible = false })
                SafeDeleteEntity(previewEntity)
                SetNuiFocus(true, true)
                SendNUIMessage({
                    action          = "placementDone",
                    nodeId          = data.nodeId,
                    locType         = data.locType,
                    pointIndex      = data.pointIndex,
                    interactionType = data.interactionType,
                    coords          = finalCoords,
                })
                placed = true
            end

            if IsControlJustPressed(0, 177) then
                SendNUIMessage({ action = "togglePlacementHelp", visible = false })
                SafeDeleteEntity(previewEntity)
                SetNuiFocus(true, true)
                placed = true
            end
        end
    end)

    cb("ok")
end

__cN9 = function(data, cb)
    SetNuiFocus(false, false)

    CreateThread(function()
        SendNUIMessage({
            action       = "togglePlacementHelp",
            visible      = true,
            header       = T("door_selection_header"),
            confirmLabel = T("select_door"),
            rotateLabel  = "N/A",
        })

        local hoveredDoor = nil

        while true do
            Wait(0)
            local hit, hitCoords, hitEntity = RaycastFromCamera(100.0)

            if hit then
                
                DrawMarker(28,
                    hitCoords.x, hitCoords.y, hitCoords.z,
                    0, 0, 0, 0, 0, 0,
                    0.1, 0.1, 0.1,
                    0, 255, 0, 150,
                    false, false, 2, false, nil, nil, false)

                if hitEntity ~= 0 and IsEntityAnObject(hitEntity) then
                    local entityCoords = GetEntityCoords(hitEntity)

                    if hoveredDoor ~= hitEntity then
                        Framework.ShowTextUI(T("select_this_door"), "primary")
                        hoveredDoor = hitEntity
                    end

                    DrawMarker(9,
                        entityCoords.x, entityCoords.y, entityCoords.z + 0.5,
                        0.0, 0.0, 0.0, 0.0, 90.0, 0.0,
                        0.15, 0.15, 0.15,
                        37, 99, 235, 200,
                        false, true, 2, false, nil, nil, false)

                    if IsControlJustPressed(0, 38) then
                        SendNUIMessage({ action = "togglePlacementHelp", visible = false })
                        Framework.HideTextUI()
                        local doorHeading = GetEntityHeading(hitEntity)
                        SetNuiFocus(true, true)
                        SendNUIMessage({
                            action    = "doorPlacementDone",
                            nodeId    = data.nodeId,
                            doorIndex = data.doorIndex,
                            doorNum   = data.doorNum or 1,
                            coords    = { x = entityCoords.x, y = entityCoords.y, z = entityCoords.z, h = doorHeading },
                            hash      = GetEntityModel(hitEntity),
                        })
                        break
                    end
                elseif hoveredDoor then
                    Framework.HideTextUI()
                    hoveredDoor = nil
                end
            end

            if IsControlJustPressed(0, 177) then
                SendNUIMessage({ action = "togglePlacementHelp", visible = false })
                Framework.HideTextUI()
                SetNuiFocus(true, true)
                break
            end
        end
    end)

    cb("ok")
end

__cD0 = function()
    debugMarkersOn = not debugMarkersOn
    local stateLabel = debugMarkersOn and T("online") or T("offline")
    Framework.Notify(T("dept_debug_markers", { state = stateLabel }))
end

__cD1 = function()
    local pd = Framework.GetPlayerData()
    if not pd then return end

    if not LocalPlayerJob or LocalPlayerJob.dept == "none" then
        Framework.Notify(T("not_part_of_dept"), "error")
        return
    end
    TriggerServerEvent("plt_departments:s3")
end

__cD2 = function()
    if not DepartmentData or not DepartmentData.nodes then return end
    for _, node in ipairs(DepartmentData.nodes) do
        if node.type == "door" and node.doors then
            for _, door in ipairs(node.doors) do
                
            end
        end
    end
end

local function FindDoorByHash(hashKey)
    if not DepartmentData or not DepartmentData.nodes then return nil end

    for _, node in ipairs(DepartmentData.nodes) do
        if node.type == "door" and node.doors then
            for i, door in ipairs(node.doors) do
                local key1 = GetHashKey("plt_door_" .. tostring(node.id) .. "_" .. i)
                if key1 == hashKey then
                    return { hash = door.hash, coords = door.coords }
                end
                if door.isDouble then
                    local key2 = GetHashKey("plt_door_" .. tostring(node.id) .. "_" .. i .. "_2")
                    if key2 == hashKey then
                        return { hash = door.hash2, coords = door.coords2 }
                    end
                end
            end
        end
    end
    return nil
end

RegisterNetEvent("plt_departments:client:SyncDoorState")
AddEventHandler("plt_departments:client:SyncDoorState", function(hashKeyRaw, state)
    local hashKey  = tonumber(hashKeyRaw)
    local doorData = FindDoorByHash(hashKey)
    if not doorData or not doorData.hash or not doorData.coords then return end
    if not doorData.coords.x or not doorData.coords.y or not doorData.coords.z then return end

    if not IsDoorRegisteredWithSystem(hashKey) then
        AddDoorToSystem(hashKey, doorData.hash,
            doorData.coords.x, doorData.coords.y, doorData.coords.z,
            false, false, false)
    end

    local doorState = (state == 1) and 1 or 0
    DoorSystemSetDoorState(hashKey, doorState, false, true)
    DoorSystemSetHoldOpen(hashKey, false)

    if state == 1 then
        DoorSystemSetAutomaticRate(hashKey, 1.0, false, false)
    end
end)

RegisterNetEvent("plt_departments:client:SyncAllDoors")
AddEventHandler("plt_departments:client:SyncAllDoors", function(doorStates)
    CreateThread(function()
        local attempts = 0
        while (not DepartmentData or not DepartmentData.nodes or #DepartmentData.nodes == 0) and attempts < 50 do
            Wait(100)
            attempts = attempts + 1
        end
        for hashKey, lockState in pairs(doorStates) do
            TriggerEvent("plt_departments:client:SyncDoorState", hashKey, lockState)
        end
    end)
end)

CreateThread(function()
    while true do
        local tickInterval = 1000
        local ped          = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local nearbyDoor   = nil

        if DepartmentData and DepartmentData.nodes then
            for _, node in ipairs(DepartmentData.nodes) do
                if node.type == "door" and node.doors then
                    local dept = GetDepartmentForNode(node.id, DepartmentData)
                    if dept then
                        local playerDept  = tostring(LocalPlayerJob.dept)
                        local nodeDept    = tostring(dept)
                        local hasAccess   = debugMarkersOn or playerDept == nodeDept or playerDept ~= "none"

                        if hasAccess then
                            for i, door in ipairs(node.doors) do
                                if door.coords then
                                    local doorVec  = vector3(door.coords.x, door.coords.y, door.coords.z)
                                    local grade    = tonumber(LocalPlayerJob.grade) or 0
                                    local minRank  = tonumber(door.minRank) or 0
                                    local ctrlDist = tonumber(door.controlDistance) or tonumber(door.distance) or 2.0
                                    local checkDist = math.max(ctrlDist, 5.0)
                                    local dist      = #(playerCoords - doorVec)

                                    local canOpen = debugMarkersOn or grade >= minRank

                                    if canOpen and checkDist > dist then
                                        tickInterval = 5

                                        local key1 = GetHashKey("plt_door_" .. tostring(node.id) .. "_" .. i)
                                        local key2 = nil
                                        if door.isDouble and door.coords2 then
                                            key2 = GetHashKey("plt_door_" .. tostring(node.id) .. "_" .. i .. "_2")
                                        end

                                        if not IsDoorRegisteredWithSystem(key1) then
                                            AddDoorToSystem(key1, door.hash,
                                                door.coords.x, door.coords.y, door.coords.z,
                                                false, false, false)
                                        end
                                        if key2 and not IsDoorRegisteredWithSystem(key2) then
                                            AddDoorToSystem(key2, door.hash2,
                                                door.coords2.x, door.coords2.y, door.coords2.z,
                                                false, false, false)
                                        end

                                        local inRangeDouble = false
                                        if key2 and door.coords2 then
                                            local doorVec2 = vector3(door.coords2.x, door.coords2.y, door.coords2.z)
                                            inRangeDouble  = checkDist > #(playerCoords - doorVec2)
                                        end

                                        if inRangeDouble or not key2 then
                                            
                                            local locked = DoorSystemGetDoorState(key1) == 1
                                            nearbyDoor = { id = tostring(node.id) .. "_" .. i, locked = locked }

                                            if IsControlJustPressed(0, 38) then
                                                local newState = locked and 0 or 1
                                                TriggerServerEvent("plt_departments:s5", key1, newState)
                                                if key2 then
                                                    TriggerServerEvent("plt_departments:s5", key2, newState)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if nearbyDoor then
            local actionLabel = nearbyDoor.locked and T("unlock_door") or T("lock_door")
            local hintStyle   = nearbyDoor.locked and "error" or "success"
            local hintKey     = nearbyDoor.id .. "_" .. tostring(nearbyDoor.locked)

            if currentDoorHint ~= hintKey then
                Framework.ShowTextUI(actionLabel, hintStyle)
                currentDoorHint = hintKey
            end
        elseif currentDoorHint then
            Framework.HideTextUI()
            currentDoorHint = nil
        end

        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and #vehicleDeleteZones > 0 then
            for _, zone in ipairs(vehicleDeleteZones) do
                local zoneVec = vector3(zone.coords.x, zone.coords.y, zone.coords.z)
                if #(playerCoords - zoneVec) < 10.0 then
                    tickInterval = 0
                    local vehModel = GetEntityModel(vehicle)
                    local validModel = false
                    for _, v in ipairs(zone.vehicles) do
                        if GetHashKey(v.model) == vehModel then
                            validModel = true
                            break
                        end
                    end
                    if validModel and IsControlJustPressed(0, 38) then
                        SafeDeleteEntity(vehicle)
                        Framework.Notify("Vehicle stored!", "success")
                    end
                end
            end
        end

        Wait(tickInterval)
    end
end)

RegisterNetEvent("plt_departments:client:SpawnK9")
AddEventHandler("plt_departments:client:SpawnK9", function(data)
    
    if currentK9 and type(currentK9) == "number" and DoesEntityExist(currentK9) then
        Framework.Notify("You already have a police dog!", "error")
        return
    end

    local nodeId     = data.nodeId
    local spawnCoords = nil

    for _, node in ipairs(DepartmentData.nodes) do
        if node.id == nodeId then
            spawnCoords = node.spawnCoords or node.coords
            break
        end
    end
    if not spawnCoords then return end

    local k9Config    = (Config and type(Config.K9) == "table") and Config.K9 or {}
    local modelName   = tostring(k9Config.Model or "a_c_shepherd")
    local modelHash   = GetHashKey(modelName)

    if not IsModelInCdimage(modelHash) then
        modelHash = GetHashKey("a_c_shepherd")
    end
    if not IsModelInCdimage(modelHash) then
        Framework.Notify(T("no_dog"), "error")
        return
    end

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(10) end

    currentK9 = CreatePed(28, modelHash,
        spawnCoords.x, spawnCoords.y, spawnCoords.z,
        spawnCoords.h or 0.0,
        true, true)

    SetEntityAsMissionEntity(currentK9, true, true)
    SetModelAsNoLongerNeeded(modelHash)
    SetBlockingOfNonTemporaryEvents(currentK9, true)
    SetPedKeepTask(currentK9, true)

    TriggerEvent("plt_departments:client:StartK9Follow")
    if PLTK9Target then PLTK9Target.Attach(currentK9) end
    Framework.Notify(T("dog_deployed"), "success")
end)

RegisterNetEvent("plt_departments:client:RemoveK9")
AddEventHandler("plt_departments:client:RemoveK9", function()
    if currentK9 and type(currentK9) == "number" and DoesEntityExist(currentK9) then
        if PLTK9Target then PLTK9Target.Detach(currentK9) end
        TriggerEvent("plt_departments:client:StopK9Follow")
        SafeDeleteEntity(currentK9)
        currentK9 = nil
        Framework.Notify(T("dog_returned"), "primary")
    else
        Framework.Notify(T("no_dog"), "error")
    end
end)

CreateThread(function()
    while true do
        local tickInterval = 1000

        if Framework.Type == "esx" then
            local ped         = PlayerPedId()
            if ped and ped ~= 0 then
                local playerCoords = GetEntityCoords(ped)

                for key, locationData in pairs(esxProximityPeds) do
                    local locationVec = vector3(locationData.coords.x, locationData.coords.y, locationData.coords.z)
                    local dist        = #(playerCoords - locationVec)

                    if dist < 50.0 then
                        
                        if not interactionPeds[key] then
                            interactionPeds[key] = "loading"
                            local model = locationData.model or 1581098148

                            CreateThread(function()
                                RequestModel(model)
                                local attempts = 0
                                while not HasModelLoaded(model) and attempts < 100 do
                                    Wait(10)
                                    attempts = attempts + 1
                                end

                                if HasModelLoaded(model) and interactionPeds[key] == "loading" then
                                    
                                    local existing = GetClosestPed(
                                        locationData.coords.x, locationData.coords.y, locationData.coords.z,
                                        1.2, false, false, false, false, -1)
                                    if existing ~= 0 and not IsPedAPlayer(existing) then
                                        SafeDeleteEntity(existing)
                                    end

                                    local spawnHeading = locationData.coords.h or 0.0
                                    local ped = CreatePed(4, model,
                                        locationData.coords.x, locationData.coords.y, locationData.coords.z,
                                        spawnHeading, false, false)

                                    if DoesEntityExist(ped) then
                                        SetEntityAsMissionEntity(ped, true, true)
                                        SetBlockingOfNonTemporaryEvents(ped, true)
                                        SetEntityInvincible(ped, true)
                                        SetPedCanRagdoll(ped, false)
                                        SetPedDefaultComponentVariation(ped)
                                        SetEntityVisible(ped, true, false)
                                        SetEntityAlpha(ped, 255, false)
                                        Wait(100)
                                        FreezeEntityPosition(ped, true)
                                        SetEntityHeading(ped, spawnHeading + 0.0)

                                        if interactionPeds[key] == "loading" then
                                            interactionPeds[key] = ped
                                            RegisterTargetZone(
                                                locationData.id,
                                                locationData.locType,
                                                locationData.coords,
                                                locationData.label,
                                                locationData.jobName,
                                                ped)
                                        else
                                            SafeDeleteEntity(ped)
                                        end
                                    else
                                        if interactionPeds[key] == "loading" then
                                            interactionPeds[key] = nil
                                        end
                                    end
                                else
                                    if interactionPeds[key] == "loading" then
                                        interactionPeds[key] = nil
                                    end
                                end
                                SetModelAsNoLongerNeeded(model)
                            end)
                        end

                    elseif dist > 60.0 then
                        
                        local existing = interactionPeds[key]
                        if existing and existing ~= "loading" then
                            SafeDeleteEntity(existing)
                            interactionPeds[key] = nil
                        end
                    end
                end
            end
        else
            tickInterval = 5000
        end

        Wait(tickInterval)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    RemoveMacintosh()
    RemoveK9Beds()
    RemoveInteractionPeds()
    ClearAllTargetZones()

    pcall(function()
        exports["pma-voice"]:setRadioChannel(0)
        exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
    end)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, blip in pairs(officerBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
