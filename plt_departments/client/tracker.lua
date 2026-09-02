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


function PlaceTrackerProgressbar(plate, vehicleModel)
    local ped = PlayerPedId()
    Framework.Progressbar("place_tracker", "PLACING GPS TRACKER...", 5000, false, true, {
        disableMovement    = true,
        disableCarMovement = true,
        disableMouse       = false,
        disableCombat      = true,
    }, {
        animDict = "amb@medic@standing@tendtodead@base",
        animName = "base",
        flags    = 1,
    }, {}, {},
    function()
        TriggerServerEvent("plt_departments:server:placeTracker", plate, vehicleModel)
    end,
    function()
        Framework.Notify("Placement cancelled.", "error")
    end)
end

RegisterNetEvent("plt_departments:client:useGPSTracker", function()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.5, 0, 71)

    if not vehicle or vehicle == 0 then
        Framework.Notify("No vehicle nearby.", "error")
        return
    end

    local plate        = GetVehicleNumberPlateText(vehicle)
    local vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))

    PlaceTrackerProgressbar(plate, vehicleModel)
end)

RegisterNetEvent("plt_departments:client:receiveTrackers", function(trackers)
    SendNUIMessage({ action = "receiveTrackers", trackers = trackers })
end)

RegisterNUICallback("locateTrackedVehicle", function(data, cb)
    local plate  = data.plate
    local coords = data.coords

    if not coords then
        Framework.Notify("Vehicle signal lost.", "error")
        cb("error")
        return
    end

    Framework.Notify("Vehicle [" .. plate .. "] located.", "success")

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Tracked Vehicle [" .. plate .. "]")
    EndTextCommandSetBlipName(blip)
    SetBlipRoute(blip, true)

    SetTimeout(15000, function()
        RemoveBlip(blip)
    end)

    cb("ok")
end)

RegisterNUICallback("removeTracker", function(data, cb)
    TriggerServerEvent("plt_departments:server:removeTracker", data.plate)
    cb("ok")
end)

RegisterNUICallback("getTrackers", function(data, cb)
    TriggerServerEvent("plt_departments:server:getTrackers")
    cb("ok")
end)

