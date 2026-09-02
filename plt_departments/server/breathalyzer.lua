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


local playerAlcoholLevels = {}

CreateThread(function()
    Wait(1500)
    Framework.RegisterUsableItem("breathalyzer", function(playerId, itemData)
        local player = Framework.GetPlayer(playerId)
        if not player then return end
        TriggerClientEvent("plt_departments:client:useBreathalyzer", playerId)
    end)
end)

CreateThread(function()
    Wait(2000)
    local alcoholicItems = Config.AlcoholicItems or {}
    for itemName, itemData in pairs(alcoholicItems) do
        Framework.RegisterUsableItem(itemName, function(playerId, slotData)
            local player = Framework.GetPlayer(playerId)
            if not player then return end

            local citizenId = player.citizenid
            local currentLevel = playerAlcoholLevels[citizenId] or 0.0
            playerAlcoholLevels[citizenId] = currentLevel + itemData.strength

            Framework.Notify(playerId, "You consumed some alcohol...", "primary")
            TriggerClientEvent("plt_departments:client:consumeAlcohol", playerId)
        end)
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        for citizenId, level in pairs(playerAlcoholLevels) do
            if level > 0 then
                playerAlcoholLevels[citizenId] = math.max(0.0, level - 0.001)
            else
                playerAlcoholLevels[citizenId] = nil
            end
        end
    end
end)

RegisterNetEvent("plt_departments:server:requestBreathTest")
AddEventHandler("plt_departments:server:requestBreathTest", function(targetPlayerId)
    local officerId = source
    local targetPlayer = Framework.GetPlayer(targetPlayerId)
    if not targetPlayer then return end

    local officer = Framework.GetPlayer(officerId)
    local officerName = (officer and officer.name) or "Officer"

    Framework.Notify(targetPlayerId, "Officer " .. officerName .. " is requesting a breath test.", "primary")
    TriggerClientEvent("plt_departments:client:startBreathTest", targetPlayerId, officerId, true)
    TriggerClientEvent("plt_departments:client:startBreathTest", officerId, officerId, false)
end)

RegisterNetEvent("plt_departments:server:syncBreathProgress")
AddEventHandler("plt_departments:server:syncBreathProgress", function(targetPlayerId, progress, state)
    TriggerClientEvent("plt_departments:client:updateBreathProgress", targetPlayerId, progress, state)
end)

RegisterNetEvent("plt_departments:server:sendBreathResult")
AddEventHandler("plt_departments:server:sendBreathResult", function(officerId, targetPlayerId)
    local subjectId = source
    local subjectPlayer = Framework.GetPlayer(subjectId)
    if not subjectPlayer then return end

    local subjectName = subjectPlayer.name or "Unknown"
    local citizenId = subjectPlayer.citizenid
    local baseLevel = playerAlcoholLevels[citizenId] or 0.0

    local variance = math.random(-5, 5) / 1000
    local finalLevel = math.max(0.0, baseLevel + variance)

    TriggerClientEvent("plt_departments:client:breathTestResult", officerId, finalLevel, subjectName)
    TriggerClientEvent("plt_departments:client:breathTestResult", subjectId, finalLevel, subjectName)
end)

