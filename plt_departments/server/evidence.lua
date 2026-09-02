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


local activeEvidence = {}

function IsWeaponIgnored(weaponHash)
    local ignoredList = (Config.Evidence and Config.Evidence.IgnoredShotWeapons) or {}
    for _, entry in ipairs(ignoredList) do
        if type(entry) == "number" and weaponHash == entry then
            return true
        end
        if type(entry) == "string" and weaponHash == GetHashKey(entry) then
            return true
        end
    end
    return false
end

function DepartmentHasEvidenceNode()
    if not DepartmentData or not DepartmentData.nodes then return false end
    for _, node in ipairs(DepartmentData.nodes) do
        if node.type == "evidence" then return true end
    end
    return false
end

function PlayerHasEvidenceAccess(player, memberRecord)
    if not memberRecord then return false end
    if memberRecord.dept == "none" then return false end
    if PLTServerNodes and PLTServerNodes.DepartmentHasNodeType then
        return PLTServerNodes.DepartmentHasNodeType(memberRecord.dept, "evidence", DepartmentData)
    end
    return false
end

function ResolveItemMeta(player, itemData)
    
    if itemData then
        if itemData.info then return itemData.info end
        if itemData.metadata then return itemData.metadata end
    end

    if itemData and itemData.slot and player and player.functions and player.functions.GetItemBySlot then
        local slotItem = player.functions.GetItemBySlot(itemData.slot)
        if slotItem then
            return slotItem.info or slotItem.metadata
        end
    end

    return nil
end

CreateThread(function()
    Wait(1500)

    local function triggerEvidenceBagUI(playerId)
        TriggerClientEvent("plt_departments:client:useEvidenceBag", playerId)
    end

    local function openForensicReport(playerId, itemData)
        local player = Framework.GetPlayer(playerId)
        if not player then return end

        local meta = ResolveItemMeta(player, itemData)

        if not meta then
            local items = Inventory.GetItems(playerId)
            for _, item in ipairs(items) do
                if item.name == "forensic_report" and item.info then
                    local hasId = item.info.serial or item.info.reportId
                    if hasId then
                        
                        if itemData and itemData.slot then
                            if item.slot == itemData.slot then
                                meta = item.info
                                break
                            end
                        else
                            meta = item.info
                            break
                        end
                    end
                end
            end
        end

        if meta then
            TriggerClientEvent("plt_departments:client:viewForensicReport", playerId, meta)
        else
            Framework.Notify(playerId, T("report_unreadable"), "error")
        end
    end

    Framework.RegisterUsableItem("evidence_bag", function(playerId, itemData)
        triggerEvidenceBagUI(playerId)
    end)

    Framework.RegisterUsableItem("forensic_report", function(playerId, itemData)
        openForensicReport(playerId, itemData)
    end)
end)

RegisterNetEvent("plt_departments:server:dropCasing")
AddEventHandler("plt_departments:server:dropCasing", function(weaponHash, coords)
    if IsWeaponIgnored(weaponHash) then return end
    if not DepartmentHasEvidenceNode() then return end

    local evidenceId = "evidence_" .. os.time() .. "_" .. math.random(1000, 9999)

    local serial = "Unknown"

    local evidenceEntry = {
        id        = evidenceId,
        type      = "casing",
        coords    = coords,
        weapon    = weaponHash,
        serial    = serial,
        timestamp = os.time(),
    }

    activeEvidence[evidenceId] = evidenceEntry
    TriggerClientEvent("plt_departments:client:addEvidence", -1, evidenceId, evidenceEntry)
end)

