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


RegisterNetEvent("plt_departments:server:sendDeptMessage")
AddEventHandler("plt_departments:server:sendDeptMessage", function(data)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local fromDept = data.fromDept
    local toDept   = data.toDept
    local message  = data.message
    local sender   = player.name
    local timestamp = os.time()

    MySQL.Async.execute(
        "INSERT INTO plt_departments_comms (fromDept, toDept, senderName, message, timestamp) VALUES (?, ?, ?, ?, ?)",
        { fromDept, toDept, sender, message, timestamp },
        function()
            TriggerEvent("plt_departments:server:syncDeptComms", fromDept, toDept)
        end
    )
end)

RegisterNetEvent("plt_departments:server:syncDeptComms")
AddEventHandler("plt_departments:server:syncDeptComms", function(fromDept, toDept)
    MySQL.Async.fetchAll(
        "SELECT * FROM plt_departments_comms WHERE (fromDept = ? AND toDept = ?) OR (fromDept = ? AND toDept = ?) ORDER BY timestamp ASC",
        { fromDept, toDept, toDept, fromDept },
        function(rows)
            for _, playerServerId in ipairs(GetPlayers()) do
                local numericId = tonumber(playerServerId)
                local player = Framework.GetPlayer(numericId)
                if player and player.job then
                    local jobName = player.job.name
                    if jobName == fromDept or jobName == toDept then
                        TriggerClientEvent("plt_departments:client:receiveDeptComms", numericId, rows, fromDept, toDept)
                    end
                end
            end
        end
    )
end)

Framework.CreateCallback("plt_departments:server:getDeptComms", function(source, cb, data)
    local fromDept = data.fromDept
    local toDept   = data.toDept
    MySQL.Async.fetchAll(
        "SELECT * FROM plt_departments_comms WHERE (fromDept = ? AND toDept = ?) OR (fromDept = ? AND toDept = ?) ORDER BY timestamp ASC",
        { fromDept, toDept, toDept, fromDept },
        function(rows)
            cb(rows)
        end
    )
end)

Framework.CreateCallback("plt_departments:server:getAllDepts", function(source, cb)
    local deptList = {}

    if DepartmentData and DepartmentData.nodes then
        for _, node in ipairs(DepartmentData.nodes) do
            if node.type == "department" then
                table.insert(deptList, { id = node.id, label = node.label })
            end
        end
    end

    if #deptList > 0 then
        cb(deptList)
        return
    end

    MySQL.Async.fetchAll(
        "SELECT value FROM plt_departments_data WHERE `key` = ?",
        { "departments" },
        function(result)
            if result and result[1] then
                local decoded = json.decode(result[1].value)
                if decoded and decoded.nodes then
                    for _, node in ipairs(decoded.nodes) do
                        if node.type == "department" then
                            table.insert(deptList, { id = node.id, label = node.label })
                        end
                    end
                end
            end
            cb(deptList)
        end
    )
end)

