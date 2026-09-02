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

local activeCalls = {}

exports("GetActiveCalls", function()
    return activeCalls
end)

exports("CreateDispatchCall", function(callData)
    if not callData or not callData.code then return end

    if not callData.id then
        callData.id = tostring(os.time()) .. math.random(100, 999)
    end

    callData.timestamp = os.time()
    callData.time = callData.time or os.date("%H:%M")

    table.insert(activeCalls, callData)

    if #activeCalls > 100 then
        table.remove(activeCalls, 1)
    end

    TriggerClientEvent("plt_departments:client:addDispatchCall", -1, callData)
    TriggerEvent("plt_departments:server:OnDispatchCall", callData)
end)

RegisterNetEvent("plt_departments:server:createDispatchCall")
AddEventHandler("plt_departments:server:createDispatchCall", function(callData)
    local playerId = source
    local finalCallData = callData

    if playerId and playerId > 0 then
        if PLTServerNodes and PLTServerNodes.BuildDispatchCallForSource then
            local enriched = PLTServerNodes.BuildDispatchCallForSource(playerId, callData, MemberData)
            if not enriched then return end
            finalCallData = enriched
        end
    end

    exports.plt_departments:CreateDispatchCall(finalCallData)
end)