RegisterNetEvent("plt_departments:server:pickUpEvidence")
AddEventHandler("plt_departments:server:pickUpEvidence", function(evidenceId)
    local playerId = source
    local evidenceEntry = activeEvidence[evidenceId]
    if not evidenceEntry then return end

    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local memberRecord = MemberData[player.citizenid]
    if not PlayerHasEvidenceAccess(player, memberRecord) then
        Framework.Notify(playerId, T("no_evidence_node"), "error")
        return
    end

    local requiredItem = (Config.Evidence and Config.Evidence.EvidenceItem) or "evidence_bag"
    if not Inventory.HasItem(playerId, requiredItem, 1) then
        Framework.Notify(playerId, T("need_evidence_bag"), "error")
        return
    end

    activeEvidence[evidenceId] = nil
    TriggerClientEvent("plt_departments:client:removeEvidence", -1, evidenceId)
    Inventory.RemoveItem(playerId, requiredItem, 1)

    local weaponStr = (evidenceEntry.weapon and tostring(evidenceEntry.weapon)) or "Unknown"
    local serial = evidenceEntry.serial
    
    if not serial or serial == "Unknown" or serial == "UNKNOWN" then
        serial = "SN-" .. math.random(1000, 9999)
    else
        serial = tostring(serial)
    end

    local bagMeta = {
        type   = "Bullet Casing",
        weapon = weaponStr,
        serial = serial,
        date   = os.date("%Y-%m-%d %H:%M:%S", evidenceEntry.timestamp),
        id     = evidenceId,
    }

    local addedItem = "filled_evidence_bag"
    local success = Inventory.AddItem(playerId, addedItem, 1, bagMeta)
    if not success then
        addedItem = "evidence_bag"
        success = Inventory.AddItem(playerId, addedItem, 1, bagMeta)
    end

    if success then
        Framework.Notify(playerId, T("evidence_collected", { item = addedItem }), "success")
    else
        Framework.Notify(playerId, "Failed to collect evidence! Inventory might be full.", "error")
    end
end)

RegisterNetEvent("plt_departments:server:printEvidenceReport")
AddEventHandler("plt_departments:server:printEvidenceReport", function(evidenceData)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local memberRecord = MemberData[player.citizenid]
    if not PlayerHasEvidenceAccess(player, memberRecord) then
        Framework.Notify(playerId, T("no_print_report_node"), "error")
        return
    end

    local report = {
        serial   = evidenceData.serial  or "UNKNOWN",
        weapon   = evidenceData.weapon  or "Unknown",
        caliber  = evidenceData.caliber or "Unknown",
        date     = evidenceData.date    or os.date("%Y-%m-%d %H:%M:%S"),
        officer  = player.name,
        reportId = "FORENSIC-" .. math.random(10000, 99999),
    }

    local success = Inventory.AddItem(playerId, "forensic_report", 1, report)
    if success then
        Framework.Notify(playerId, "Forensic report printed.", "success")
    else
        Framework.Notify(playerId, "Failed to print report. Check inventory space!", "error")
    end
end)

Framework.CreateCallback("plt_departments:server:getEvidence", function(source, cb)
    cb(activeEvidence)
end)

Framework.CreateCallback("plt_departments:server:getPlayerEvidence", function(source, cb)
    local ok, items = pcall(function()
        return Inventory.GetItems(source)
    end)

    if not ok or type(items) ~= "table" then
        cb({})
        return
    end

    local results = {}
    for _, item in ipairs(items) do
        local meta = (type(item.info) == "table" and item.info) or {}
        local isEvidenceItem = false

        if item.name == "filled_evidence_bag" then
            isEvidenceItem = true
        elseif item.name == "evidence_bag" then
            
            if meta.type == "Bullet Casing" or meta.weapon or meta.serial then
                isEvidenceItem = true
            end
        end

        if isEvidenceItem then
            table.insert(results, {
                serial = meta.serial or "UNKNOWN",
                weapon = meta.weapon or "Unknown",
                date   = meta.date   or "N/A",
                type   = meta.type   or "Bullet Casing",
                slot   = item.slot,
            })
        end
    end

    cb(results)
end)

CreateThread(function()
    while true do
        Wait(300000) 
        local now = os.time()
        local lifetimeSeconds = ((Config.Evidence and Config.Evidence.CasingLifeTime) or 30) * 60

        for id, entry in pairs(activeEvidence) do
            if (now - entry.timestamp) > lifetimeSeconds then
                activeEvidence[id] = nil
                TriggerClientEvent("plt_departments:client:removeEvidence", -1, id)
            end
        end
    end
end)

