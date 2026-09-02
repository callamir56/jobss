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


local activeRadars    = {}   
local radarObjects    = {}   
local placementActive = false

local RADAR_MODEL = -6978462

function GetSpeedUnitLabel()
    local unit = tostring(Config.SpeedUnit or "kmh"):lower()
    return (unit == "mph") and "MPH" or "KM/H"
end

function GetSpeedMultiplier()
    local unit = tostring(Config.SpeedUnit or "kmh"):lower()
    return (unit == "mph") and 2.236936 or 3.6
end

function GetTargetSystem()
    if Config and Config.Target then
        local t = tostring(Config.Target):lower()
        if t == "qb-target" or t == "qb_target" then return "qb-target" end
        if t == "ox_target" or t == "ox-target" then return "ox_target" end
    end
    if GetResourceState("ox_target") == "started"  then return "ox_target"  end
    if GetResourceState("qb-target") == "started"   then return "qb-target"  end
    return "ox_target"
end

function RotationToDirection(rot)
    local rad = {
        x = math.pi / 180 * rot.x,
        y = math.pi / 180 * rot.y,
        z = math.pi / 180 * rot.z,
    }
    return {
        x = -math.sin(rad.z) * math.abs(math.cos(rad.x)),
        y =  math.cos(rad.z) * math.abs(math.cos(rad.x)),
        z =  math.sin(rad.x),
    }
end

function RaycastFromCamera(distance)
    local camRot   = GetGameplayCamRot(2)
    local camCoord = GetGameplayCamCoord()
    local dir      = RotationToDirection(camRot)

    local dest = vector3(
        camCoord.x + dir.x * distance,
        camCoord.y + dir.y * distance,
        camCoord.z + dir.z * distance
    )

    local ped    = PlayerPedId()
    local entity = ped
    if IsPedInAnyVehicle(ped, false) then
        entity = GetVehiclePedIsIn(ped, false)
    end

    local ray = _ENV["StartExpensiveSynchronousShapeTestLosProbe"](
        camCoord.x, camCoord.y, camCoord.z,
        dest.x, dest.y, dest.z,
        -1, entity, 0
    )

    local _, hit, hitCoords, _, hitEntity = GetShapeTestResult(ray)
    return hit, hitCoords, hitEntity
end

function DrawTextAtCoords(x, y, z, text)
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

function SafeDeleteEntity(entity)
    if entity and type(entity) == "number" and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

RegisterNetEvent("plt_departments:client:startRadarPlacement", function(deptId)
    if placementActive then return end
    placementActive = true

    CreateThread(function()
        RequestModel(RADAR_MODEL)
        while not HasModelLoaded(RADAR_MODEL) do Wait(0) end

        local previewObj = CreateObject(RADAR_MODEL, 0.0, 0.0, 0.0, false, false, false)
        SetEntityAlpha(previewObj, 150, false)
        SetEntityCollision(previewObj, false, false)

        local heading = 0.0

        while placementActive do
            Wait(0)

            local hit, hitCoords = RaycastFromCamera(100.0)

            if hit then
                SetEntityCoords(previewObj, hitCoords.x, hitCoords.y, hitCoords.z, false, false, false, false)
                SetEntityHeading(previewObj, heading)

                if IsControlPressed(0, 174) then heading = heading + 2.0 end
                if IsControlPressed(0, 175) then heading = heading - 2.0 end

                DrawTextAtCoords(hitCoords.x, hitCoords.y, hitCoords.z + 0.5, T("place_radar_help"))

                if IsControlJustPressed(0, 38) then
                    placementActive = false
                    SafeDeleteEntity(previewObj)
                    SetNuiFocus(true, true)
                    SendNUIMessage({
                        action    = "openRadarSetup",
                        speedUnit = GetSpeedUnitLabel(),
                        data      = {
                            deptId  = deptId,
                            coords  = { x = hitCoords.x, y = hitCoords.y, z = hitCoords.z },
                            heading = heading,
                        },
                    })
                    break
                end

                if IsControlJustPressed(0, 177) then
                    placementActive = false
                    SafeDeleteEntity(previewObj)
                    break
                end
            end
        end
    end)
end)

