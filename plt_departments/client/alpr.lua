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


local alprOpen        = false   
local speedLockThresh = 80      
local alprActive      = false   
local boloList        = {}      
local lastScannedPlate = nil    
local lockedPlate      = "UNKNOWN"
local lockedAt         = 0      
local isScanning       = false  
local scanStartTime    = 0      
local nextAlertAllowed = 0      

local alprSizes    = { "normal", "small", "large" }
local alprSizeIdx  = 1

function GetSpeedUnitLabel()
    local unit = tostring(Config.SpeedUnit or "kmh"):lower()
    return (unit == "mph") and "MPH" or "KM/H"
end

function GetSpeedMultiplier()
    local unit = tostring(Config.SpeedUnit or "kmh"):lower()
    return (unit == "mph") and 2.236936 or 3.6
end

function GetVehicleSpeedConverted(vehicle)
    return math.floor(GetEntitySpeed(vehicle) * GetSpeedMultiplier())
end

RegisterNetEvent("plt_departments:client:SyncBolos", function(bolos)
    boloList = bolos
end)

function IsInAuthorizedALPRVehicle()
    local playerData = Framework.GetPlayerData()
    if not playerData then return false end

    if not (LocalPlayerJob and LocalPlayerJob.onDuty) then return false end

    local playerDept = (LocalPlayerJob and LocalPlayerJob.dept) or "none"
    local playerJob  = (playerData.job and playerData.job.name) or "none"

    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return false end

    local vehicleModel = GetEntityModel(vehicle)

    if not (DepartmentData and DepartmentData.nodes) then return false end

    for _, node in ipairs(DepartmentData.nodes) do
        if node.type == "vehicle" or node.type == "helipad" then
            local deptId = GetDepartmentForNode(node.id, DepartmentData)
            if deptId then
                local frameworkJob = GetFrameworkJobFromNodeId(deptId)

                local jobMatch  = tostring(deptId) == tostring(playerDept)
                if not jobMatch and LocalPlayerJob.dept ~= "none" then
                    jobMatch = tostring(LocalPlayerJob.dept) == tostring(deptId)
                end

                if jobMatch and node.vehicles then
                    for _, entry in ipairs(node.vehicles) do
                        if entry.model and entry.model ~= "" then
                            local hash = (type(entry.model) == "string")
                                and GetHashKey(entry.model)
                                or entry.model
                            if hash == vehicleModel then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

function GetVehicleInFront(vehicle)
    local origin  = GetEntityCoords(vehicle)
    local forward = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 50.0, 0.0)

    local ray = StartShapeTestRay(
        origin.x, origin.y, origin.z,
        forward.x, forward.y, forward.z,
        10, vehicle, 0
    )

    local _, hit, _, _, hitEntity = GetShapeTestResult(ray)

    if hit == 1 and IsEntityAVehicle(hitEntity) then
        return hitEntity
    end
    return nil
end

function ToggleALPR(arg)
    
    if not (LocalPlayerJob and LocalPlayerJob.dept and LocalPlayerJob.dept ~= "none") then
        return
    end

    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then
        Framework.Notify(T("alpr_vehicle_required"), "error")
        return
    end

    if not IsInAuthorizedALPRVehicle() then
        local msg
        if not (LocalPlayerJob and LocalPlayerJob.onDuty) then
            msg = "You must be ON DUTY to use ALPR systems!"
        elseif GetVehiclePedIsIn(PlayerPedId(), false) == 0 then
            msg = T("alpr_vehicle_required")
        else
            msg = "This vehicle is not equipped with ALPR systems!"
        end
        Framework.Notify(msg, "error")
        return
    end

    if arg then
        local numericArg = tonumber(arg)
        if numericArg then
            speedLockThresh = numericArg
            if not alprActive then
                alprActive = true
                alprOpen   = true
            end
            SendNUIMessage({
                action    = "openALPR",
                speedLock = speedLockThresh,
                speedUnit = GetSpeedUnitLabel(),
            })
            Framework.Notify(T("alpr_speed_set", { speed = numericArg, unit = GetSpeedUnitLabel() }), "success")
            return
        end

        local sizeArg = arg:lower()
        if sizeArg == "small" or sizeArg == "normal" or sizeArg == "large" then
            if not alprActive then
                alprActive = true
                alprOpen   = true
            end
            SendNUIMessage({ action = "setAlprSize", size = sizeArg })
            Framework.Notify(T("alpr_size_set", { size = sizeArg:upper() }), "success")
            return
        end
    end

    alprOpen = not alprOpen
    if alprOpen then
        alprActive = true
        SendNUIMessage({
            action    = "openALPR",
            speedLock = speedLockThresh,
            speedUnit = GetSpeedUnitLabel(),
        })
    else
        alprActive = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "closeALPR" })
    end
