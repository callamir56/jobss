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


Inventory = {}

local function GetInventoryType()
    return Config.Inventory or "qb"
end

if IsDuplicityVersion() then
    
    function Inventory.AddItem(source, item, count, metadata)
        count = count or 1
        local invType = GetInventoryType()
        
        if invType == "ox" then
            local result = exports.ox_inventory:AddItem(source, item, count, metadata)
            return result ~= nil
        elseif invType == "qb" or invType == "lj" or invType == "aj" then
            local Player = Framework.Core.Functions.GetPlayer(source)
            if Player and Player.Functions.AddItem then
                local success = Player.Functions.AddItem(item, count, false, metadata)
                if success then
                    TriggerClientEvent('inventory:client:ItemBox', source, Framework.Core.Shared.Items[item], "add")
                end
                return success
            end
        elseif invType == "qs" then
            return exports['qs-inventory']:AddItem(source, item, count, nil, metadata)
        elseif invType == "codem" then
            return exports["codem-inventory"]:AddItem(source, item, count, metadata)
        elseif invType == "tgiann" then
            return exports["tgiann-inventory"]:AddItem(source, item, count, nil, metadata)
        elseif invType == "core" then
            return exports['core_inventory']:addItem(item, count, metadata, source)
        elseif invType == "chezza" then
            return exports.inventory:AddItem(source, item, count, metadata)
        end
        
        local Player = Framework.GetPlayer(source)
        if Player and Player.functions and Player.functions.AddItem then
            return Player.functions.AddItem(item, count, false, metadata)
        end
        
        return false
    end

    function Inventory.HasItem(source, item, count)
        count = count or 1
        local invType = GetInventoryType()
        
        if invType == "ox" then
            local count_ = exports.ox_inventory:GetItemCount(source, item)
            return count_ >= count
        elseif invType == "qb" or invType == "lj" or invType == "aj" then
            local Player = Framework.Core and Framework.Core.Functions and Framework.Core.Functions.GetPlayer(source)
            if Player then
                local itemData = Player.Functions.GetItemByName(item)
                return itemData and itemData.amount >= count
            end
        elseif invType == "qs" then
            return (exports['qs-inventory']:GetItemTotalAmount(source, item) or 0) >= count
        elseif invType == "codem" then
            local okCount, itemCount = pcall(function()
                return exports["codem-inventory"]:GetItemCount(source, item)
            end)
            if okCount and itemCount then
                return itemCount >= count
            end

            local okTotal, totalAmount = pcall(function()
                return exports["codem-inventory"]:GetItemsTotalAmount(source, item)
            end)
            if okTotal and totalAmount then
                return totalAmount >= count
            end

            return false
        elseif invType == "tgiann" then
            return exports["tgiann-inventory"]:HasItem(source, item, count)
        end
        
        if Framework.Type == "qb" and Framework.Core and Framework.Core.Functions then
            local Player = Framework.Core.Functions.GetPlayer(source)
            if Player then
                local itemData = Player.Functions.GetItemByName(item)
                return itemData and itemData.amount >= count
            end
        elseif Framework.Type == "esx" and Framework.Core then
            local xPlayer = Framework.Core.GetPlayerFromId(source)
            if xPlayer then
                local item = xPlayer.getInventoryItem(item)
                return item and item.count >= count
            end
        end
        
        return false
    end

    function Inventory.GetItems(source)
        local invType = GetInventoryType()
        local items = {}
        
        if invType == "ox" then
            local inventory = exports.ox_inventory:GetInventory(source)
            if inventory and inventory.items then
                for _, item in pairs(inventory.items) do
                    table.insert(items, {
                        name = item.name,
                        amount = item.count,
                        info = item.metadata or {},
                        slot = item.slot,
                        label = item.label
                    })
                end
            end
        elseif invType == "qb" or invType == "lj" or invType == "aj" then
            local Player = Framework.Core and Framework.Core.Functions and Framework.Core.Functions.GetPlayer(source)
            if Player and Player.PlayerData and Player.PlayerData.items then
                for k, item in pairs(Player.PlayerData.items) do
                    table.insert(items, {
                        name = item.name,
                        amount = item.amount,
                        info = item.info or {},
                        slot = item.slot,
                        label = item.label
                    })
                end
            end
        elseif invType == "qs" then
            local inventory = exports['qs-inventory']:GetInventory(source)
            if inventory then
                for _, item in pairs(inventory) do
                    table.insert(items, {
                        name = item.name,
                        amount = item.amount,
                        info = item.info or {},
                        slot = item.slot,
                        label = item.label
                    })
                end
            end
        elseif invType == "codem" then
            local inventory = exports["codem-inventory"]:GetInventory(source)
            if inventory then
                for _, item in pairs(inventory) do
                    table.insert(items, {
                        name = item.name,
                        amount = item.count or item.amount or 0,
                        info = item.info or item.metadata or {},
                        slot = item.slot or 0,
                        label = item.label or item.name
                    })
                end
            end
        elseif invType == "tgiann" then
            local inventory = exports["tgiann-inventory"]:GetPlayerItems(source)
            if inventory then
                for _, item in pairs(inventory) do
                    table.insert(items, {
                        name = item.name,
                        amount = item.amount or item.count or 0,
                        info = item.info or item.metadata or {},
                        slot = item.slot or 0,
                        label = item.label or item.name
                    })
                end
            end
        elseif invType == "esx" then
            local xPlayer = Framework.Core and Framework.Core.GetPlayerFromId(source)
            if xPlayer and xPlayer.getInventory then
                local inventory = xPlayer.getInventory()
                for _, item in pairs(inventory) do
                    if item.count > 0 then
                        table.insert(items, {
                            name = item.name,
                            amount = item.count,
                            info = item.metadata or {},
                            slot = item.slot or 0,
                            label = item.label
                        })
                    end
                end
            end
        end

        if #items == 0 and Framework.Type == "qb" and Framework.Core and Framework.Core.Functions then
            local Player = Framework.Core.Functions.GetPlayer(source)
            if Player and Player.PlayerData and Player.PlayerData.items then
                for k, item in pairs(Player.PlayerData.items) do
                    table.insert(items, {
                        name = item.name,
                        amount = item.amount,
                        info = item.info or {},
                        slot = item.slot,
                        label = item.label
                    })
                end
            end
        end

        return items
    end

    function Inventory.RemoveItem(source, item, count, metadata)
        count = count or 1
        local invType = GetInventoryType()
        
        if invType == "ox" then
            return exports.ox_inventory:RemoveItem(source, item, count, metadata)
        elseif invType == "qb" or invType == "lj" or invType == "aj" then
            local Player = Framework.Core.Functions.GetPlayer(source)
            if Player and Player.Functions.RemoveItem then
                local success = Player.Functions.RemoveItem(item, count)
                if success then
                    TriggerClientEvent('inventory:client:ItemBox', source, Framework.Core.Shared.Items[item], "remove")
                end
                return success
            end
        elseif invType == "qs" then
            return exports['qs-inventory']:RemoveItem(source, item, count)
        elseif invType == "codem" then
            return exports["codem-inventory"]:RemoveItem(source, item, count)
        elseif invType == "tgiann" then
            return exports["tgiann-inventory"]:RemoveItem(source, item, count, nil, metadata)
        elseif invType == "core" then
            return exports['core_inventory']:removeItem(item, count, source)
        elseif invType == "chezza" then
            return exports.inventory:RemoveItem(source, item, count, metadata)
        end
        
        local Player = Framework.GetPlayer(source)
        if Player and Player.functions and Player.functions.RemoveItem then
            return Player.functions.RemoveItem(item, count)
        end
        
        return false
    end

    function Inventory.RegisterStash(id, label, slots, weight, owner)
        local invType = GetInventoryType()
        
        if invType == "ox" then
            exports.ox_inventory:RegisterStash(id, label, slots, weight, owner)
        elseif invType == "tgiann" then
            exports["tgiann-inventory"]:RegisterStash(id, label, slots, weight, false)
        elseif invType == "qs" then
            
        elseif invType == "codem" then
            
            local created = false
            created = pcall(function()
                exports["codem-inventory"]:CreateStash(id, label, slots, weight)
            end)

            if not created then
                created = pcall(function()
                    exports["codem-inventory"]:RegisterStash(id, label, slots, weight)
                end)
            end

            if not created then
                pcall(function()
                    exports["codem-inventory"]:AddStash(id, label, slots, weight)
                end)
            end
        end
    end

    function Inventory.OpenStash(source, id, label, slots, weight)
        local invType = GetInventoryType()
        
        if invType == "ox" then
            exports.ox_inventory:forceOpenInventory(source, 'stash', id)
        elseif invType == "qb" or invType == "lj" or invType == "aj" then
            TriggerClientEvent("inventory:client:SetCurrentStash", source, id)
            TriggerClientEvent("inventory:server:OpenInventory", source, "stash", id, {
                maxweight = weight or 100000,
                slots = slots or 50,
            })
        elseif invType == "qs" then
            local data = { id = id, label = label or "Stash", slots = slots or 50, weight = weight or 100000 }
            TriggerClientEvent('qs-inventory:client:openStash', source, data)
        elseif invType == "codem" then
            local opened = false
            opened = pcall(function()
                exports["codem-inventory"]:OpenStash(source, id, slots or 50, weight or 100000)
            end)

            if not opened then
                opened = pcall(function()
                    exports["codem-inventory"]:OpenInventory(source, "stash", id, {
                        label = label or "Stash",
                        slots = slots or 50,
                        maxweight = weight or 100000,
                        maxWeight = weight or 100000
                    })
                end)
            end

            if not opened then
                
                TriggerClientEvent("inventory:client:SetCurrentStash", source, id)
                TriggerClientEvent("inventory:server:OpenInventory", source, "stash", id, {
                    maxweight = weight or 100000,
                    slots = slots or 50
                })
            end
        elseif invType == "tgiann" then
            exports["tgiann-inventory"]:OpenInventory(source, "stash", id, {
                label = label or "Stash",
                slots = slots or 50,
                maxWeight = weight or 100000
            })
        elseif invType == "chezza" then
            TriggerClientEvent('inventory:openStorage', source, "Stash", id, slots or 50, weight or 100000)
        end
    end

    function Inventory.OpenPlayerInventory(source, targetId)
        local invType = GetInventoryType()
        targetId = tonumber(targetId)
        if not targetId then return end
        
        if invType == "ox" then
            exports.ox_inventory:forceOpenInventory(source, 'player', targetId)
        elseif invType == "qb" then
            local opened = false

            if GetResourceState('qb-inventory') == 'started' then
                opened = pcall(function()
                    exports['qb-inventory']:OpenInventoryById(source, targetId)
                end)
            end

            if not opened then
                TriggerClientEvent("plt_departments:client:OpenQBInventory", source, targetId)
            end
        elseif invType == "lj" or invType == "aj" or invType == "ps" then
            
            TriggerClientEvent("plt_departments:client:OpenQBInventory", source, targetId)
        elseif invType == "qs" then
            TriggerClientEvent("plt_departments:client:OpenQSInventory", source, targetId)
        elseif invType == "codem" then
            exports["codem-inventory"]:OpenOtherInventory(source, targetId)
        elseif invType == "tgiann" then
            exports["tgiann-inventory"]:OpenInventoryById(source, targetId, false)
        elseif invType == "core" then
            exports.core_inventory:openOtherInventory(targetId, source)
        end
    end

end

if not IsDuplicityVersion() then
    
    RegisterNetEvent("plt_departments:client:OpenQSInventory", function(targetId)
        TriggerEvent("inventory:client:SetCurrentStash", "otherplayer", targetId)
        TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", targetId)
    end)

    RegisterNetEvent("plt_departments:client:OpenQBInventory", function(targetId)
        TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", targetId)
    end)
end

