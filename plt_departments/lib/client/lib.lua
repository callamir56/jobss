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


PLTClientNodes = PLTClientNodes or {}
PLTLibClient   = PLTLibClient   or {}

local security = {
    verified = false,
    nonce    = nil,
}

local isBossMenuOpen = false

local currentRadioFrequency = 0

local isRadioAnimPlaying = false

local Events = {
    challengeClient      = "plt_departments:c:k",
    challengeReply       = "plt_departments:s:k",
    keepAlive            = "plt_departments:s:p",
    requestSync          = "plt_departments:s0",
    toggleDuty           = "plt_departments:s3",
    takeArmory           = "plt_departments:s4",
    updateDoor           = "plt_departments:s5",
    joinRadio            = "plt_departments:s6",
    leaveRadio           = "plt_departments:s7",
    moveRadio            = "plt_departments:s8",
    saveData             = "plt_departments:s9",
    hirePlayer           = "plt_departments:sa",
    updateRankSalary     = "plt_departments:sb",
    manageDivision       = "plt_departments:sc",
    toggleMemberDivision = "plt_departments:sd",
    financeAction        = "plt_departments:se",
    distributeSalaries   = "plt_departments:sf",
    toggleAutoPay        = "plt_departments:sg",
    submitOfficerReport  = "plt_departments:sh",
    openStash            = "plt_departments:si",
}

local function SafeToString(value)
    if value == nil then return nil end
    return tostring(value)
end

local function GetSpeedUnitLabel()
    local unit = tostring(Config.SpeedUnit or "kmh"):lower()
    return (unit == "mph") and "MPH" or "KM/H"
end

function PLTClientNodes.GetNodeById(nodeId, departmentData)
    if not (departmentData and departmentData.nodes) then return nil end
    local idStr = SafeToString(nodeId)
    if not idStr then return nil end
    for _, node in ipairs(departmentData.nodes) do
        if SafeToString(node.id) == idStr then
            return node
        end
    end
    return nil
end

function PLTClientNodes.ResolveDepartment(startNodeId, departmentData)
    if not (departmentData and departmentData.links) then return nil end

    local startStr = SafeToString(startNodeId)
    if not startStr then return nil end

    local startNode = PLTClientNodes.GetNodeById(startStr, departmentData)
    if startNode and startNode.type == "department" then
        return startNode.id
    end

    local visited = { [startStr] = true }
    local queue   = { startStr }

    while #queue > 0 do
        local current = table.remove(queue, 1)

        for _, link in ipairs(departmentData.links) do
            
            local fromStr = SafeToString(link.from)
            local toStr   = SafeToString(link.to)
            local neighbour = nil

            if fromStr == current then
                neighbour = toStr
            elseif toStr == current then
                neighbour = fromStr
            end

            if neighbour and not visited[neighbour] then
                local neighbourNode = PLTClientNodes.GetNodeById(neighbour, departmentData)
                if neighbourNode then
                    if neighbourNode.type == "department" then
                        return neighbourNode.id
                    end
                    visited[neighbour] = true
                    table.insert(queue, neighbour)
                end
            end
        end
    end

    return nil
end

function PLTClientNodes.GetDepartmentArmoryNode(nodeId, departmentData)
    if not (departmentData and departmentData.nodes) then return nil end

    local deptId = PLTClientNodes.ResolveDepartment(nodeId, departmentData)
    if not deptId then return nil end

    for _, node in ipairs(departmentData.nodes) do
        if node.type == "armory" then
            local armoryDeptId = PLTClientNodes.ResolveDepartment(node.id, departmentData)
            if armoryDeptId and tostring(armoryDeptId) == tostring(deptId) then
                return node
            end
        end
    end

    return nil
end

function PLTClientNodes.GetLinkedArmoryNode(nodeId, departmentData)
    if not (departmentData and departmentData.nodes and departmentData.links) then return nil end

    local nodeStr = SafeToString(nodeId)
    if not nodeStr then return nil end

    for _, link in ipairs(departmentData.links) do
        local fromStr = SafeToString(link.from)
        local toStr   = SafeToString(link.to)
        local neighbour = nil

        if fromStr == nodeStr then
            neighbour = toStr
        elseif toStr == nodeStr then
            neighbour = fromStr
        end

        if neighbour then
            local node = PLTClientNodes.GetNodeById(neighbour, departmentData)
            if node and node.type == "armory" then
                return node
            end
        end
    end

    return PLTClientNodes.GetDepartmentArmoryNode(nodeId, departmentData)
