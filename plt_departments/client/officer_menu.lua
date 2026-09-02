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


local isMenuOpen        = false   
local isCuffedLocally   = false   
local cuffAnimDict      = "mp_arresting"
local cuffAnimClip      = "idle"
local isEnteringVehicle = false   
local isExitingVehicle  = false   
local isEscortActive    = false   
local lastVehicleHandle = 0       
local lastVehicleSeat   = nil     

local spawnableObjects = {
    spawn_cone    = -1036807324,
    spawn_barrier = -143315610,
    spawn_spikes  = -874338148,
    spawn_light   = -350795026,
}

local placedObjects    = {}
local isPlacingObject  = false
local ghostObject      = nil

function SafeDeleteEntity(handle)
    if handle and type(handle) == "number" and handle ~= 0 and DoesEntityExist(handle) then
        DeleteEntity(handle)
    end
end

function SetNuiFocusState(enabled)
    SetNuiFocus(enabled, enabled)
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(enabled)
    end
end

function GetSpeedUnitLabel()
    local unit = tostring(Config.SpeedUnit or "kmh"):lower()
    return unit == "mph" and "MPH" or "KM/H"
end

function SendLocaleToNui()
    SendNUIMessage({
        action       = "updateLocale",
        translations = PLTGetLocaleTable(),
        speedUnit    = GetSpeedUnitLabel(),
    })
end

function GetVehiclePlate(vehicle)
    local plate = ""
    if Framework and type(Framework.GetPlate) == "function" then
        plate = Framework.GetPlate(vehicle) or ""
    end
    if plate == "" then
        local raw = GetVehicleNumberPlateText(vehicle)
        if raw then
            plate = string.gsub(raw, "^%s*(.-)%s*$", "%1") or ""
        end
    end
    return plate
end

function GetVehicleColorName(colorIndex)
    local colors = {
        [0]   = "Black",
        [111] = "White",
        [88]  = "Yellow",
        [38]  = "Red",
        [27]  = "Blue",
        [50]  = "Pink",
        [49]  = "Dark Green",
    }
    return colors[colorIndex] or "Unknown"
end

function GetCurrentStreetLabel()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local hash1, hash2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(hash1)
    if hash2 ~= 0 then
        street = street .. " | " .. GetStreetNameFromHashKey(hash2)
    end
    return street, coords
end

function GetGameClockString()
    return string.format("%02d:%02d", GetClockHours(), GetClockMinutes())
end

function IsPlayerOfficer()
    return LocalPlayerJob and LocalPlayerJob.dept ~= "none"
end

function IsLocalPlayerCuffed()
    local state = LocalPlayer and LocalPlayer.state
    if not state then return isCuffedLocally end
    return isCuffedLocally or state.isCuffed or state.ishandcuffed
end

function IsStateBagCuffed(stateBag)
    if not stateBag then return false end
    return stateBag.isCuffed or stateBag.ishandcuffed
end

function GetTargetResource()
    local cfg = Config and Config.Target
    if cfg then
        local t = tostring(cfg):lower()
        if t then
            if t == "qb-target" or t == "qb_target" then return "qb-target" end
            if t == "ox_target" or t == "ox-target" then return "ox_target" end
        end
    end
    if GetResourceState("ox_target") == "started" then return "ox_target" end
    if GetResourceState("qb-target") == "started" then return "qb-target" end
    return "ox_target"
end

function IsLocalPlayerDeptJob(playerData)
    if not LocalPlayerJob or LocalPlayerJob.dept == "none" then return false end
    local data = playerData or Framework.GetPlayerData()
    if not data then return false end
    local deptStr = ""
    if type(GetFrameworkJobFromNodeId) == "function" then
        deptStr = tostring(GetFrameworkJobFromNodeId(LocalPlayerJob.dept) or ""):lower()
    end
    local jobName = (data.job and data.job.name) and tostring(data.job.name):lower() or ""
    if deptStr == "" or jobName == "" then return false end
    return deptStr == jobName
end

function ResolveRankLabel(fallback)
    if not (DepartmentData and DepartmentData.nodes) then return fallback end
    local dept = LocalPlayerJob.dept
    local rankNode = nil
    for _, link in ipairs(DepartmentData.links) do
        local linkedId = nil
        if link.from == dept then linkedId = link.to
        elseif link.to == dept then linkedId = link.from end
        if linkedId then
            for _, node in ipairs(DepartmentData.nodes) do
                if node.id == linkedId and node.type == "rank" then
                    rankNode = node
                    break
                end
            end
        end
        if rankNode then break end
    end
    if rankNode and rankNode.ranks then
        for _, rank in ipairs(rankNode.ranks) do
            if rank.level == LocalPlayerJob.grade then
                return rank.name
            end
        end
    end
    return fallback
end

function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

function LoadModel(model, maxIter)
    RequestModel(model)
    local iter = 0
    while not HasModelLoaded(model) do
        Wait(10)
        iter = iter + 1
        if maxIter and iter > maxIter then break end
    end
end

function SyncHandcuffState(state)
    if Framework.Type == "qb" then
        TriggerServerEvent("police:server:SetHandcuffState", state)
    else
        TriggerServerEvent("esx_policejob:handcuff", state)
    end
end

function FindFreeSeat(vehicle)
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = 1, maxSeats - 1 do
        if IsVehicleSeatFree(vehicle, seat) then return seat end
    end
    if IsVehicleSeatFree(vehicle, 0) then return 0 end
    return -1
end

function GetPedSeatInVehicle(vehicle, ped)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, seat) == ped then return seat end
    end
    return nil
end

function GetCuffedOrEscortedPlayerInVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return -1 end
    local firstSeen = -1
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local occupant = GetPedInVehicleSeat(vehicle, seat)
        if occupant ~= 0 and IsPedAPlayer(occupant) then
            local playerIndex = NetworkGetPlayerIndexFromPed(occupant)
            if playerIndex and playerIndex ~= -1 then
                local serverId = GetPlayerServerId(playerIndex)
                if serverId and serverId ~= -1 then
                    local bag = Player(serverId).state
                    if IsStateBagCuffed(bag) or bag.isEscorted then
                        return serverId
                    end
                    if firstSeen == -1 then firstSeen = serverId end
                end
            end
        end
    end
    return firstSeen
end

function EulerToForwardVector(rot)
    local rad = { x = rot.x * math.pi / 180, y = rot.y * math.pi / 180, z = rot.z * math.pi / 180 }
    return {
        x = -math.sin(rad.z) * math.abs(math.cos(rad.x)),
        y =  math.cos(rad.z) * math.abs(math.cos(rad.x)),
        z =  math.sin(rad.x),
    }
end

function GetCameraForwardRaycast(distance)
    local camRot    = GetGameplayCamRot(2)
    local camCoord  = GetGameplayCamCoord()
    local forward   = EulerToForwardVector(camRot)
    local endCoord  = vector3(
        camCoord.x + forward.x * distance,
        camCoord.y + forward.y * distance,
        camCoord.z + forward.z * distance
    )
    local ped       = PlayerPedId()
    local ignore    = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    local handle    = StartExpensiveSynchronousShapeTestLosProbe(
        camCoord.x, camCoord.y, camCoord.z,
        endCoord.x, endCoord.y, endCoord.z,
        -1, ignore, 0
    )
    local _, hit, coords, _, entity = GetShapeTestResult(handle)
    return hit, coords, entity
