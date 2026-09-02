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


local jailSessions = {}

local function IsPlayerCuffed(playerId)
    local playerState = Player(playerId)
    if not playerState or not playerState.state then return false end
    return playerState.state.isCuffed or playerState.state.ishandcuffed or false
end

local function CheckNotCuffed(playerId)
    if IsPlayerCuffed(playerId) then
        Framework.Notify(playerId, T("cannot_while_cuffed"), "error")
        return false
    end
    return true
end

local function GetJailConfig()
    local cfg = (Config and Config.Jail) or {}
    return {
        enabled         = cfg.Enabled ~= false,
        minMinutes      = tonumber(cfg.MinMinutes) or 0,
        maxMinutes      = tonumber(cfg.MaxMinutes) or 60,
        maxDistance     = tonumber(cfg.MaxDistance) or 2.0,
        jailLocation    = cfg.JailLocation    or { x = 1680.16, y = 2513.45, z = 45.56, h = 270.0 },
        releaseLocation = cfg.ReleaseLocation or { x = 425.1,   y = -979.5,  z = 30.7,  h = 90.0  },
        returnToInitial = cfg.ReturnToInitialPosition ~= false,
    }
end

local function ParseCoords(raw)
    if type(raw) ~= "table" then return nil end
    local x, y, z = tonumber(raw.x), tonumber(raw.y), tonumber(raw.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z, h = tonumber(raw.h) or 0.0 }
end

local function ToggleCuffPlayer(officerId, targetId, animType, pairedMode)
    if not CoreEngine.IsHired(officerId)  then return false end
    if not CheckNotCuffed(officerId)      then return false end

    local handcuffsCfg = Config and Config.Handcuffs
    if handcuffsCfg and handcuffsCfg.RequireItem then
        local itemName = handcuffsCfg.ItemName or "handcuffs"
        if not Inventory.HasItem(officerId, itemName, 1) then
            Framework.Notify(officerId, T("need_handcuffs"), "error")
            return false
        end
    end

    if not Framework.GetPlayer(targetId) then return false end

    local targetIsCuffed = IsPlayerCuffed(targetId)

    if targetIsCuffed then
        if handcuffsCfg and handcuffsCfg.RequireKey then
            local keyItem = handcuffsCfg.KeyItemName or "handcuff_key"
            if not Inventory.HasItem(officerId, keyItem, 1) then
                Framework.Notify(officerId, T("need_handcuff_key"), "error")
                return false
            end
        end
    end

    if pairedMode and not targetIsCuffed then
        TriggerClientEvent("plt_departments:client:CuffAnimPaired", officerId, targetId)
        TriggerClientEvent("plt_departments:client:GetCuffedPaired", targetId, officerId)
    else
        TriggerClientEvent("plt_departments:client:CuffAnim",  officerId, targetIsCuffed)
        TriggerClientEvent("plt_departments:client:GetCuffed", targetId, officerId, animType)
    end
    return true
end

local function CuffPlayer(officerId, targetId, animType, pairedMode)
    if not CoreEngine.IsHired(officerId) then return false end
    if not CheckNotCuffed(officerId)     then return false end
    if not Framework.GetPlayer(targetId) then return false end

    if IsPlayerCuffed(targetId) then return false end

    return ToggleCuffPlayer(officerId, targetId, animType, pairedMode)
end

local function UncuffPlayer(officerId, targetId, animType)
    if not CoreEngine.IsHired(officerId) then return false end
    if not CheckNotCuffed(officerId)     then return false end
    if not Framework.GetPlayer(targetId) then return false end

    if not IsPlayerCuffed(targetId) then return false end

    TriggerClientEvent("plt_departments:client:CuffAnim",  officerId, true)
    TriggerClientEvent("plt_departments:client:GetCuffed", targetId, officerId, animType)
    return true
end

RegisterNetEvent("plt_departments:server:CuffPlayer")
AddEventHandler("plt_departments:server:CuffPlayer", function(targetId, animType, pairedMode, modeOverride)
    local officerId = source
    local mode = modeOverride and tostring(modeOverride):lower() or "toggle"

    if mode == "cuff" then
        CuffPlayer(officerId, targetId, animType, pairedMode)
    elseif mode == "uncuff" then
        UncuffPlayer(officerId, targetId, animType)
    else
        ToggleCuffPlayer(officerId, targetId, animType, pairedMode)
    end
end)

exports("CuffPlayer",       CuffPlayer)
exports("UncuffPlayer",     UncuffPlayer)
exports("ToggleCuffPlayer", ToggleCuffPlayer)

exports("SeizeVehicle", function(playerId, plate, reason, extra)
    if PLTLibServer and PLTLibServer.SeizeVehicle then
        return PLTLibServer.SeizeVehicle(playerId, plate, reason, extra)
    end
end)

RegisterNetEvent("plt_departments:server:ForceTargetAnim")
AddEventHandler("plt_departments:server:ForceTargetAnim", function(targetId, animDict, animName)
    if not Player(targetId) then return end
    TriggerClientEvent("plt_departments:client:ForceAnim", targetId, animDict, animName)
end)