end

CreateThread(function()
    Wait(1000)
    local cmd = Config.OfficerCommands.alpr or "alpr"
    TriggerEvent("chat:addSuggestion", "/" .. cmd, "Toggle ALPR or Configure (Optional: [speed/size])", {
        { name = "parameter", help = "Speed (e.g. 80) or Size (small/normal/large)" },
    })
end)

RegisterCommand(Config.OfficerCommands.alprsize or "alprsize", function()
    if not alprActive then
        Framework.Notify(T("alpr_must_be_active"), "error")
        return
    end
    alprSizeIdx = alprSizeIdx + 1
    if alprSizeIdx > #alprSizes then alprSizeIdx = 1 end

    local size = alprSizes[alprSizeIdx]
    SendNUIMessage({ action = "setAlprSize", size = size })
    Framework.Notify(T("alpr_size_msg", { size = size:upper() }), "primary")
end, false)

RegisterCommand(Config.OfficerCommands.alpr or "alpr", function(source, args)
    ToggleALPR(args[1])
end, false)

RegisterCommand("!alpr_toggle", function()
    ToggleALPR()
end, false)

RegisterKeyMapping("!alpr_toggle", "Toggle ALPR System", "keyboard", "F11")

RegisterNUICallback("setSpeedLock", function(data, cb)
    speedLockThresh = tonumber(data.speed)
    cb("ok")
end)

RegisterNUICallback("closeALPR", function(data, cb)
    alprOpen   = false
    alprActive = false
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("closeAlprMove", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

CreateThread(function()
    while true do
        local tickInterval = 1000

        if alprActive then
            tickInterval = 200

            if IsInAuthorizedALPRVehicle() then
                local ped         = PlayerPedId()
                local myVehicle   = GetVehiclePedIsIn(ped, false)
                local mySpeed     = GetVehicleSpeedConverted(myVehicle)
                local targetVeh   = GetVehicleInFront(myVehicle)
                local targetSpeed = 0

                if targetVeh then
                    targetSpeed = GetVehicleSpeedConverted(targetVeh)
                    local plate = GetVehicleNumberPlateText(targetVeh)
                    lockedPlate = plate

                    if targetSpeed > speedLockThresh then
                        lastScannedPlate = plate  
                        lockedAt         = GetGameTimer()
                    end
                end

                local displayPlate  = lockedPlate
                local displayLocked = false
                if lastScannedPlate then
                    local elapsed = GetGameTimer() - lockedAt
                    if elapsed < 300000 then   
                        displayPlate  = lastScannedPlate
                        displayLocked = true
                    end
                end

                SendNUIMessage({
                    action      = "updateALPR",
                    mySpeed     = mySpeed,
                    targetSpeed = targetSpeed,
                    speedUnit   = GetSpeedUnitLabel(),
                    targetPlate = displayPlate,
                    isLocked    = displayLocked,
                })

                if targetVeh then
                    local rawPlate    = GetVehicleNumberPlateText(targetVeh)
                    local cleanPlate  = rawPlate:gsub("%s+", "")

                    if lastScannedPlate ~= cleanPlate then
                        
                        lastScannedPlate = cleanPlate
                        scanStartTime    = GetGameTimer()
                        isScanning       = true
                        SendNUIMessage({ action = "updateBoloScanner", plate = rawPlate, status = "SCANNING" })
                    elseif isScanning then
                        local scanElapsed = GetGameTimer() - scanStartTime
                        if scanElapsed >= 5000 then
                            isScanning = false
                            if Framework and Framework.TriggerCallback then
                                Framework.TriggerCallback("plt_departments:server:checkBolo", function(isBolo)
                                    
                                    if isBolo then
                                        local now = GetGameTimer()
                                        if now > nextAlertAllowed then
                                            PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", 1)
                                            nextAlertAllowed = now + 10000
                                        end
                                    end

                                    SendNUIMessage({
                                        action = "updateBoloScanner",
                                        plate  = rawPlate,
                                        isBolo = isBolo,
                                        status = isBolo and "WANTED" or "CLEAR",
                                    })
                                end, rawPlate)
                            end
                        end
                    end
                else
                    
                    if lastScannedPlate ~= nil then
                        lastScannedPlate = nil
                        isScanning       = false
                        SendNUIMessage({ action = "updateBoloScanner", plate = nil, isBolo = false, status = "READY" })
                    end
                end
            else
                
                alprActive = false
                alprOpen   = false
                SetNuiFocus(false, false)
                SendNUIMessage({ action = "closeALPR" })
            end
        end

        Wait(tickInterval)
    end
end)