end

function PointToSegmentDistance(point, segA, segB)
    local ab = segB - segA
    local len = #ab
    if len == 0 then return #(point - segA) end
    local dir  = ab / len
    local ap   = point - segA
    local proj = ap.x * dir.x + ap.y * dir.y + ap.z * dir.z
    proj = math.max(0, math.min(len, proj))
    local closest = segA + dir * proj
    return #(point - closest)
end

function Notify(key, kind)
    Framework.Notify(T(key), kind)
end

function IsTargetActionEnabled(playerActions, vehicleActions, category, key)
    if category == "player" then
        return playerActions[key] ~= false
    elseif category == "vehicle" then
        return vehicleActions[key] ~= false
    end
    return true
end

function DrawWorldText(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local width = string.len(text) / 370
    DrawRect(0.0, 0.0125, 0.017 + width, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function CloseOfficerMenu(force)
    if force or isMenuOpen then
        isMenuOpen = false
        SetNuiFocusState(false)
        SendNUIMessage({ action = "closeOfficerMenu" })
    end
end

function OpenOfficerMenu(playerData)
    if not playerData then
        playerData = Framework.GetPlayerData()
    end
    if not playerData then return end
    if not IsLocalPlayerDeptJob(playerData) then return end

    local rankLabel = playerData.job and playerData.job.gradeLabel or "Officer"
    rankLabel = ResolveRankLabel(rankLabel)

    local tabs = Config.OfficerMenuTabs or {}
    local enabledTabs = {
        interaction = tabs.interaction ~= false,
        radio       = tabs.radio ~= false,
        frequency   = tabs.frequency ~= false,
        objects     = tabs.objects ~= false,
        vehicles    = tabs.vehicles ~= false,
        poses       = tabs.poses ~= false,
    }

    local fakePlayers = (Config.ShowFakePlayers and Config.FakePlayers) or nil

    isMenuOpen = true
    SetNuiFocusState(true)
    SendLocaleToNui()
    SendNUIMessage({
        action      = "openOfficerMenu",
        playerName  = playerData.name,
        myCitizenId = playerData.citizenid,
        rankLabel   = rankLabel,
        radioCodes  = Config.RadioCodes,
        animations  = Config.Animations,
        tabs        = enabledTabs,
        fakePlayers = fakePlayers,
    })
end

function ToggleOfficerMenu(forceClose)
    if forceClose then
        CloseOfficerMenu(true)
        return
    end
    if isMenuOpen then
        CloseOfficerMenu(true)
    else
        OpenOfficerMenu()
    end
end

exports("isOfficerMenuOpen",    function() return isMenuOpen end)
exports("OpenOfficerMenu",      function() if not isMenuOpen then OpenOfficerMenu() end end)
exports("ToggleOfficerMenu",    function(v) ToggleOfficerMenu(v) end)
exports("IsPlayerCuffed",       function() return IsLocalPlayerCuffed() end)

exports("BreakCuffs", function(opts)
    if not IsLocalPlayerCuffed() then return false end
    opts = (type(opts) == "table" and opts) or {}
    local silent = opts.silent == true
    local ped    = PlayerPedId()

    isCuffedLocally = false
    LocalPlayer.state:set("isCuffed",      false, true)
    LocalPlayer.state:set("ishandcuffed",  false, true)
    lastVehicleHandle = 0
    lastVehicleSeat   = nil

    SetPedConfigFlag(ped, 184, false)
    ClearPedTasksImmediately(ped)
    SyncHandcuffState(false)

    if not silent then
        Notify("you_were_uncuffed", "success")
    end
    return true
end)

exports("RequestCuffPlayer", function(targetServerId, isBehind, isKneeling)
    TriggerServerEvent("plt_departments:server:CuffPlayer",
        targetServerId, isBehind == true, isKneeling == true, "cuff")
end)

exports("RequestUncuffPlayer", function(targetServerId, isBehind)
    TriggerServerEvent("plt_departments:server:CuffPlayer",
        targetServerId, isBehind == true, false, "uncuff")
end)

exports("RequestToggleCuffPlayer", function(targetServerId, isBehind, isKneeling)
    TriggerServerEvent("plt_departments:server:CuffPlayer",
        targetServerId, isBehind == true, isKneeling == true)
end)

exports("RequestSeizeVehicle", function(vehicle, reason, price)
    if not DoesEntityExist(vehicle) then return end
    TriggerServerEvent("plt_departments:server:seizeVehicle",
        NetworkGetNetworkIdFromEntity(vehicle),
        reason or "No reason provided",
        price  or 0)
end)

RegisterKeyMapping("officermenu", "Open Officer Menu", "keyboard", "F6")

RegisterCommand("officermenu", function()
    ToggleOfficerMenu()
end, false)

RegisterNUICallback("closeOfficerMenu", function(_, cb)
    isMenuOpen = false
    SetNuiFocusState(false)
    cb("ok")
end)

RegisterNUICallback("closeFineInput", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("closeSeizeInput", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("closeJailInput", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("submitSeize", function(data, cb)
    SetNuiFocus(false, false)
    if data.vehNetId and data.reason and data.price then
        TriggerServerEvent("plt_departments:server:seizeVehicle",
            data.vehNetId, data.reason, data.price)
    end
    cb("ok")
end)

RegisterNUICallback("submitJail", function(data, cb)
    SetNuiFocus(false, false)
    local targetId = tonumber(data.targetId)
    local minutes  = tonumber(data.minutes)
    local reason   = tostring(data.reason or ""):gsub("^%s*(.-)%s*$", "%1")

    local maxMin = tonumber((Config.Jail or {}).MaxMinutes) or 60
    local minMin = tonumber((Config.Jail or {}).MinMinutes) or 0
    if maxMin < 0 then maxMin = 0 end

    if targetId and minutes and reason ~= "" then
        minutes = math.max(minMin, math.min(maxMin, minutes))
        TriggerServerEvent("plt_departments:server:JailPlayer",
            targetId, math.floor(minutes), reason)
    end
    cb("ok")
end)

RegisterNUICallback("submitFine", function(data, cb)
    SetNuiFocus(false, false)
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local street = GetCurrentStreetLabel()

    local nearVehicleInfo = nil
    local closestVeh = Framework.GetClosestVehicle(coords)
    if closestVeh and closestVeh ~= 0 then
        local dist = #(coords - GetEntityCoords(closestVeh))
        if dist < 5.0 then
            local plate     = GetVehiclePlate(closestVeh)
            local model     = GetDisplayNameFromVehicleModel(GetEntityModel(closestVeh))
            local color1, _ = GetVehicleColours(closestVeh)
            nearVehicleInfo = { plate = plate, model = model, color = GetVehicleColorName(color1) }
        end
    end

    if data.targetId and data.reason and data.amount then
        TriggerServerEvent("plt_departments:server:SendCitation",
            data.targetId, data.reason, data.amount, street, nearVehicleInfo)
    end
    cb("ok")
end)

RegisterNUICallback("payCitation", function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent("plt_departments:server:PayCitation", data.amount, data.officerSource)
    cb("ok")
end)

RegisterNUICallback("declineCitation", function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent("plt_departments:server:DeclineCitation", data.amount, data.officerSource)
    cb("ok")
end)

RegisterNUICallback("closeCitation", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("officerAction", function(data, cb)
    DispatchOfficerAction(data.action, data)
    cb("ok")
end)

function RequireOfficerPermission(action)
    if not IsLocalPlayerDeptJob() then
        Notify("no_command_permission", "error")
        return false
    end
    return true
end

function ExecuteOfficerCommand(action)
    if not RequireOfficerPermission(action) then return end
    DispatchOfficerAction(action, {})
end

function BlockIfCuffed()
    if IsLocalPlayerCuffed() then
        Notify("cannot_while_cuffed", "error")
        return true
    end
    return false
end

function GetClosestPlayerChecked(maxDist)
    local playerIndex, dist = Framework.GetClosestPlayer()
    if playerIndex == -1 or dist >= maxDist then
        Notify("no_one_nearby", "error")
        return nil
    end
    return playerIndex, dist
end

function IsTargetKneeling(targetPed)
    for _, flags in ipairs({3, 1, 49}) do
        if IsEntityPlayingAnim(targetPed, "cartoonkneelsur@animation", "cartoonkneelsur_clip", flags) then
            return true
        end
    end
    return false
end

function IsTargetFacingAway(targetPed)
    local targetCoords  = GetEntityCoords(targetPed)
    local myCoords      = GetEntityCoords(PlayerPedId())
    local forward       = GetEntityForwardVector(targetPed)
    local delta         = targetCoords - myCoords
    local dot           = forward.x * delta.x + forward.y * delta.y
    return dot <= 0
end

function DispatchOfficerAction(action, data)
    
    local cuffBlockedActions = {
        cuff = true, search_person = true, escort = true,
        put_car = true, out_car = true,
    }
    if cuffBlockedActions[action] and BlockIfCuffed() then return end

    if action == "cuff" then
        local pi = GetClosestPlayerChecked(3.0)
        if not pi then return end
        local targetPed = GetPlayerPed(pi)
        TriggerServerEvent("plt_departments:server:CuffPlayer",
            GetPlayerServerId(pi),
            IsTargetFacingAway(targetPed),
            IsTargetKneeling(targetPed))

    elseif action == "search_person" then
        local pi = GetClosestPlayerChecked(3.0)
        if not pi then return end
        TriggerServerEvent("plt_departments:server:SearchPlayer", GetPlayerServerId(pi))

    elseif action == "escort" then
        local pi = GetClosestPlayerChecked(3.0)
        if not pi then return end
        local serverId = GetPlayerServerId(pi)
        local bag      = Player(serverId).state
        if IsStateBagCuffed(bag) then
            StartEscortPed(GetPlayerPed(pi), pi)
        else
            Notify("must_be_handcuffed", "error")
        end

    elseif action == "put_car" then
        local pi = GetClosestPlayerChecked(3.0)
        if not pi then return end
        local serverId = GetPlayerServerId(pi)
        if not IsStateBagCuffed(Player(serverId).state) then
            Notify("must_be_handcuffed", "error")
            return
        end
        local myCoords = GetEntityCoords(PlayerPedId())
        local veh      = Framework.GetClosestVehicle(myCoords)
        if not veh or veh == 0 then
            Notify("no_vehicle_nearby", "error")
            return
        end
        if #(myCoords - GetEntityCoords(veh)) >= 5.0 then
            Notify("no_vehicle_nearby", "error")
            return
        end
        local seat = FindFreeSeat(veh)
        if seat == -1 then
            Notify("no_free_seats", "error")
            return
        end
        TriggerServerEvent("plt_departments:server:setPlayerEscort",
            serverId, false, VehToNet(veh), seat)

    elseif action == "out_car" then
        local targetServerId = -1
        local myCoords       = GetEntityCoords(PlayerPedId())
        local veh            = Framework.GetClosestVehicle(myCoords)
        if veh and veh ~= 0 and #(myCoords - GetEntityCoords(veh)) < 6.0 then
            targetServerId = GetCuffedOrEscortedPlayerInVehicle(veh)
        end
        if targetServerId == -1 then
            local pi, dist = Framework.GetClosestPlayer()
            if pi ~= -1 and dist < 3.0 then
                local tPed = GetPlayerPed(pi)
                if tPed ~= 0 and IsPedInAnyVehicle(tPed, false) then
                    targetServerId = GetPlayerServerId(pi)
                end
            end
        end
        if targetServerId ~= -1 then
            TriggerServerEvent("plt_departments:server:setPlayerEscort",
                targetServerId, false, nil, nil, true)
        else
            Notify("no_one_nearby", "error")
        end

    elseif action == "fine" then
        local pi = GetClosestPlayerChecked(3.0)
        if not pi then return end
        local serverId = GetPlayerServerId(pi)
        SetNuiFocus(true, true)
        SendLocaleToNui()
        SendNUIMessage({ action = "openFineInput", targetServerId = serverId })

    elseif action == "jail" then
        local pi, dist = Framework.GetClosestPlayer()
        local maxDist  = tonumber((Config.Jail or {}).MaxDistance) or 2.0
        if pi == -1 or dist >= maxDist then
            Notify("no_one_nearby", "error")
            return
        end
        local serverId = GetPlayerServerId(pi)
        local maxMin   = tonumber((Config.Jail or {}).MaxMinutes) or 60
        if maxMin < 0 then maxMin = 0 end
        SetNuiFocus(true, true)
        SendLocaleToNui()
        SendNUIMessage({ action = "openJailInput", targetServerId = serverId, maxMinutes = maxMin })

    elseif action == "check_plate" then
        ActionCheckPlate()

    elseif action == "unlock" then
        local veh = Framework.GetClosestVehicle()
        if veh == 0 then
            Notify("no_vehicle_nearby", "error")
            return
        end
        Framework.Progressbar("unlock_veh", T("unlock_vehicle"), 10000, false, true,
            { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
            { animDict = "veh@break_in@0h@p_m_one@", anim = "low_force_entry_ds", flags = 16 },
            {}, {},
            function()
                SetVehicleDoorsLocked(veh, 1)
                SetVehicleDoorsLockedForAllPlayers(veh, false)
                Notify("vehicle_unlocked", "success")
            end,
            function() Notify("cancelled", "error") end
        )

    elseif action == "seize" then
        local veh = Framework.GetClosestVehicle()
        if veh == 0 then
            Notify("no_vehicle_nearby", "error")
            return
        end
        SetNuiFocus(true, true)
        SendLocaleToNui()
        SendNUIMessage({ action = "openSeizeInput", vehNetId = NetworkGetNetworkIdFromEntity(veh) })

    elseif action == "alpr_toggle" then
        ExecuteCommand(Config.OfficerCommands.alpr or "alpr")

    elseif action == "alpr_set_speed" then
        if data.speed then
            ExecuteCommand((Config.OfficerCommands.alpr or "alpr") .. " " .. tostring(data.speed))
        end

    elseif action == "alpr_move" then
        CloseOfficerMenu(true)
        ExecuteCommand(Config.OfficerCommands.alprsize or "alprsize")

    elseif action == "remove_object" then
        ActionRemoveNearestObject()

    elseif action == "clear_objects" then
        ActionClearAllObjects()

    elseif action == "stop_poses" then
        exports.plt_departments:StopAnimation()

    else
        
        if spawnableObjects[action] then
            BeginObjectPlacement(action)
            return
        end
        
        local poseName = action:match("^pose_(.*)")
        if poseName then
            exports.plt_departments:PlayPose(poseName)
            return
        end
        
        if action:find("CODE%-") or action:find("10%-") then
            ActionSendRadioCode(action)
        end
    end
end

local function RegisterOfficerCommand(configKey, actionKey, defaultCmd)
    local cmd = (Config.OfficerCommands and Config.OfficerCommands[configKey]) or defaultCmd
    RegisterCommand(cmd, function() ExecuteOfficerCommand(actionKey) end, false)
end

RegisterOfficerCommand("search",       "search_person", "searchperson")
RegisterOfficerCommand("cuff",         "cuff",          "cuff")
RegisterOfficerCommand("escort",       "escort",        "escort")
RegisterOfficerCommand("putinvehicle", "put_car",       "putinvehicle")
RegisterOfficerCommand("outofvehicle", "out_car",       "outofvehicle")
RegisterOfficerCommand("plate",        "check_plate",   "plate")
RegisterOfficerCommand("seize",        "seize",         "seize")

function ActionCheckPlate()
    local ped      = PlayerPedId()
    local coords   = GetEntityCoords(ped)
    local targetVeh = 0

    local currentVeh = GetVehiclePedIsIn(ped, false)
    if currentVeh ~= 0 then
        local vehCoords = GetEntityCoords(currentVeh)
        local frontCoords = GetOffsetFromEntityInWorldCoords(currentVeh, 0.0, 15.0, 0.0)
        local handle = StartShapeTestRay(
            vehCoords.x, vehCoords.y, vehCoords.z,
            frontCoords.x, frontCoords.y, frontCoords.z,
            10, currentVeh, 0)
        local _, hit, _, _, hitEntity = GetShapeTestResult(handle)
        if hit == 1 and IsEntityAVehicle(hitEntity) then
            targetVeh = hitEntity
        else
            targetVeh = currentVeh
        end
    end

    if not targetVeh or targetVeh == 0 or targetVeh == -1 then
        local camCoord = GetGameplayCamCoord()
        local camRot   = GetGameplayCamRot(2)
        local forward  = EulerToForwardVector(camRot)
        local endPt    = camCoord + vector3(forward.x, forward.y, forward.z) * 10.0
        local handle   = StartShapeTestRay(
            camCoord.x, camCoord.y, camCoord.z,
            endPt.x, endPt.y, endPt.z,
            10, ped, 0)
        local _, hit, _, _, hitEntity = GetShapeTestResult(handle)
        if hit == 1 and IsEntityAVehicle(hitEntity) then targetVeh = hitEntity end
    end

    if not targetVeh or targetVeh == 0 or targetVeh == -1 then
        local frontPt = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.0)
        local handle  = StartShapeTestRay(
            coords.x, coords.y, coords.z,
            frontPt.x, frontPt.y, frontPt.z,
            10, ped, 0)
        local _, hit, _, _, hitEntity = GetShapeTestResult(handle)
        if hit == 1 and IsEntityAVehicle(hitEntity) then targetVeh = hitEntity end
    end

    if not targetVeh or targetVeh == 0 or targetVeh == -1 then
        targetVeh = Framework.GetClosestVehicle(coords)
    end

    if targetVeh and targetVeh ~= 0 and targetVeh ~= -1 then
        CloseOfficerMenu(true)
        CheckPlateOnVehicle(targetVeh, GetVehiclePlate(targetVeh))
    else
        Notify("no_vehicle_nearby", "error")
    end
end

function ActionRemoveNearestObject()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local bestObj, bestIdx, bestDist = 0, -1, 3.0

    for i, obj in ipairs(placedObjects) do
        if DoesEntityExist(obj) then
            local d = #(coords - GetEntityCoords(obj))
            if d < bestDist then
                bestDist = d
                bestObj  = obj
                bestIdx  = i
            end
        end
    end

    if bestObj ~= 0 then
        SafeDeleteEntity(bestObj)
        table.remove(placedObjects, bestIdx)
        Notify("object_removed", "success")
    else
        Notify("no_objects_nearby", "error")
    end
end

function ActionClearAllObjects()
    for _, obj in ipairs(placedObjects) do SafeDeleteEntity(obj) end
    placedObjects = {}
    Notify("all_objects_cleared", "success")
end

function ActionSendRadioCode(code)
    local playerData = Framework.GetPlayerData()
    if not playerData then return end

    local street, coords = GetCurrentStreetLabel()
    local clockStr       = GetGameClockString()

    local label = code
    for _, entry in ipairs(Config.RadioCodes) do
        if entry.code == code then label = entry.label; break end
    end

    TriggerServerEvent("plt_departments:server:createDispatchCall", {
        code     = code,
        title    = label,
        location = street,
        coords   = coords,
        time     = clockStr,
        isRadio  = true,
        info     = "Officer " .. playerData.name .. " reported " .. label .. ".",
    })
    Framework.Notify(T("status_updated", { status = label }), "success")
end

function CheckPlateOnVehicle(vehicle, plate)
    if not vehicle or vehicle == 0 then return end
    CreateThread(function()
        local ped       = PlayerPedId()
        local animDict  = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
        local animClip  = "base"
        local tabletHash = -1585232418

        LoadAnimDict(animDict)
        LoadModel(tabletHash, 100)

        TaskPlayAnim(ped, animDict, animClip, 8.0, 8.0, -1, 49, 0, false, false, false)

        local tabletCoords = GetEntityCoords(ped)
        local tabletObj    = CreateObject(tabletHash,
            tabletCoords.x, tabletCoords.y, tabletCoords.z, false, false, false)

        local boneIdx = GetPedBoneIndex(ped, 28422)
        AttachEntityToEntity(tabletObj, ped, boneIdx,
            0.0, 0.0, 0.03, 0.0, 0.0, 0.0,
            true, true, false, true, 1, true)

        Framework.Notify(T("connecting_dmv"), "primary")
        FreezeEntityPosition(ped, true)

        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 5000 do
            for _, ctrl in ipairs({30,31,32,33,34,35,24,257,25,263,21,22,44,140,141,142}) do
                DisableControlAction(0, ctrl, true)
            end
            if not IsEntityPlayingAnim(ped, animDict, animClip, 3) then
                TaskPlayAnim(ped, animDict, animClip, 8.0, 8.0, -1, 49, 0, false, false, false)
            end
            Wait(0)
        end

        FreezeEntityPosition(ped, false)
        StopAnimTask(ped, animDict, animClip, 1.0)
        SafeDeleteEntity(tabletObj)

        Framework.TriggerCallback("plt_departments:server:getVehicleInfo", function(info)
            if info then
                SendNUIMessage({
                    action = "showNotification",
                    title  = T("vehicle_registration"),
                    items  = {
                        { label = T("plate"),  value = info.plate },
                        { label = T("owner"),  value = info.owner:upper() },
                        { label = T("status"), value = T("valid") },
                    },
                })
            else
                SendNUIMessage({
                    action = "showNotification",
                    title  = T("plate_check_failed"),
                    items  = {
                        { label = T("plate"),  value = plate },
                        { label = T("owner"),  value = T("unknown_no_reg") },
                        { label = T("alert"),  value = T("not_in_database") },
                    },
                })
            end
        end, plate)
    end)
end

RegisterNetEvent("plt_departments:client:CheckPlateTarget")
AddEventHandler("plt_departments:client:CheckPlateTarget", function(vehicle, plate)
    CheckPlateOnVehicle(vehicle, plate)
end)

function BeginObjectPlacement(objectKey)
    local modelHash = spawnableObjects[objectKey]
    if not modelHash then return end

    if isPlacingObject then SafeDeleteEntity(ghostObject) end

    isPlacingObject = true
    CloseOfficerMenu(true)
    SendNUIMessage({
        action       = "togglePlacementHelp",
        visible      = true,
        header       = T("object_placement_header"),
        confirmLabel = T("place_object"),
        rotateLabel  = T("rotate_object"),
    })

    LoadModel(modelHash)

    local ped      = PlayerPedId()
    local origin   = GetEntityCoords(ped)
    ghostObject    = CreateObject(modelHash, origin.x, origin.y, origin.z, false, true, false)
    SetEntityAlpha(ghostObject, 150, false)
    SetEntityCollision(ghostObject, false, false)

    local heading = GetEntityHeading(ped)

    CreateThread(function()
        while isPlacingObject do
            local hit, hitCoords, _ = GetCameraForwardRaycast(100.0)
            if hit then
                SetEntityCoords(ghostObject, hitCoords.x, hitCoords.y, hitCoords.z)
                PlaceObjectOnGroundProperly(ghostObject)
                SetEntityHeading(ghostObject, heading)
            end

            if IsControlPressed(0, 174) then heading = (heading + 2.0) % 360.0
            elseif IsControlPressed(0, 175) then heading = (heading - 2.0 + 360.0) % 360.0 end

            local pedCoords  = GetEntityCoords(PlayerPedId())
            local distToGhost = hitCoords and #(pedCoords - hitCoords) or 999.0

            if distToGhost > 5.0 then
                SetEntityDrawOutline(ghostObject, true)
                SetEntityDrawOutlineColor(255, 0, 0, 255)
            else
                SetEntityDrawOutline(ghostObject, false)
            end

            if IsControlJustPressed(0, 38) then
                if distToGhost <= 5.0 then
                    local ghostCoords   = GetEntityCoords(ghostObject)
                    local ghostHeading  = GetEntityHeading(ghostObject)
                    SafeDeleteEntity(ghostObject)

                    local placed = CreateObject(modelHash,
                        ghostCoords.x, ghostCoords.y, ghostCoords.z, true, true, true)
                    PlaceObjectOnGroundProperly(placed)
                    SetEntityHeading(placed, ghostHeading)
                    SetEntityInvincible(placed, true)
                    FreezeEntityPosition(placed, true)
                    table.insert(placedObjects, placed)

                    isPlacingObject = false
                    ghostObject     = nil
                    Notify("object_placed", "success")
                    SendNUIMessage({ action = "togglePlacementHelp", visible = false })
                else
                    Notify("too_far_away", "error")
                end
            end

            if IsControlJustPressed(0, 47) or IsControlJustPressed(0, 177) then
                SafeDeleteEntity(ghostObject)
                isPlacingObject = false
                ghostObject     = nil
                Notify("placement_cancelled", "error")
                SendNUIMessage({ action = "togglePlacementHelp", visible = false })
            end

            Wait(0)
        end
    end)
end

function StartEscortPed(targetPed, playerIndex)
    TriggerServerEvent("plt_departments:server:setPlayerEscort",
        GetPlayerServerId(playerIndex), nil, false, false)
    LocalPlayer.state:set("blockHandsUp", false, true)
    StopAnimTask(PlayerPedId(),
        "amb@world_human_drinking@coffee@female@base", "base", 2.0)
end

function StopEscortingPlayer(targetServerId, extra)
    TriggerServerEvent("plt_departments:server:setPlayerEscort",
        targetServerId, false, nil, nil, extra)
    LocalPlayer.state:set("blockHandsUp", false, true)
    StopAnimTask(PlayerPedId(),
        "amb@world_human_drinking@coffee@female@base", "base", 2.0)
end

RegisterNetEvent("plt_departments:client:StartOfficerEscort")
AddEventHandler("plt_departments:client:StartOfficerEscort", function()
    local ped      = PlayerPedId()
    local animDict = "amb@world_human_drinking@coffee@female@base"
    LoadAnimDict(animDict)
    TaskPlayAnim(ped, animDict, "base", 8.0, 8.0, -1, 51, 0, false, false, false)
end)

RegisterNetEvent("plt_departments:client:StopOfficerEscort")
AddEventHandler("plt_departments:client:StopOfficerEscort", function()
    StopAnimTask(PlayerPedId(),
        "amb@world_human_drinking@coffee@female@base", "base", 2.0)
end)

local isDoorAnimating = false
AddEventHandler("CEventOpenDoor", function()
    if not LocalPlayer.state.blockHandsUp then return end
    if isDoorAnimating then return end
    isDoorAnimating = true
    while IsPedOpeningADoor(PlayerPedId()) do Wait(100) end
    isDoorAnimating = false
    if LocalPlayer.state.blockHandsUp then
        StopEscortingPlayer(nil, true)
    end
end)

function RunEscortWalkLoop(targetServerId)
    local walkDict  = "anim@move_m@prisoner_cuffed"
    local runDict   = "anim@move_m@trash"
    local arrestDict = "mp_arresting"
    local ped       = PlayerPedId()

    while isEscortActive do
        local playerIndex = GetPlayerFromServerId(targetServerId)
        local targetPed   = playerIndex > 0 and GetPlayerPed(playerIndex)
        if not targetPed then break end

        if not IsEntityAttachedToEntity(ped, targetPed) then
            AttachEntityToEntity(ped, targetPed, 11816,
                0.38, 0.4, 0.0, 0.0, 0.0, 0.0,
                false, false, true, true, 2, true)
        end

        if IsPedWalking(targetPed) then
            if not IsEntityPlayingAnim(ped, walkDict, "walk", 3) then
                LoadAnimDict(walkDict)
                LoadAnimDict(arrestDict)
                TaskPlayAnim(ped, walkDict, "walk",   8.0, -8, -1, 1,  0.0, false, false, false)
                TaskPlayAnim(ped, arrestDict, "idle", 8.0, -8, -1, 49, 0.0, false, false, false)
            end
        elseif IsPedRunning(targetPed) or IsPedSprinting(targetPed) then
            if not IsEntityPlayingAnim(ped, runDict, "run", 3) then
                LoadAnimDict(runDict)
                LoadAnimDict(arrestDict)
                TaskPlayAnim(ped, runDict,    "run",  8.0, -8, -1, 1,  0.0, false, false, false)
                TaskPlayAnim(ped, arrestDict, "idle", 8.0, -8, -1, 49, 0.0, false, false, false)
            end
        else
            if not IsEntityPlayingAnim(ped, arrestDict, "idle", 3) then
                LoadAnimDict(arrestDict)
                TaskPlayAnim(ped, arrestDict, "idle", 8.0, -8, -1, 49, 0.0, false, false, false)
            end
            StopAnimTask(ped, walkDict, "walk", -8.0)
            StopAnimTask(ped, runDict,  "run",  -8.0)
        end

        Wait(0)
    end

    RemoveAnimDict(walkDict)
    RemoveAnimDict(runDict)
    RemoveAnimDict(arrestDict)
end

local myPlayerBagKey = string.format("player:%s", GetPlayerServerId(PlayerId()))
AddStateBagChangeHandler("isEscorted", myPlayerBagKey, function(_, _, newValue)
    isEscortActive = newValue
    local ped = PlayerPedId()

    if IsEntityAttached(ped) then
        DetachEntity(ped, true, false)
        StopAnimTask(ped, "anim@move_m@prisoner_cuffed", "walk", -8.0)
        StopAnimTask(ped, "anim@move_m@trash", "run", -8.0)
    end

    if newValue then
        CreateThread(function() RunEscortWalkLoop(newValue) end)
    end
end)

RegisterNetEvent("plt_departments:client:setInVehicle")
AddEventHandler("plt_departments:client:setInVehicle", function(vehNetId, seat)
    local veh = NetToVeh(vehNetId)
    if not DoesEntityExist(veh) then return end

    local ped = PlayerPedId()
    isEnteringVehicle = true
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, veh, 10000, seat, 1.0, 1, 0)

    CreateThread(function()
        local tries = 0
        while not IsPedInAnyVehicle(ped, false) and tries < 100 do
            Wait(100)
            tries = tries + 1
        end
        isEnteringVehicle = false
        if not IsPedInAnyVehicle(ped, false) then
            SetPedIntoVehicle(ped, veh, seat)
        end
    end)
end)

RegisterNetEvent("plt_departments:client:exitVehicle")
AddEventHandler("plt_departments:client:exitVehicle", function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end

    local veh = GetVehiclePedIsIn(ped, false)
    isExitingVehicle = true

    if IsEntityAttached(ped) then DetachEntity(ped, true, true) end
    ClearPedTasks(ped)
    TaskLeaveVehicle(ped, veh, 16)

    CreateThread(function()
        local tries = 0
        while IsPedInAnyVehicle(ped, false) and tries < 60 do
            Wait(100)
            tries = tries + 1
        end
        if IsPedInAnyVehicle(ped, false) then
            ClearPedTasksImmediately(ped)
            local offset = GetOffsetFromEntityInWorldCoords(veh, 1.2, -2.0, 0.2)
            SetEntityCoords(ped, offset.x, offset.y, offset.z, false, false, false, false)
        end
        isExitingVehicle = false
    end)
end)

RegisterNetEvent("plt_departments:client:TeleportToCoords")
AddEventHandler("plt_departments:client:TeleportToCoords", function(coords)
    if not coords then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not (x and y and z) then return end
    local h = tonumber(coords.h) or GetEntityHeading(ped)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, h)
end)

RegisterNetEvent("plt_departments:client:ShowCitation")
AddEventHandler("plt_departments:client:ShowCitation", function(data)
    SendNUIMessage({ action = "showCitation", data = data })
    SetTimeout(200, function() SetNuiFocus(true, true) end)
end)

function FindValidCuffClip(animDict, candidates)
    for _, clip in ipairs(candidates) do
        if GetAnimDuration(animDict, clip) > 0 then return clip end
    end
    return candidates[#candidates]
end

RegisterNetEvent("plt_departments:client:GetCuffed")
AddEventHandler("plt_departments:client:GetCuffed", function(officerServerId, isStandingCuff)
    local ped = PlayerPedId()

    if isCuffedLocally then
        
        isCuffedLocally = false
        LocalPlayer.state:set("isCuffed", false, true)
        lastVehicleHandle = 0
        lastVehicleSeat   = nil
        SetPedConfigFlag(ped, 184, false)

        if isStandingCuff then
            ClearPedTasks(ped)
        else
            LoadAnimDict("mp_arresting")
            TaskPlayAnim(ped, "mp_arresting", "b_uncuff",
                8.0, -8.0, -1, 33, 0.0, false, false, false)
            Wait(2500)
            ClearPedTasks(ped)
        end

        SyncHandcuffState(false)
        Notify("you_were_uncuffed", "success")
    else
        
        isCuffedLocally = true
        LocalPlayer.state:set("isCuffed", true, true)

        local dict, clip
        if isStandingCuff then
            dict = "anim@move_m@prisoner_cuffed"
            clip = "idle"
        else
            dict = "cuffed@pluto"
            clip = "cuffing_clip"
        end

        LoadAnimDict(dict)

        if not isStandingCuff then
            clip = FindValidCuffClip(dict,
                {"cuffing_clip","cuffed_clip","idle","loop","cuffed","cuff"})
        end

        cuffAnimDict = dict
        cuffAnimClip = clip
        ClearPedTasksImmediately(ped)
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, 50, 0.0, false, false, false)
        SyncHandcuffState(true)
        Notify("being_handcuffed", "primary")
    end
end)

RegisterNetEvent("plt_departments:client:CuffAnimPaired")
AddEventHandler("plt_departments:client:CuffAnimPaired", function(targetServerId)
    local ped       = PlayerPedId()
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
    local animDict  = "mp_arrest_paired"
    local animClip  = "cop_p2_back_right"

    LoadAnimDict(animDict)

    if DoesEntityExist(targetPed) then
        AttachEntityToEntity(ped, targetPed, 11816,
            0.0, -0.75, 0.0, 0.0, 0.0, 0.0,
            false, false, false, false, 2, true)
    end

    TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, 3500, 2, 0, false, false, false)
    Wait(2000)
    DetachEntity(ped, true, false)
end)

RegisterNetEvent("plt_departments:client:GetCuffedPaired")
AddEventHandler("plt_departments:client:GetCuffedPaired", function(officerServerId)
    local ped = PlayerPedId()

    LoadAnimDict("mp_arrest_paired")
    local pairClip = "crook_p2_back_right"
    cuffAnimDict   = "mp_arrest_paired"
    cuffAnimClip   = pairClip

    isCuffedLocally = true
    LocalPlayer.state:set("isCuffed", true, true)
    ClearPedTasksImmediately(ped)
    TaskPlayAnim(ped, "mp_arrest_paired", pairClip,
        8.0, -8.0, 2000, 2, 0, false, false, false)
    Wait(2000)

    LoadAnimDict("cuffed@pluto")
    local idleClip = FindValidCuffClip("cuffed@pluto",
        {"cuffing_clip","cuffed_clip","idle","loop","cuffed","cuff"})

    cuffAnimDict = "cuffed@pluto"
    cuffAnimClip = idleClip
    ClearPedTasksImmediately(ped)
    Wait(10)
    TaskPlayAnim(ped, "cuffed@pluto", idleClip, 8.0, -8.0, -1, 50, 0.0, false, false, false)
    Wait(10)
    SetEntityAnimCurrentTime(ped, "cuffed@pluto", idleClip, 0.99)

    SyncHandcuffState(true)
    Notify("being_handcuffed", "primary")
end)

RegisterNetEvent("plt_departments:client:ForceAnim")
AddEventHandler("plt_departments:client:ForceAnim", function(animDict, animClip)
    local ped = PlayerPedId()
    LoadAnimDict(animDict)
    ClearPedTasksImmediately(ped)
    TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, -1, 49, 0, false, false, false)
    Notify("forced_animation", "primary")
end)

RegisterNetEvent("plt_departments:client:CuffAnim")
AddEventHandler("plt_departments:client:CuffAnim", function(isCuffing)
    local ped      = PlayerPedId()
    isCuffing      = isCuffing == true or isCuffing == 1
    local animDict = isCuffing and "mp_arresting"    or "cuffing@pluto"
    local animClip = isCuffing and "a_uncuff"        or "cuffing_clip"

    LoadAnimDict(animDict)

    if isCuffing then
        TaskPlayAnim(ped, animDict, animClip, 5.0, 5.0, -1, 49, 0, 0, 0, 0)
        Wait(1000)
        StopAnimTask(ped, animDict, animClip, 1.0)
    else
        TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, -1, 48, 0, 0, 0, 0)
        Wait(3000)
        StopAnimTask(ped, animDict, animClip, 1.0)
    end
    ClearPedSecondaryTask(ped)
end)

CreateThread(function()
    while true do
        if isMenuOpen then
            DisablePlayerFiring(PlayerId(), true)
            for _, ctrl in ipairs({24,25,37,45,68,69,70,91,92,140,141,142,143,257,263,264}) do
                DisableControlAction(0, ctrl, true)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        local waitMs = 1000
        if isCuffedLocally then
            waitMs  = 0
            local ped = PlayerPedId()

            for _, ctrl in ipairs({24,25,47,58,140,141,142,143,263,264,257,21,22,23,75,37,44,45}) do
                DisableControlAction(0, ctrl, true)
            end

            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                for _, ctrl in ipairs({59,60,61,62,63,64,71,72,76,86}) do
                    DisableControlAction(0, ctrl, true)
                end
                SetPedConfigFlag(ped, 184, true)

                if not isEnteringVehicle and not isExitingVehicle then
                    local seat = GetPedSeatInVehicle(veh, ped)
                    if seat ~= nil then
                        if veh == lastVehicleHandle and lastVehicleSeat ~= nil then
                            if seat ~= lastVehicleSeat then
                                SetPedIntoVehicle(ped, lastVehicleHandle, lastVehicleSeat)
                            end
                        else
                            lastVehicleHandle = veh
                            lastVehicleSeat   = seat
                        end
                    end
                end

                local weapon = GetSelectedPedWeapon(ped)
                if weapon ~= -1569615261 then
                    SetCurrentPedWeapon(ped, -1569615261, true)
                end

                local coords = GetEntityCoords(ped)
                local obj1   = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, -1025684278, false, false, false)
                if obj1 ~= 0 then
                    SetEntityAsMissionEntity(obj1, true, true)
                    DeleteObject(obj1)
                end
                local obj2 = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, 336846092, false, false, false)
                if obj2 ~= 0 then
                    SetEntityAsMissionEntity(obj2, true, true)
                    DeleteObject(obj2)
                end
            else
                lastVehicleHandle = 0
                lastVehicleSeat   = nil

                if not isEscortActive and not isEnteringVehicle and not isExitingVehicle then
                    if not IsEntityPlayingAnim(ped, cuffAnimDict, cuffAnimClip, 3) then
                        RequestAnimDict(cuffAnimDict)
                        if HasAnimDictLoaded(cuffAnimDict) then
                            local flags = (cuffAnimDict == "cuffed@pluto") and 50 or 49
                            TaskPlayAnim(ped, cuffAnimDict, cuffAnimClip,
                                8.0, -8.0, -1, flags, 0.0, false, false, false)
                            if cuffAnimDict == "cuffed@pluto" then
                                SetEntityAnimCurrentTime(ped, cuffAnimDict, cuffAnimClip, 0.99)
                            end
                        end
                    end
                end
            end
        end
        Wait(waitMs)
    end