RegisterNetEvent("plt_departments:server:SearchPlayer")
AddEventHandler("plt_departments:server:SearchPlayer", function(targetId)
    local officerId = source
    if not CoreEngine.IsHired(officerId) then return end
    if not CheckNotCuffed(officerId)     then return end
    Inventory.OpenPlayerInventory(officerId, targetId)
end)

RegisterNetEvent("plt_departments:server:setPlayerEscort")
AddEventHandler("plt_departments:server:setPlayerEscort", function(targetId, startEscort, vehicleNetId, vehicleSeat, exitVehicle)
    local officerId  = source
    if not CoreEngine.IsHired(officerId) then return end
    if not CheckNotCuffed(officerId)     then return end

    local targetState = Player(targetId)
    if not targetState then return end

    local currentEscortBy = targetState.state.isEscorted

    if startEscort == false or (startEscort == nil and currentEscortBy == officerId) then
        targetState.state:set("isEscorted", false, true)
        TriggerClientEvent("plt_departments:client:StopOfficerEscort", officerId)

        if vehicleNetId and vehicleSeat then
            TriggerClientEvent("plt_departments:client:setInVehicle", targetId, vehicleNetId, vehicleSeat)
        elseif exitVehicle then
            TriggerClientEvent("plt_departments:client:exitVehicle", targetId)
        end
    else
        targetState.state:set("isEscorted", officerId, true)
        TriggerClientEvent("plt_departments:client:StartOfficerEscort", officerId)
    end
end)

RegisterNetEvent("plt_departments:server:officerAction")
AddEventHandler("plt_departments:server:officerAction", function(_, _)
    
    local _ = source
end)

RegisterNetEvent("plt_departments:server:JailPlayer")
AddEventHandler("plt_departments:server:JailPlayer", function(targetId, minutes, reason)
    local officerId = source
    local jailCfg   = GetJailConfig()

    if not jailCfg.enabled              then return end
    if not CoreEngine.IsHired(officerId) then return end
    if not CheckNotCuffed(officerId)     then return end

    local targetServerId = tonumber(targetId)
    if not targetServerId then return end

    local targetPlayer = Framework.GetPlayer(targetServerId)
    if not targetPlayer then
        Framework.Notify(officerId, T("could_not_find_player", { id = tostring(targetServerId) }), "error")
        return
    end

    local officerPed = GetPlayerPed(officerId)
    local targetPed  = GetPlayerPed(targetServerId)
    if officerPed == 0 or targetPed == 0 then return end

    local officerCoords = GetEntityCoords(officerPed)
    local targetCoords  = GetEntityCoords(targetPed)
    if #(officerCoords - targetCoords) > jailCfg.maxDistance then
        Framework.Notify(officerId, T("no_one_nearby"), "error")
        return
    end

    local jailMinutes = math.floor(tonumber(minutes) or jailCfg.minMinutes)
    jailMinutes = math.max(jailCfg.minMinutes, math.min(jailCfg.maxMinutes, jailMinutes))

    local cleanReason = tostring(reason or ""):gsub("^%s*(.-)%s*$", "%1")
    if cleanReason == "" then
        Framework.Notify(officerId, "A reason is required.", "error")
        return
    end

    local jailCoords    = ParseCoords(jailCfg.jailLocation)
    local releaseCoords = ParseCoords(jailCfg.releaseLocation)
    if not jailCoords then return end

    local initialPos = {
        x = targetCoords.x,
        y = targetCoords.y,
        z = targetCoords.z,
        h = GetEntityHeading(targetPed),
    }

    local officerPlayer = Framework.GetPlayer(officerId)
    local officerName   = (officerPlayer and officerPlayer.name) or ("Officer " .. tostring(officerId))

    local sessionToken = string.format("%s:%s:%s",
        tostring(os.time()),
        tostring(officerId),
        tostring(math.random(1000, 9999))
    )

    jailSessions[targetServerId] = {
        token      = sessionToken,
        initialPos = initialPos,
        releasePos = releaseCoords,
        reason     = cleanReason,
    }

    TriggerClientEvent("plt_departments:client:TeleportToCoords", targetServerId, jailCoords)
    Framework.Notify(officerId,      string.format("Jailed player for %d minute(s).", jailMinutes), "success")
    Framework.Notify(targetServerId, string.format("%s jailed you for %d minute(s). Reason: %s", officerName, jailMinutes, cleanReason), "error")

    SetTimeout(jailMinutes * 60000, function()
        local session = jailSessions[targetServerId]
        if not session or session.token ~= sessionToken then return end

        local releasePos = (jailCfg.returnToInitial and session.initialPos) or session.releasePos
        if releasePos then
            TriggerClientEvent("plt_departments:client:TeleportToCoords", targetServerId, releasePos)
            Framework.Notify(targetServerId, "Your jail time is over.", "success")
        end
        jailSessions[targetServerId] = nil
    end)
end)