RegisterNUICallback("confirmRadarSetup", function(data, cb)
    SetNuiFocus(false, false)

    local name = data.name
    
    if not name or name == "" or name == "Mobile Radar" then
        local streetHash, crossingHash = GetStreetNameAtCoord(data.coords.x, data.coords.y, data.coords.z)
        name = GetStreetNameFromHashKey(streetHash)
        if crossingHash ~= 0 then
            name = name .. " / " .. GetStreetNameFromHashKey(crossingHash)
        end
    end

    TriggerServerEvent("plt_departments:server:registerRadar",
        data.coords, data.heading, data.limit, data.deptId, name)
    cb("ok")
end)

RegisterNUICallback("closeRadarSetup", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("removeRadar", function(data, cb)
    TriggerServerEvent("plt_departments:server:removeRadar", data.radarId)
    cb("ok")
end)

RegisterNUICallback("updateRadarField", function(data, cb)
    TriggerServerEvent("plt_departments:server:updateRadarField", data.radarId, data.field, data.value)
    cb("ok")
end)

RegisterNetEvent("plt_departments:client:syncRadars", function(radars)
    activeRadars = radars

    SendNUIMessage({
        action    = "syncData",
        radars    = radars,
        speedUnit = GetSpeedUnitLabel(),
    })

    for _, obj in pairs(radarObjects) do
        SafeDeleteEntity(obj)
    end
    radarObjects = {}

    RequestModel(RADAR_MODEL)

    local targetSystem = GetTargetSystem()

    for radarId, radarData in pairs(activeRadars) do
        local obj = CreateObject(
            RADAR_MODEL,
            radarData.coords.x, radarData.coords.y, radarData.coords.z,
            false, false, false
        )
        SetEntityHeading(obj, radarData.heading)
        FreezeEntityPosition(obj, true)
        radarObjects[radarId] = obj

        local function canInteract()
            return LocalPlayerJob and LocalPlayerJob.dept and LocalPlayerJob.dept ~= "none"
        end

        if targetSystem == "ox_target" then
            exports.ox_target:addLocalEntity(obj, {
                {
                    name        = "remove_radar_" .. radarId,
                    label       = T("deactivate_radar"),
                    icon        = "fas fa-trash",
                    distance    = 2.0,
                    canInteract = canInteract,
                    onSelect    = function()
                        TriggerServerEvent("plt_departments:server:removeRadar", radarId)
                    end,
                },
            })
        else
            exports["qb-target"]:AddTargetEntity(obj, {
                options = {
                    {
                        type        = "server",
                        event       = "plt_departments:server:removeRadar",
                        icon        = "fas fa-trash",
                        label       = T("deactivate_radar"),
                        radarId     = radarId,
                        canInteract = canInteract,
                    },
                },
                distance = 2.0,
            })
        end
    end
end)

CreateThread(function()
    local lastViolationTime = 0

    while true do
        local tickInterval = 1000

        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            
            if not (LocalPlayerJob and LocalPlayerJob.dept and LocalPlayerJob.dept ~= "none") then
                local playerCoords = GetEntityCoords(ped)

                for radarId, radarData in pairs(activeRadars) do
                    local radarPos = vector3(radarData.coords.x, radarData.coords.y, radarData.coords.z)
                    local dist     = #(playerCoords - radarPos)

                    if dist < 20.0 then
                        tickInterval = 100

                        local speed      = GetEntitySpeed(vehicle) * GetSpeedMultiplier()
                        local speedLimit = radarData.limit + 5   

                        if speed > speedLimit then
                            local now     = GetGameTimer()
                            local elapsed = now - lastViolationTime

                            if elapsed > 5000 then
                                lastViolationTime = now
                                TriggerServerEvent(
                                    "plt_departments:server:processRadarViolation",
                                    radarId,
                                    NetworkGetNetworkIdFromEntity(vehicle),
                                    speed
                                )
                            end
                        end
                    end
                end
            end
        end

        Wait(tickInterval)
    end
end)

RegisterNetEvent("plt_departments:client:playRadarFlash", function()
    StartScreenEffect("SuccessNeutral", 0, false)
    Wait(100)
    StopScreenEffect("SuccessNeutral")
end)

CreateThread(function()
    
    while true do
        local data = Framework.GetPlayerData()
        if data and data.citizenid then break end
        Wait(100)
    end

    Framework.TriggerCallback("plt_departments:server:getActiveRadars", function(radars)
        activeRadars = radars
        TriggerEvent("plt_departments:client:syncRadars", radars)
    end)
end)

