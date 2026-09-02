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


ActiveRadars = {}

function GetSpeedUnitLabel()
    local unit = tostring(Config.SpeedUnit or "kmh"):lower()
    return unit == "mph" and "MPH" or "KM/H"
end

function GetPlayerDept(player)
    local memberRecord = MemberData and MemberData[player.citizenid]
    if memberRecord and memberRecord.dept then
        return memberRecord.dept
    end
    return (player.job and player.job.name) or "civilian"
end

function SaveAllRadarsToDB()
    for id, radarData in pairs(ActiveRadars) do
        MySQL.Async.execute(
            "INSERT INTO plt_departments_radars (id, data) VALUES (@id, @data) ON DUPLICATE KEY UPDATE data = @data",
            { ["@id"] = id, ["@data"] = json.encode(radarData) }
        )
    end
end

function LoadRadarsFromDB()
    local rows = MySQL.Sync.fetchAll("SELECT * FROM plt_departments_radars", {})
    ActiveRadars = {}
    for _, row in ipairs(rows) do
        ActiveRadars[row.id] = json.decode(row.data)
    end
end

CreateThread(function()
    while true do
        if PLTServerDataLoaded() then break end
        Wait(100)
    end
    LoadRadarsFromDB()
end)

CreateThread(function()
    Wait(1500)
    Framework.RegisterUsableItem("radar_camera", function(playerId, itemData)
        local player = Framework.GetPlayer(playerId)
        if not player then return end
        local dept = GetPlayerDept(player)
        TriggerClientEvent("plt_departments:client:startRadarPlacement", playerId, dept)
    end)
end)

RegisterCommand("placecamera", function(playerId)
    local player = Framework.GetPlayer(playerId)
    if not player then return end
    local dept = GetPlayerDept(player)
    TriggerClientEvent("plt_departments:client:startRadarPlacement", playerId, dept)
end, false)

RegisterCommand("checkmyjob", function(playerId)
    local player = Framework.GetPlayer(playerId)
    local memberRecord = MemberData and MemberData[player.citizenid]
    if memberRecord then
        local msg = "Dept: " .. tostring(memberRecord.dept) .. " | Duty: " .. tostring(memberRecord.onDuty)
        Framework.Notify(playerId, msg, "primary")
    else
        Framework.Notify(playerId, "You are not in the department database!", "error")
    end
end, false)

RegisterNetEvent("plt_departments:server:registerRadar")
AddEventHandler("plt_departments:server:registerRadar", function(coords, heading, speedLimit, deptId, radarName)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    if not radarName or radarName == "" then
        radarName = "Mobile Radar"
    end

    local radarId = "radar_" .. os.time() .. "_" .. math.random(100, 999)

    ActiveRadars[radarId] = {
        id        = radarId,
        name      = radarName,
        coords    = coords,
        heading   = heading,
        limit     = speedLimit,
        deptId    = deptId,
        ownerCid  = player.citizenid,
        ownerName = player.name,
    }

    SaveAllRadarsToDB()
    TriggerClientEvent("plt_departments:client:syncRadars", -1, ActiveRadars)

    Framework.Notify(playerId, T("radar_setup_msg", { name = ActiveRadars[radarId].name, limit = speedLimit }), "success")
end)

RegisterNetEvent("plt_departments:server:removeRadar")
AddEventHandler("plt_departments:server:removeRadar", function(radarIdOrTable)
    local playerId = source
    local radarId = (type(radarIdOrTable) == "table" and radarIdOrTable.radarId) or radarIdOrTable

    if not ActiveRadars[radarId] then return end

    ActiveRadars[radarId] = nil
    MySQL.Async.execute("DELETE FROM plt_departments_radars WHERE id = ?", { radarId })
    TriggerClientEvent("plt_departments:client:syncRadars", -1, ActiveRadars)
    Framework.Notify(playerId, T("camera_removed"), "primary")
end)

RegisterNetEvent("plt_departments:server:updateRadarField")
AddEventHandler("plt_departments:server:updateRadarField", function(radarId, field, value)
    local playerId = source
    if not ActiveRadars[radarId] then return end

    ActiveRadars[radarId][field] = value
    SaveAllRadarsToDB()
    TriggerClientEvent("plt_departments:client:syncRadars", -1, ActiveRadars)

    local displayValue
    if field == "fineAmount" then
        displayValue = "$" .. value .. "/UNIT"
    elseif field == "limit" then
        displayValue = value .. " " .. GetSpeedUnitLabel()
    else
        displayValue = tostring(value)
    end

    Framework.Notify(playerId, string.format("Radar updated: %s set to %s", field:upper(), displayValue), "success")
end)

RegisterNetEvent("plt_departments:server:processRadarViolation")
AddEventHandler("plt_departments:server:processRadarViolation", function(radarId, vehicleNetId, detectedSpeed)
    local radarData = ActiveRadars[radarId]
    if not radarData then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local driverPed = GetPedInVehicleSeat(vehicle, -1)
    if driverPed == 0 then return end

    local driverServerId = NetworkGetEntityOwner(driverPed)
    local driverPlayer = Framework.GetPlayer(driverServerId)
    if not driverPlayer then return end

    local driverMember = MemberData[driverPlayer.citizenid]
    if driverMember and driverMember.dept ~= "none" then return end

    local finePerUnit = radarData.fineAmount or 15
    local overspeed = detectedSpeed - radarData.limit
    local fineAmount = math.max(50, math.floor(overspeed * finePerUnit))

    local deducted = driverPlayer.functions.RemoveMoney("bank", fineAmount, "Speeding Fine (Radar)")
    if not deducted then return end

    if DeptBalances and DeptBalances[radarData.deptId] then
        DeptBalances[radarData.deptId] = DeptBalances[radarData.deptId] + fineAmount
        SaveBalances()

        local driverName = driverPlayer.name or "Unknown"
        local radarName = radarData.name or "Mobile"
        local speedLabel = string.format("Speeding: %d %s (Limit: %d)", math.floor(detectedSpeed), GetSpeedUnitLabel(), radarData.limit)

        AddFinanceTransaction(
            radarData.deptId,
            "fine_forced",
            fineAmount,
            { name = "Radar: " .. radarName, cid = "RADAR" },
            { name = driverName, cid = driverPlayer.citizenid },
            speedLabel
        )

        UpdateFinanceHistory(radarData.deptId)
        TriggerClientEvent("plt_departments:client:SyncFinances", -1, FinanceHistory, DeptBalances)
    end

    Framework.Notify(driverServerId, T("caught_speeding", { amount = fineAmount }), "error")
    TriggerClientEvent("plt_departments:client:playRadarFlash", driverServerId)
end)

Framework.CreateCallback("plt_departments:server:getActiveRadars", function(source, cb)
    cb(ActiveRadars)
end)