RegisterNetEvent("plt_departments:server:SendCitation")
AddEventHandler("plt_departments:server:SendCitation", function(targetId, reason, amount, location, vehicleData)
    local officerId = source
    if not CoreEngine.IsHired(officerId) then return end

    local targetServerId = tonumber(targetId)
    local officerPlayer  = Framework.GetPlayer(officerId)
    local targetPlayer   = Framework.GetPlayer(targetServerId)

    if not officerPlayer then return end
    if not targetPlayer then
        Framework.Notify(officerId, T("could_not_find_player", { id = tostring(targetServerId) }), "error")
        return
    end

    local officerName  = officerPlayer.name
    local targetName   = targetPlayer.name
    local officerCid   = officerPlayer.citizenid
    local officerMember = MemberData[officerCid]

    local officerLastName = (officerPlayer.charinfo and officerPlayer.charinfo.lastname) or "Officer"

    local deptLabel = "CITY OF LOS SANTOS"
    if officerMember and officerMember.dept and DepartmentData and DepartmentData.nodes then
        for _, node in ipairs(DepartmentData.nodes) do
            if node.id == officerMember.dept then
                deptLabel = node.label:upper()
                break
            end
        end
    end

    local citationData = {
        officerName   = officerName,
        officerSource = officerId,
        targetName    = targetName,
        targetCID     = targetPlayer.citizenid,
        reason        = reason,
        amount        = amount,
        location      = location or "Unknown Location",
        time          = os.date("%H:%M"),
        date          = os.date("%m/%d/%Y"),
        deptLabel     = deptLabel,
        vehicle       = vehicleData or { plate = "NONE", model = "PEDESTRIAN", color = "N/A" },
    }

    TriggerClientEvent("plt_departments:client:ShowCitation", targetServerId, citationData)
    Framework.Notify(targetServerId, T("citation_issued",  { name = officerLastName }), "primary")
    Framework.Notify(officerId,      T("citation_sent",    { name = targetName }),      "success")
end)

RegisterNetEvent("plt_departments:server:PayCitation")
AddEventHandler("plt_departments:server:PayCitation", function(amount, officerServerId)
    local targetId       = source
    local officerSrvId   = tonumber(officerServerId)
    local parsedAmount   = tonumber(amount)

    local targetPlayer   = Framework.GetPlayer(targetId)
    local officerPlayer  = Framework.GetPlayer(officerSrvId)
    if not targetPlayer then return end

    local success = targetPlayer.functions.RemoveMoney("bank", parsedAmount, "traffic-citation")
    if success then
        Framework.Notify(targetId, T("citation_signed_paid", { amount = parsedAmount }), "success")

        if officerPlayer then
            local officerMember = MemberData[officerPlayer.citizenid]
            if officerMember and officerMember.dept and officerMember.dept ~= "none" then
                local deptId      = officerMember.dept
                local defaultBal  = (Config and Config.DefaultDeptBalance) or 0
                DeptBalances[deptId] = (DeptBalances[deptId] or defaultBal) + parsedAmount
                SaveBalances()
                UpdateFinanceHistory(deptId)
                AddFinanceTransaction(deptId, "fine_paid", parsedAmount,
                    { name = officerPlayer.name, cid = officerPlayer.citizenid },
                    { name = targetPlayer.name,  cid = targetPlayer.citizenid  },
                    "Signed Traffic Citation"
                )
                TriggerClientEvent("plt_departments:client:SyncFinances", -1, FinanceHistory, DeptBalances)
            end
        end

        local payerName = (Framework.GetPlayer(targetId) and Framework.GetPlayer(targetId).name) or "Unknown"
        Framework.Notify(officerSrvId, T("citation_signed_target", { name = payerName }), "success")
    else
        Framework.Notify(targetId, T("insufficient_funds_citation"), "error")
    end
end)

RegisterNetEvent("plt_departments:server:DeclineCitation")
AddEventHandler("plt_departments:server:DeclineCitation", function(amount, officerServerId)
    local targetId      = source
    local officerSrvId  = tonumber(officerServerId)
    local parsedAmount  = tonumber(amount)

    local targetPlayer  = Framework.GetPlayer(targetId)
    local officerPlayer = Framework.GetPlayer(officerSrvId)
    if not targetPlayer then return end

    local officerDeptId = "none"
    if officerPlayer then
        local officerMember = MemberData[officerPlayer.citizenid]
        if officerMember and officerMember.dept then
            officerDeptId = officerMember.dept
        end
    end

    local officerName = (officerPlayer and officerPlayer.name) or "Unknown"
    local targetName  = (Framework.GetPlayer(targetId) and Framework.GetPlayer(targetId).name)
                        or "Unknown"

    table.insert(DelayedPayments, {
        targetCid  = targetPlayer.citizenid,
        targetName = targetName,
        officerCid = (officerPlayer and officerPlayer.citizenid) or "none",
        officerName = officerName,
        amount     = parsedAmount,
        deptId     = officerDeptId,
        dueAt      = os.time() + 172800,
        deniedAt   = os.time(),
    })
    SaveDelayedPayments()

    Framework.Notify(targetId,     T("citation_declined",         { amount = parsedAmount }), "error")
    if officerPlayer then
        Framework.Notify(officerSrvId, T("citation_declined_officer", { name = targetName }),   "primary")
    end
end)
