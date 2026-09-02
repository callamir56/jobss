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


TrackedVehicles = {}

function SaveTrackerToDB(plate, trackerData)
    MySQL.Async.execute(
        "INSERT INTO plt_departments_trackers (plate, deptId, model, placedBy, timestamp) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE deptId = VALUES(deptId), model = VALUES(model), placedBy = VALUES(placedBy), timestamp = VALUES(timestamp)",
        { plate, trackerData.deptId, trackerData.model, trackerData.placedBy, trackerData.timestamp }
    )
end

function DeleteTrackerFromDB(plate)
    MySQL.Async.execute(
        "DELETE FROM plt_departments_trackers WHERE plate = ?",
        { plate }
    )
end

CreateThread(function()
    Wait(2000)
    MySQL.Async.fetchAll("SELECT * FROM plt_departments_trackers", {}, function(rows)
        if not rows then return end
        for _, row in ipairs(rows) do
            TrackedVehicles[row.plate] = {
                plate     = row.plate,
                deptId    = row.deptId,
                model     = row.model,
                placedBy  = row.placedBy,
                timestamp = row.timestamp,
            }
        end
    end)
end)

CreateThread(function()
    Wait(1000)
    local function triggerTrackerUI(playerId)
        TriggerClientEvent("plt_departments:client:useGPSTracker", playerId)
    end

    Framework.RegisterUsableItem("gps_tracker", function(playerId, itemData)
        triggerTrackerUI(playerId)
    end)
end)

RegisterNetEvent("plt_departments:server:placeTracker")
AddEventHandler("plt_departments:server:placeTracker", function(plate, vehicleModel)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local deptId = (player.job and player.job.name) or "unemployed"
    local placedBy = player.name

    if not Inventory.HasItem(playerId, "gps_tracker", 1) then
        Framework.Notify(playerId, "You don't have a GPS tracker.", "error")
        return
    end

    Inventory.RemoveItem(playerId, "gps_tracker", 1)

    local trackerData = {
        plate     = plate,
        deptId    = deptId,
        model     = vehicleModel,
        placedBy  = placedBy,
        timestamp = os.time(),
    }

    TrackedVehicles[plate] = trackerData
    SaveTrackerToDB(plate, trackerData)

    Framework.Notify(playerId, T("gps_placed", { plate = plate }), "success")
end)

RegisterNetEvent("plt_departments:server:getTrackers")
AddEventHandler("plt_departments:server:getTrackers", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local deptId = (player.job and player.job.name) or "unemployed"
    local allVehicles = GetAllVehicles()
    local results = {}

    for plate, trackerData in pairs(TrackedVehicles) do
        if trackerData.deptId == deptId then
            local cleanPlate = string.gsub(plate, "%s+", "")
            local coords = nil
            local isOnline = false

            for _, vehicle in ipairs(allVehicles) do
                local vehiclePlate = string.gsub(GetVehicleNumberPlateText(vehicle), "%s+", "")
                if vehiclePlate == cleanPlate then
                    local rawCoords = GetEntityCoords(vehicle)
                    coords = { x = rawCoords.x, y = rawCoords.y, z = rawCoords.z }
                    isOnline = true
                    break
                end
            end

            table.insert(results, {
                plate    = plate,
                model    = trackerData.model,
                placedBy = trackerData.placedBy,
                time     = os.date("%m/%d %H:%M", trackerData.timestamp),
                isOnline = isOnline,
                coords   = coords,
            })
        end
    end

    TriggerClientEvent("plt_departments:client:receiveTrackers", playerId, results)
end)

RegisterNetEvent("plt_departments:server:removeTracker")
AddEventHandler("plt_departments:server:removeTracker", function(plate)
    local playerId = source
    if not TrackedVehicles[plate] then return end

    TrackedVehicles[plate] = nil
    DeleteTrackerFromDB(plate)

    Framework.Notify(playerId, T("gps_removed", { plate = plate }), "success")
end)