end)

local SPIKE_STRIP_HASH = -874338148
local VEHICLE_WHEELS = {
    { name = "wheel_lf",  index = 0 },
    { name = "wheel_rf",  index = 1 },
    { name = "wheel_lm1", index = 2 },
    { name = "wheel_rm1", index = 3 },
    { name = "wheel_lr",  index = 4 },
    { name = "wheel_rr",  index = 5 },
    { name = "wheel_lm2", index = 6 },
    { name = "wheel_rm2", index = 7 },
}

CreateThread(function()
    while true do
        local waitMs = 1000
        local ped    = PlayerPedId()
        local veh    = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local vehCoords = GetEntityCoords(veh)
            local strip     = GetClosestObjectOfType(
                vehCoords.x, vehCoords.y, vehCoords.z, 15.0,
                SPIKE_STRIP_HASH, false, false, false)

            if strip ~= 0 then
                local stripCoords = GetEntityCoords(strip)
                if #(vehCoords - stripCoords) < 10.0 then
                    waitMs = 0
                    local forward = GetEntityForwardVector(strip)
                    local segA    = stripCoords - forward * 2.5
                    local segB    = stripCoords + forward * 2.5

                    for _, wheel in ipairs(VEHICLE_WHEELS) do
                        if not IsVehicleTyreBurst(veh, wheel.index, false) then
                            local boneIdx = GetEntityBoneIndexByName(veh, wheel.name)
                            if boneIdx ~= -1 then
                                local bonePos = GetWorldPositionOfEntityBone(veh, boneIdx)
                                if PointToSegmentDistance(bonePos, segA, segB) < 0.8 then
                                    SetVehicleTyreBurst(veh, wheel.index, true, 1000.0)
                                end
                            end
                        end
                    end
                end
            end
        end

        Wait(waitMs)
    end
end)