end

function GetFrameworkJobFromNodeId(nodeId)
    if not (DepartmentData and DepartmentData.nodes) then return nodeId end

    local searchStr = tostring(nodeId):lower()

    for _, node in ipairs(DepartmentData.nodes) do
        if tostring(node.id):lower() == searchStr and node.type == "department" then
            if node.frameworkJob and node.frameworkJob ~= "" then
                return tostring(node.frameworkJob):lower()
            end
            break
        end
    end

    return searchStr
end

function GetDepartmentForNode(nodeId, departmentData)
    if PLTClientNodes and PLTClientNodes.ResolveDepartment then
        return PLTClientNodes.ResolveDepartment(nodeId, departmentData)
    end
    return nil
end

function PLTLibClient.SecureTriggerServer(eventName, ...)
    if not security.verified then return false end
    TriggerServerEvent(eventName, ...)
    return true
end

local function BuildGradeFilteredList(itemList, category)
    local result = {}
    if not (itemList and #itemList > 0) then return result end

    for _, item in ipairs(itemList) do
        local minGrade = tonumber(item.minGrade)
        if not minGrade or (LocalPlayerJob and LocalPlayerJob.grade >= minGrade) then
            table.insert(result, {
                name     = item.model,
                label    = item.label,
                icon     = item.icon,
                category = category,
                grade    = item.minGrade or 0,
                limit    = tonumber(item.limit) or 0,
            })
        end
    end

    return result
end

function PLTLibClient.HandleInteract(locData)
    local locType = locData.locType
    local job     = locData.job
    local nodeId  = locData.nodeId
    local coords  = locData.coords

    if "duty" == locType then
        SetNuiFocus(true, true)
        SendNUIMessage({ action = "startSwipeMinigame" })

    elseif "stash" == locType then
        TriggerServerEvent(Events.openStash, job, nodeId)

    elseif "evidence" == locType then
        TriggerEvent("plt_departments:client:openForensicPC")

    elseif locType == "garage" or locType == "impound" or locType == "helipad" or locType == "armory" then
        Framework.TriggerCallback("plt_departments:server:GetData", function(serverData)
            local deptData    = serverData.departments
            local weapons     = {}
            local items       = {}
            local vehicles    = {}
            local spawnPoints = {}

            local deptId     = GetDepartmentForNode(nodeId, deptData)
            local linkedArmoryNode = nil
            local deptLabel  = nil

            if deptId then
                local deptNode = PLTClientNodes.GetNodeById(deptId, deptData)
                if deptNode and deptNode.label and deptNode.label ~= "" then
                    deptLabel = tostring(deptNode.label)
                end
            end

            if locType == "armory" then
                if PLTClientNodes and PLTClientNodes.GetLinkedArmoryNode then
                    linkedArmoryNode = PLTClientNodes.GetLinkedArmoryNode(nodeId, deptData)
                end
            end

            for _, node in ipairs(deptData.nodes) do
                local nodeMatches = false

                if locType == "helipad" and node.type == "helipad" then
                    nodeMatches = true
                elseif locType == "garage" and node.type == "vehicle" then
                    nodeMatches = true
                elseif locType == "armory" and node.type == "armory" then
                    nodeMatches = true
                elseif locType == "impound" and (node.type == "vehicle" or node.type == "helipad") then
                    nodeMatches = true
                end

                if nodeMatches then
                    local nodeDeptId = GetDepartmentForNode(node.id, deptData)
                    local isArmoryType = (locType == "armory")

                    if isArmoryType and linkedArmoryNode then
                        
                        if tostring(node.id) == tostring(linkedArmoryNode.id) then
                            local nodeWeapons = BuildGradeFilteredList(node.weapons, "Firearms")
                            for _, w in ipairs(nodeWeapons) do table.insert(weapons, w) end
                            local nodeItems = BuildGradeFilteredList(node.items, "Equipment")
                            for _, i in ipairs(nodeItems) do table.insert(items, i) end
                        end
                    elseif nodeDeptId and deptId and tostring(nodeDeptId) == tostring(deptId) then
                        
                        if isArmoryType then
                            local nodeWeapons = BuildGradeFilteredList(node.weapons, "Firearms")
                            for _, w in ipairs(nodeWeapons) do table.insert(weapons, w) end
                            local nodeItems = BuildGradeFilteredList(node.items, "Equipment")
                            for _, i in ipairs(nodeItems) do table.insert(items, i) end
                        elseif locType == "garage" or locType == "helipad" then
                            if node.vehicles then
                                for _, veh in ipairs(node.vehicles) do
                                    local minGrade = tonumber(veh.minGrade)
                                    if not minGrade or (LocalPlayerJob and LocalPlayerJob.grade >= minGrade) then
                                        table.insert(vehicles, veh)
                                    end
                                end
                            end
                        elseif locType == "impound" then
                            
                        end

                        local spList = (locType == "impound" and node.impoundSpawnPoints) or node.spawnPoints
                        if spList then
                            for _, sp in ipairs(spList) do table.insert(spawnPoints, sp) end
                        end
                    end
                end
            end

            if locType == "armory" then
                
                local armoryNodeId = (linkedArmoryNode and linkedArmoryNode.id) or nodeId
                if PLTSetArmoryNodeId then PLTSetArmoryNodeId(armoryNodeId) end

                SetNuiFocus(true, true)
                if PLTPushLocaleToNUI then PLTPushLocaleToNUI() end

                local title = deptLabel and (deptLabel:upper() .. " ARMORY")
                           or (tostring(job):upper() .. " ARMORY")

                SendNUIMessage({
                    action        = "openArmory",
                    deptName      = title,
                    inventoryType = tostring(Config.Inventory or "qb"),
                    weapons       = weapons,
                    items         = items,
                })

            elseif locType == "impound" then
                Framework.TriggerCallback("plt_departments:server:getImpoundedVehicles", function(impoundedVehicles)
                    if #impoundedVehicles > 0 then
                        SetNuiFocus(true, true)
                        if PLTPushLocaleToNUI then PLTPushLocaleToNUI() end
                        local title = (tostring(job):upper()) .. " IMPOUND"
                        SendNUIMessage({
                            action      = "openGarage",
                            vehicles    = impoundedVehicles,
                            spawnPoints = spawnPoints,
                            deptName    = title,
                        })
                    else
                        Framework.Notify(T("no_impounded_vehicles"), "primary")
                    end
                end)

            else
                
                if #vehicles > 0 then
                    local suffix = (locType == "helipad") and " HELIPAD" or " GARAGE"
                    local title  = (tostring(job):upper()) .. suffix

                    SetNuiFocus(true, true)
                    if PLTPushLocaleToNUI then PLTPushLocaleToNUI() end
                    SendNUIMessage({
                        action      = "openGarage",
                        vehicles    = vehicles,
                        spawnPoints = spawnPoints,
                        deptName    = title,
                    })
                else
                    local msg = (locType == "helipad")
                        and T("no_aircraft_configured")
                        or  T("no_vehicles_configured")
                    Framework.Notify(msg, "error")
                end
            end
        end)

    elseif "store" == locType then
        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
            Framework.Notify(T("vehicle_stored"), "success")
        else
            Framework.Notify(T("must_be_in_vehicle"), "error")
        end

    elseif "boss_menu" == locType then
        Framework.TriggerCallback("plt_departments:server:GetData", function(serverData)
            if not serverData then
                Framework.Notify(T("failed_fetch_data"), "error")
                return
            end
            local deptData = serverData.departments
            if not (deptData and deptData.links and deptData.nodes) then return end

            local deptId   = GetDepartmentForNode(nodeId, deptData)
            local rankNode = nil
            if deptId then
                local deptIdStr = tostring(deptId)
                for _, link in ipairs(deptData.links) do
                    local neighbour = nil
                    if tostring(link.from) == deptIdStr then neighbour = link.to
                    elseif tostring(link.to) == deptIdStr then neighbour = link.from
                    end
                    if neighbour then
                        local node = PLTClientNodes.GetNodeById(neighbour, deptData)
                        if node and node.type == "rank" then
                            rankNode = node
                            break
                        end
                    end
                end
            end

            if not rankNode then
                Framework.Notify(T("no_boss_perms"), "error")
                return
            end

            local playerRankEntry = nil
            if rankNode.ranks then
                for _, rank in ipairs(rankNode.ranks) do
                    if tonumber(rank.level) == tonumber(LocalPlayerJob and LocalPlayerJob.grade) then
                        playerRankEntry = rank
                        break
                    end
                end
            end

            if not playerRankEntry or not playerRankEntry.bossMenu then
                Framework.Notify(T("no_boss_perms"), "error")
                return
            end

            PLTLibClient.OpenBossMenuUI(
                deptData,
                job,
                nodeId,
                serverData.departmentCatalog,
                serverData.finances,
                serverData.balances,
                serverData.members,
                serverData.warrants,
                serverData.cases,
                serverData.bolos,
                serverData.dutyLogs,
                serverData.transactions,
                serverData.autoPay,
                serverData.radars,
                serverData.news,
                serverData.mails
            )
        end)
    end
end

PLTLibClient.HandleInteract = PLTLibClient.HandleInteract

function PLTLibClient.OpenBossMenuUI(
    deptData, jobName, nodeId,
    departmentCatalog, finances, balances,
    members, warrants, cases, bolos,
    dutyLogs, transactions, autoPay,
    radars, news, mails
)
    if isBossMenuOpen then return end
    if type(deptData) ~= "table" then return end

    departmentCatalog = type(departmentCatalog) == "table" and departmentCatalog or {}
    finances          = type(finances)          == "table" and finances          or {}
    balances          = type(balances)          == "table" and balances          or {}
    members           = type(members)           == "table" and members           or {}
    warrants          = type(warrants)          == "table" and warrants          or {}
    cases             = type(cases)             == "table" and cases             or {}
    bolos             = type(bolos)             == "table" and bolos             or {}
    dutyLogs          = type(dutyLogs)          == "table" and dutyLogs          or {}
    transactions      = type(transactions)      == "table" and transactions      or {}
    autoPay           = type(autoPay)           == "table" and autoPay           or {}
    radars            = type(radars)            == "table" and radars            or {}
    news              = type(news)              == "table" and news              or {}
    mails             = type(mails)             == "table" and mails             or {}

    local playerData = Framework.GetPlayerData and Framework.GetPlayerData()
    local playerName = (playerData and playerData.name)
                    or GetPlayerName(PlayerId())
                    or "OFFICER"

    local playerGrade = (LocalPlayerJob and LocalPlayerJob.grade) or 0
    local rankLabel   = "RANK " .. tostring(playerGrade)

    if nodeId and deptData.links and deptData.nodes and LocalPlayerJob then
        for _, link in ipairs(deptData.links) do
            local neighbour = nil
            if tostring(link.from) == tostring(nodeId) then
                neighbour = link.to
            elseif tostring(link.to) == tostring(nodeId) then
                neighbour = link.from
            end

            if neighbour then
                for _, node in ipairs(deptData.nodes) do
                    if tostring(node.id) == tostring(neighbour) and node.type == "rank" then
                        if node.ranks then
                            for _, rank in ipairs(node.ranks) do
                                if tonumber(rank.level) == tonumber(playerGrade) and rank.label then
                                    rankLabel = rank.label
                                end
                            end
                        end
                        break
                    end
                end
                break
            end
        end
    end

    isBossMenuOpen = true
    SetNuiFocus(true, true)
    if PLTPushLocaleToNUI then PLTPushLocaleToNUI() end

    SendNUIMessage({
        action            = "openBossMenu",
        theme             = Config.BossMenuTheme or "modern",
        jobName           = jobName,
        playerName        = playerName,
        playerRank        = rankLabel,
        data              = deptData,
        departmentCatalog = departmentCatalog,
        members           = members,
        finances          = finances,
        balances          = balances,
        warrants          = warrants,
        cases             = cases,
        bolos             = bolos,
        dutyLogs          = dutyLogs,
        transactions      = transactions,
        autoPay           = autoPay,
        radars            = radars,
        speedUnit         = GetSpeedUnitLabel(),
        news              = news,
        mails             = mails,
    })
end

PLTLibClient.OpenBossMenuUI = PLTLibClient.OpenBossMenuUI

function PLTLibClient.HandleSpawnVehicle(vehicleData, cb)
    if not (vehicleData.spawnPoints and #vehicleData.spawnPoints > 0) then
        Framework.Notify(T("no_spawn_points"), "error")
        cb("ok")
        return
    end

    local playerPos = GetEntityCoords(PlayerPedId())

    local rankedPoints = {}
    for _, sp in ipairs(vehicleData.spawnPoints) do
        if sp and sp.x and sp.y and sp.z then
            local dist = #(playerPos - vector3(sp.x, sp.y, sp.z))
            table.insert(rankedPoints, { point = sp, distance = dist })
        end
    end
    table.sort(rankedPoints, function(a, b) return a.distance < b.distance end)

    local chosenPoint = nil
    for _, entry in ipairs(rankedPoints) do
        local sp    = entry.point
        local pos   = vector3(sp.x, sp.y, sp.z)
        local nearby = GetClosestVehicle(pos.x, pos.y, pos.z, 3.0, 0, 71)
        if not DoesEntityExist(nearby) then
            chosenPoint = sp
            break
        end
    end

    if not chosenPoint then
        
        if Framework.Type == "esx" then
            Framework.Notify("No nearby free spawn point found. Move closer to this garage.", "error")
        else
            Framework.Notify(T("all_spawn_points_blocked"), "error")
        end
        cb("ok")
        return
    end

    local function GetTrimmedPlate(vehicle)
        local plate = (type(Framework.GetPlate) == "function") and Framework.GetPlate(vehicle) or ""
        if plate == "" then
            local raw = GetVehicleNumberPlateText(vehicle)
            if raw then
                plate = raw:gsub("^%s*(.-)%s*$", "%1") or ""
            end
        end
        return plate
    end

    local spawnHeading = (chosenPoint.h or 0.0) + 0.0
    local spawnPos     = vector3(chosenPoint.x, chosenPoint.y, chosenPoint.z)

    local function DoSpawn()
        SetNuiFocus(false, false)

        local ok = pcall(function()
            Framework.SpawnVehicle(vehicleData.model, function(spawnedVehicle)
                if not (spawnedVehicle and spawnedVehicle ~= 0 and DoesEntityExist(spawnedVehicle)) then
                    Framework.Notify("Vehicle spawn failed at target location.", "error")
                    return
                end

                if vehicleData.isImpounded then
                    Framework.SetVehicleProperties(spawnedVehicle, vehicleData.props)
                else
                    local livery = tonumber(vehicleData.livery)
                    if livery ~= nil and livery >= 0 then
                        SetVehicleModKit(spawnedVehicle, 0)
                        if GetVehicleLiveryCount(spawnedVehicle) > 0 then
                            SetVehicleLivery(spawnedVehicle, livery)
                        end
                        if GetNumVehicleMods(spawnedVehicle, 48) > 0 then
                            SetVehicleMod(spawnedVehicle, 48, livery, false)
                        end
                    end
                end

                SetEntityHeading(spawnedVehicle, spawnHeading)
                SetVehicleOnGroundProperly(spawnedVehicle)

                CreateThread(function()
                    for _ = 1, 10 do
                        if DoesEntityExist(spawnedVehicle) then
                            SetEntityHeading(spawnedVehicle, spawnHeading)
                        end
                        Wait(10)
                    end
                end)

                local plate = GetTrimmedPlate(spawnedVehicle)
                if Framework.Type == "qb" then
                    TriggerEvent("vehiclekeys:client:SetOwner", plate)
                else
                    TriggerEvent("esx_givecarkeys:setOwner", plate)
                end

                SetVehicleEngineOn(spawnedVehicle, true, true)
                local notifKey = vehicleData.isImpounded and "vehicle_unimpounded" or "vehicle_spawned"
                Framework.Notify(T(notifKey), "success")
            end, spawnPos, true)
        end)

        if not ok then
            Framework.Notify("Vehicle spawn failed. Move closer to this garage and try again.", "error")
        end
    end

    if vehicleData.isImpounded then
        Framework.TriggerCallback("plt_departments:server:canUnimpound", function(canUnimpound)
            if canUnimpound then DoSpawn() end
        end, vehicleData.plate)
    else
        DoSpawn()
    end

    cb("ok")
end

PLTLibClient.HandleSpawnVehicle = PLTLibClient.HandleSpawnVehicle

function PLTLibClient.RegisterCoreCallbacks()

    RegisterNetEvent(Events.challengeClient)
    AddEventHandler(Events.challengeClient, function(rawNonce)
        local nonce = tonumber(rawNonce)
        security.nonce    = nonce
        security.verified = false
        if nonce then
            local response = (nonce * 7 + 13) % 1000000
            TriggerServerEvent(Events.challengeReply, response)
            security.verified = true
        end
    end)

    CreateThread(function()
        while true do
            Wait(45000)
            if security.verified then
                TriggerServerEvent(Events.keepAlive)
            end
        end
    end)

    local function SyncToNUI(payload)
        SendNUIMessage(payload)
    end

    RegisterNetEvent("plt_departments:client:SyncWarrants")
    AddEventHandler("plt_departments:client:SyncWarrants", function(data)
        SyncToNUI({ action = "syncData", warrants = data })
    end)

    RegisterNetEvent("plt_departments:client:SyncCaseFiles")
    AddEventHandler("plt_departments:client:SyncCaseFiles", function(data)
        SyncToNUI({ action = "syncData", cases = data })
    end)

    RegisterNetEvent("plt_departments:client:SyncBolos")
    AddEventHandler("plt_departments:client:SyncBolos", function(data)
        SyncToNUI({ action = "syncData", bolos = data })
    end)

    RegisterNetEvent("plt_departments:client:SyncNews")
    AddEventHandler("plt_departments:client:SyncNews", function(data)
        SyncToNUI({ action = "syncData", news = data })
    end)

    RegisterNetEvent("plt_departments:client:SyncDutyLogs")
    AddEventHandler("plt_departments:client:SyncDutyLogs", function(data)
        SyncToNUI({ action = "syncData", dutyLogs = data })
    end)

    RegisterNetEvent("plt_departments:client:SyncDepartmentMail")
    AddEventHandler("plt_departments:client:SyncDepartmentMail", function(data)
        SyncToNUI({ action = "syncData", mails = data })
    end)

    RegisterNetEvent("plt_departments:client:SyncRadioChannels")
    AddEventHandler("plt_departments:client:SyncRadioChannels", function(channels)
        SyncToNUI({ action = "syncRadioChannels", channels = channels })
    end)

    RegisterNetEvent("plt_departments:client:SyncTransactions")
    AddEventHandler("plt_departments:client:SyncTransactions", function(data)
        SyncToNUI({ action = "syncTransactions", transactions = data })
    end)

    RegisterNetEvent("plt_departments:client:SyncFinances")
    AddEventHandler("plt_departments:client:SyncFinances", function(finances, balances)
        Framework.TriggerCallback("plt_departments:server:GetData", function(serverData)
            SyncToNUI({
                action       = "syncData",
                finances     = finances,
                balances     = balances,
                members      = serverData.members,
                data         = serverData.departments,
                transactions = serverData.transactions,
            })
        end)
    end)

    RegisterNetEvent("plt_departments:client:SyncFinancesWithAuto")
    AddEventHandler("plt_departments:client:SyncFinancesWithAuto", function(finances, balances, autoPay)
        Framework.TriggerCallback("plt_departments:server:GetData", function(serverData)
            SyncToNUI({
                action       = "syncData",
                finances     = finances,
                balances     = balances,
                autoPay      = autoPay,
                members      = serverData.members,
                data         = serverData.departments,
                transactions = serverData.transactions,
            })
        end)
    end)

    local function JoinVoiceRadio(frequency)
        if GetResourceState("mm_radio") == "started" then
            exports.mm_radio:JoinRadio(frequency)
        else
            exports["pma-voice"]:setRadioChannel(frequency)
            exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
        end
    end

    local function LeaveVoiceRadio()
        if GetResourceState("mm_radio") == "started" then
            exports.mm_radio:LeaveRadio()
        else
            exports["pma-voice"]:setRadioChannel(0)
            exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
        end
    end

    local function EnsureAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            RequestAnimDict(dict)
            Wait(5)
        end
    end

    CreateThread(function()
        while true do
            local waitTime = 500
            if currentRadioFrequency > 0 then
                waitTime = 100
                local isTalking = LocalPlayer.state.radioTalking
                local ped       = PlayerPedId()
                local inVehicle = IsPedInAnyVehicle(ped, false)

                if isTalking and not isRadioAnimPlaying then
                    isRadioAnimPlaying = true
                    if not inVehicle then
                        EnsureAnimDict("random@arrests")
                        TaskPlayAnim(ped, "random@arrests", "generic_radio_chatter", 8.0, 0.0, -1, 49, 0, 0, 0, 0)
                    end
                elseif not isTalking and isRadioAnimPlaying then
                    isRadioAnimPlaying = false
                    if not inVehicle then
                        StopAnimTask(ped, "random@arrests", "generic_radio_chatter", 1.0)
                    end
                end
            end
            Wait(waitTime)
        end
    end)

    RegisterNUICallback("joinFrequency", function(data, cb)
        local frequency = tonumber(data.frequency)
        if frequency then
            currentRadioFrequency = frequency
            JoinVoiceRadio(frequency)
            TriggerServerEvent(Events.joinRadio, frequency)
            Framework.Notify(T("joined_freq", { freq = frequency }), "success")
        end
        cb("ok")
    end)

    RegisterNUICallback("movePlayerFrequency", function(data, cb)
        TriggerServerEvent(Events.moveRadio, data.cid, tonumber(data.toFrequency))
        cb("ok")
    end)

    RegisterNUICallback("leaveFrequency", function(data, cb)
        currentRadioFrequency = 0
        LeaveVoiceRadio()
        TriggerServerEvent(Events.leaveRadio)
        Framework.Notify(T("disconnected_freq"), "primary")
        cb("ok")
    end)

    RegisterNetEvent("plt_departments:client:ForceRadioChannel")
    AddEventHandler("plt_departments:client:ForceRadioChannel", function(frequency)
        currentRadioFrequency = frequency
        JoinVoiceRadio(frequency)
        Framework.Notify(T("moved_to_freq", { freq = frequency }), "primary")
    end)

    local function ForwardToServer(eventName)
        return function(data, cb)
            TriggerServerEvent(eventName, data)
            cb("ok")
        end
    end

    RegisterNUICallback("addBolo",           ForwardToServer("plt_departments:server:addBolo"))
    RegisterNUICallback("updateBolo",        ForwardToServer("plt_departments:server:updateBolo"))
    RegisterNUICallback("deleteBolo",        ForwardToServer("plt_departments:server:deleteBolo"))
    RegisterNUICallback("addNews",           ForwardToServer("plt_departments:server:addNews"))
    RegisterNUICallback("deleteNews",        ForwardToServer("plt_departments:server:deleteNews"))
    RegisterNUICallback("addCaseFile",       ForwardToServer("plt_departments:server:addCaseFile"))
    RegisterNUICallback("updateCaseFile",    ForwardToServer("plt_departments:server:updateCaseFile"))
    RegisterNUICallback("deleteCaseFile",    ForwardToServer("plt_departments:server:deleteCaseFile"))
    RegisterNUICallback("addWarrant",        ForwardToServer("plt_departments:server:addWarrant"))
    RegisterNUICallback("updateWarrant",     ForwardToServer("plt_departments:server:updateWarrant"))
    RegisterNUICallback("completeWarrant",   ForwardToServer("plt_departments:server:completeWarrant"))
    RegisterNUICallback("deleteWarrant",     ForwardToServer("plt_departments:server:deleteWarrant"))
    RegisterNUICallback("hirePlayer",        ForwardToServer(Events.hirePlayer))
    RegisterNUICallback("updateRankSalary",  ForwardToServer(Events.updateRankSalary))
    RegisterNUICallback("manageDivision",    ForwardToServer(Events.manageDivision))
    RegisterNUICallback("toggleMemberDivision", ForwardToServer(Events.toggleMemberDivision))
    RegisterNUICallback("financeAction",     ForwardToServer(Events.financeAction))
    RegisterNUICallback("distributeSalaries", ForwardToServer(Events.distributeSalaries))
    RegisterNUICallback("toggleAutoPay",     ForwardToServer(Events.toggleAutoPay))
    RegisterNUICallback("submitOfficerReport", ForwardToServer(Events.submitOfficerReport))

    RegisterNUICallback("sendDepartmentMail", function(data, cb)
        TriggerServerEvent("plt_departments:server:sendDepartmentMail", data)
        cb({ ok = true })
    end)

    RegisterNUICallback("getPlayers", function(data, cb)
        Framework.TriggerCallback("plt_departments:server:getPlayers", function(result)
            cb(result)
        end)
    end)

    RegisterNUICallback("getFrameworkRanks", function(data, cb)
        local jobName = (type(data) == "table" and data.jobName) or "police"

        Framework.TriggerCallback("plt_departments:server:getFrameworkJobRanks", function(result)
            if not result then
                result = {
                    framework = tostring(Framework.Type or "auto"),
                    job       = tostring(jobName),
                    ranks     = {},
                }
            end
            cb(result)
        end, jobName)
    end)

    RegisterNUICallback("manageMember", function(data, cb)
        Framework.TriggerCallback("plt_departments:server:manageMember", function(success)
            cb(success and "ok" or "error")
        end, data)
    end)

    RegisterNUICallback("closeBossMenu", function(data, cb)
        SetNuiFocus(false, false)
        if RemoveMacintosh then RemoveMacintosh() end  
        isBossMenuOpen = false
        cb("ok")
    end)

    RegisterNetEvent("plt_departments:client:OpenManager")
    AddEventHandler("plt_departments:client:OpenManager", function()
        Framework.TriggerCallback("plt_departments:server:GetData", function(serverData)
            if not serverData then
                Framework.Notify(T("failed_fetch_data"), "error")
                return
            end
            if serverData.isAuthorized then
                SetNuiFocus(true, true)
                if PLTPushLocaleToNUI then PLTPushLocaleToNUI() end
                SendNUIMessage({ action = "open", data = serverData.departments })
            else
                Framework.Notify(T("no_permission_manage"), "error")
            end
        end)
    end)

    local function ShimCallback(globalName, fallback)
        return function(data, cb)
            local fn = _G[globalName]
            if fn then return fn(data, cb) end
            cb(fallback or "ok")
        end
    end

    RegisterNUICallback("selectOutfit",        ShimCallback("__cN0"))
    RegisterNUICallback("closeOutfitSelection", ShimCallback("__cN1"))
    RegisterNUICallback("swipeSuccess",        ShimCallback("__cN2"))
    RegisterNUICallback("spawnVehicle",        ShimCallback("__cN3"))
    RegisterNUICallback("close",               ShimCallback("__cN4"))
    RegisterNUICallback("closeArmory",         ShimCallback("__cN5"))
    RegisterNUICallback("takeArmoryItem",      ShimCallback("__cN6"))
    RegisterNUICallback("save",                ShimCallback("__cN7"))
    RegisterNUICallback("startPlacement",      ShimCallback("__cN8"))
    RegisterNUICallback("startDoorPlacement",  ShimCallback("__cN9"))

    exports("GetPlayerJob", function()
        local fn = _G["__cE0"]
        return (fn and fn()) or { dept = "none", grade = 0, onDuty = false }
    end)

    exports("IsOnDuty", function()
        local fn = _G["__cE1"]
        return (fn and fn()) or false
    end)

    exports("GetDepartment", function()
        local fn = _G["__cE2"]
        return (fn and fn()) or "none"
    end)

    exports("GetGrade", function()
        local fn = _G["__cE3"]
        return (fn and fn()) or 0
    end)

    CreateThread(function()
        local attempts = 0
        while attempts < 200 do
            if _G["__cD0"] and _G["__cD1"] and _G["__cD2"] then break end
            attempts = attempts + 1
            Wait(50)
        end

        RegisterCommand("deptdebug", function()
            local fn = _G["__cD0"]
            if fn then fn() end
        end, true)

        RegisterCommand("duty", function()
            local fn = _G["__cD1"]
            if fn then fn() end
        end, false)

        if Framework.Type ~= "qb" then
            RegisterCommand(Config.CommandName, function()
                TriggerEvent("plt_departments:client:OpenManager")
            end, false)
        end

        RegisterCommand("listdoors", function()
            local fn = _G["__cD2"]
            if fn then fn() end
        end, false)
    end)

end

PLTLibClient.RegisterCoreCallbacks = PLTLibClient.RegisterCoreCallbacks