function OfficerCanInteract()
    if not IsPlayerOfficer() then return false end
    if IsLocalPlayerCuffed() then return false end
    return true
end

function InitTargetActions()
    local targetResource = GetTargetResource()
    local targetCfg      = Config.TargetActions or {}
    local playerActions  = targetCfg.player  or {}
    local vehicleActions = targetCfg.vehicle or {}
    local proximityDist  = 3.0

    local function isEnabled(category, key)
        return IsTargetActionEnabled(playerActions, vehicleActions, category, key)
    end

    local allPlayerActions = {
        {
            name = "police_search", icon = "fas fa-magnifying-glass",
            label = T("search_person"),
            configKey = "search",
            canInteract = OfficerCanInteract,
            onSelect = function(data)
                local ped = data.entity
                local idx = NetworkGetPlayerIndexFromPed(ped)
                if idx and idx ~= -1 then
                    TriggerServerEvent("plt_departments:server:SearchPlayer",
                        GetPlayerServerId(idx))
                end
            end,
        },
        {
            name = "police_cuff", icon = "fas fa-handcuffs",
            label = T("handcuff_unhandcuff"),
            configKey = "cuff",
            canInteract = OfficerCanInteract,
            onSelect = function(data)
                local ped = data.entity
                local idx = NetworkGetPlayerIndexFromPed(ped)
                if idx and idx ~= -1 then
                    local serverId = GetPlayerServerId(idx)
                    TriggerServerEvent("plt_departments:server:CuffPlayer",
                        serverId,
                        IsTargetFacingAway(ped),
                        IsTargetKneeling(ped))
                end
            end,
        },
        {
            name = "police_escort", icon = "fas fa-person-walking-arrow-right",
            label = "Escort Person",
            configKey = "escort",
            canInteract = OfficerCanInteract,
            onSelect = function(data)
                local ped = data.entity
                local idx = NetworkGetPlayerIndexFromPed(ped)
                if idx and idx ~= -1 then
                    local serverId = GetPlayerServerId(idx)
                    local bag = Player(serverId).state
                    if IsStateBagCuffed(bag) then
                        StartEscortPed(ped, idx)
                    else
                        Framework.Notify("Player must be handcuffed to be escorted!", "error")
                    end
                end
            end,
        },
        {
            name = "police_put_car", icon = "fas fa-car-side",
            label = "Put in Vehicle",
            configKey = "put_in_vehicle",
            canInteract = OfficerCanInteract,
            onSelect = function(data)
                local ped = data.entity
                local idx = NetworkGetPlayerIndexFromPed(ped)
                if idx and idx ~= -1 then
                    local serverId = GetPlayerServerId(idx)
                    if not IsStateBagCuffed(Player(serverId).state) then
                        Framework.Notify("Player must be handcuffed!", "error")
                        return
                    end
                    local myCoords = GetEntityCoords(PlayerPedId())
                    local veh = Framework.GetClosestVehicle(myCoords)
                    if not veh or veh == 0 then
                        Framework.Notify("No vehicle nearby!", "error")
                        return
                    end
                    local seat = FindFreeSeat(veh)
                    if seat == -1 then
                        Framework.Notify("No free seats!", "error")
                        return
                    end
                    TriggerServerEvent("plt_departments:server:setPlayerEscort",
                        serverId, false, VehToNet(veh), seat)
                end
            end,
        },
        {
            name = "police_out_car", icon = "fas fa-door-open",
            label = "Out of Vehicle",
            configKey = "out_of_vehicle",
            canInteract = OfficerCanInteract,
            onSelect = function(data)
                local ped = data.entity
                local idx = NetworkGetPlayerIndexFromPed(ped)
                if idx and idx ~= -1 then
                    TriggerServerEvent("plt_departments:server:setPlayerEscort",
                        GetPlayerServerId(idx), false, nil, nil, true)
                end
            end,
        },
        {
            name = "police_fine", icon = "fas fa-file-invoice-dollar",
            label = "Fine Person",
            configKey = "fine",
            canInteract = function() return IsPlayerOfficer() end,
            onSelect = function(data)
                local ped = data.entity
                local idx = NetworkGetPlayerIndexFromPed(ped)
                if idx and idx ~= -1 then
                    local serverId = GetPlayerServerId(idx)
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = "openFineInput", targetServerId = serverId })
                end
            end,
        },
        {
            name = "police_jail", icon = "fas fa-lock",
            label = "Jail Person",
            configKey = "jail",
            canInteract = function() return IsPlayerOfficer() end,
            onSelect = function(data)
                local ped = data.entity
                local idx = NetworkGetPlayerIndexFromPed(ped)
                if idx and idx ~= -1 then
                    if Framework.Type == "qb" then
                        TriggerEvent("qb-police:client:JailPlayer")
                    else
                        TriggerEvent("esx_policejob:jailPlayer", GetPlayerServerId(idx))
                    end
                end
            end,
        },
    }

    local configKeyMap = {
        police_search  = "search",    police_cuff    = "cuff",
        police_escort  = "escort",    police_put_car = "put_in_vehicle",
        police_out_car = "out_of_vehicle", police_fine = "fine",
        police_jail    = "jail",
    }
    local filteredPlayerActions = {}
    for _, entry in ipairs(allPlayerActions) do
        local cfgKey = configKeyMap[entry.name]
        if not cfgKey or isEnabled("player", cfgKey) then
            table.insert(filteredPlayerActions, entry)
        end
    end

    if targetResource == "ox_target" then
        exports.ox_target:addGlobalPlayer(filteredPlayerActions)

        local vehicleEntries = {}

        if isEnabled("vehicle", "check_plate") then
            table.insert(vehicleEntries, {
                name = "police_check_plate", icon = "fas fa-closed-captioning",
                label = T("check_plate"),
                canInteract = function() return IsPlayerOfficer() end,
                onSelect = function(data)
                    local veh   = data.entity
                    local plate = GetVehiclePlate(veh)
                    TriggerEvent("plt_departments:client:CheckPlateTarget", veh, plate)
                end,
            })
        end

        if isEnabled("vehicle", "unlock") then
            table.insert(vehicleEntries, {
                name = "police_unlock", icon = "fas fa-lock-open",
                label = T("unlock_vehicle"),
                canInteract = function() return IsPlayerOfficer() end,
                onSelect = function(data)
                    local veh = data.entity
                    Framework.Progressbar("unlock_veh", T("unlocking_vehicle"), 10000, false, true,
                        { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
                        { animDict = "veh@break_in@0h@p_m_one@", anim = "low_force_entry_ds", flags = 16 },
                        {}, {},
                        function()
                            SetVehicleDoorsLocked(veh, 1)
                            SetVehicleDoorsLockedForAllPlayers(veh, false)
                            Framework.Notify(T("vehicle_unlocked"), "success")
                        end,
                        function() Framework.Notify(T("cancelled"), "error") end
                    )
                end,
            })
        end

        if isEnabled("vehicle", "seize") then
            table.insert(vehicleEntries, {
                name = "police_seize", icon = "fas fa-car-burst",
                label = "Seize Vehicle",
                canInteract = function() return IsPlayerOfficer() end,
                onSelect = function(data)
                    local netId = NetworkGetNetworkIdFromEntity(data.entity)
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = "openSeizeInput", vehNetId = netId })
                end,
            })
        end

        if #vehicleEntries > 0 then
            exports.ox_target:addGlobalVehicle(vehicleEntries)
        end

    elseif targetResource == "qb-target" then
        
        local qbPlayerOptions = {}
        for _, entry in ipairs(filteredPlayerActions) do
            table.insert(qbPlayerOptions, {
                type        = "client",
                event       = "",
                icon        = entry.icon,
                label       = entry.label,
                canInteract = entry.canInteract,
                action      = function(entity)
                    entry.onSelect({ entity = entity })
                end,
            })
        end
        exports["qb-target"]:AddGlobalPlayer({ options = qbPlayerOptions, distance = proximityDist })

        local qbVehicleOptions = {}

        if isEnabled("vehicle", "check_plate") then
            table.insert(qbVehicleOptions, {
                name  = "police_check_plate", icon = "fas fa-closed-captioning",
                label = T("check_plate"),
                action = function(entity)
                    TriggerEvent("plt_departments:client:CheckPlateTarget",
                        entity, GetVehiclePlate(entity))
                end,
                canInteract = function() return IsPlayerOfficer() end,
            })
        end

        if isEnabled("vehicle", "unlock") then
            table.insert(qbVehicleOptions, {
                name  = "police_unlock", icon = "fas fa-lock-open",
                label = T("unlock_vehicle"),
                action = function(entity)
                    Framework.Progressbar("unlock_veh", T("unlocking_vehicle"), 10000, false, true,
                        { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
                        { animDict = "veh@break_in@0h@p_m_one@", anim = "low_force_entry_ds", flags = 16 },
                        {}, {},
                        function()
                            SetVehicleDoorsLocked(entity, 1)
                            SetVehicleDoorsLockedForAllPlayers(entity, false)
                            Framework.Notify(T("vehicle_unlocked"), "success")
                        end,
                        function() Framework.Notify(T("cancelled"), "error") end
                    )
                end,
                canInteract = function() return IsPlayerOfficer() end,
            })
        end

        if isEnabled("vehicle", "seize") then
            table.insert(qbVehicleOptions, {
                name  = "police_seize", icon = "fas fa-car-burst",
                label = T("seize_vehicle"),
                action = function(entity)
                    local netId = NetworkGetNetworkIdFromEntity(entity)
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = "openSeizeInput", vehNetId = netId })
                end,
                canInteract = function() return IsPlayerOfficer() end,
            })
        end

        if #qbVehicleOptions > 0 then
            exports["qb-target"]:AddGlobalVehicle({ options = qbVehicleOptions, distance = 2.5 })
        end
    end
end

CreateThread(function()
    Wait(2000)
    InitTargetActions()
end)
