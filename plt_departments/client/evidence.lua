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


local evidenceTable = {}  

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

function PlayerHasEvidenceNode()
    if not (DepartmentData and DepartmentData.nodes) then return false end
    for _, node in ipairs(DepartmentData.nodes) do
        if node.type == "evidence" then
            local nodeDept = tostring(GetDepartmentForNode(node.id, DepartmentData))
            local playerDept = tostring(LocalPlayerJob and LocalPlayerJob.dept)
            if nodeDept == playerDept then
                return true
            end
        end
    end
    return false
end

function CanSeeEvidence(ped)
    if not (Config and Config.Evidence and Config.Evidence.RequireTorch) then
        return true
    end

    local heldWeapon  = GetSelectedPedWeapon(ped)
    local torchItem   = Config.Evidence.TorchItem or "weapon_flashlight"
    local torchStr    = tostring(torchItem):upper()
    if not torchStr:find("WEAPON_", 1, true) then
        torchStr = "WEAPON_" .. torchStr
    end
    local torchHash      = GetHashKey(torchStr)
    local torchHashRaw   = GetHashKey(tostring(torchItem))
    local holdingTorch   = (heldWeapon == torchHash) or (heldWeapon == torchHashRaw)

    if not holdingTorch then return false end

    local flashlightOn = IsFlashLightOn(ped)
    local isAiming     = IsPlayerFreeAiming(PlayerId())
    local firePressed  = IsControlPressed(0, 24) or IsControlPressed(0, 25)
    return flashlightOn or isAiming or firePressed
end

function DrawText3D(x, y, z, text)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(screenX, screenY)

    local bgWidth = 0.015 + (#text / 370)
    DrawRect(screenX, screenY + 0.0125, bgWidth, 0.03, 41, 11, 41, 68)
end

function HasAnyEvidenceNode()
    if not (DepartmentData and DepartmentData.nodes) then return false end
    for _, node in ipairs(DepartmentData.nodes) do
        if node.type == "evidence" then return true end
    end
    return false
end

CreateThread(function()
    while true do
        local waitTime = 1000
        local ped      = PlayerPedId()

        if HasAnyEvidenceNode() then
            waitTime = 0
            if IsPedShooting(ped) then
                local weapon = GetSelectedPedWeapon(ped)
                if not IsWeaponIgnored(weapon) then
                    local coords = GetEntityCoords(ped)
                    TriggerServerEvent("plt_departments:server:dropCasing", weapon, {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z - 0.95,
                    })
                end
            end
        end

        Wait(waitTime)
    end
end)

RegisterNetEvent("plt_departments:client:syncEvidence")
AddEventHandler("plt_departments:client:syncEvidence", function(allEvidence)
    evidenceTable = allEvidence
end)

RegisterNetEvent("plt_departments:client:addEvidence")
AddEventHandler("plt_departments:client:addEvidence", function(id, entry)
    evidenceTable[id] = entry
end)

RegisterNetEvent("plt_departments:client:removeEvidence")
AddEventHandler("plt_departments:client:removeEvidence", function(id)
    evidenceTable[id] = nil
end)

CreateThread(function()
    while true do
        local waitTime  = 1000
        local ped       = PlayerPedId()
        local playerPos = GetEntityCoords(ped)

        if PlayerHasEvidenceNode() and CanSeeEvidence(ped) then
            local closestId   = nil
            local closestDist = 2.0

            for id, evidence in pairs(evidenceTable) do
                local ePos = vector3(evidence.coords.x, evidence.coords.y, evidence.coords.z)
                local dist = #(playerPos - ePos)

                if dist < 5.0 then
                    waitTime = 0
                    DrawMarker(2,
                        evidence.coords.x, evidence.coords.y, evidence.coords.z + 0.1,
                        0, 0, 0,
                        0, 180.0, 0,
                        0.1, 0.1, 0.1,
                        255, 255, 255, 150,
                        false, true, 2, false, nil, nil, false
                    )

                    if dist < closestDist then
                        closestDist = dist
                        closestId   = id
                    end
                end
            end

            if closestId then
                local e = evidenceTable[closestId]
                DrawText3D(e.coords.x, e.coords.y, e.coords.z + 0.3, "[~b~E~w~] Collect Evidence")
                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent("plt_departments:server:pickUpEvidence", closestId)
                end
            end
        end

        Wait(waitTime)
    end
end)

RegisterNetEvent("plt_departments:client:openForensicPC")
AddEventHandler("plt_departments:client:openForensicPC", function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "openForensicPC" })
end)

-- Using the evidence_bag item opens the Forensic PC
RegisterNetEvent("plt_departments:client:useEvidenceBag")
AddEventHandler("plt_departments:client:useEvidenceBag", function()
    TriggerEvent("plt_departments:client:openForensicPC")
end)

RegisterNUICallback("closeForensicPC", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("getAvailableEvidence", function(data, cb)
    local ok = pcall(function()
        Framework.TriggerCallback("plt_departments:server:getPlayerEvidence", function(result)
            if type(result) ~= "table" then
                cb({})
            else
                cb(result)
            end
        end)
    end)
    if not ok then cb({}) end
end)

RegisterNUICallback("printEvidenceReport", function(data, cb)
    TriggerServerEvent("plt_departments:server:printEvidenceReport", data)
    cb("ok")
end)

RegisterNetEvent("plt_departments:client:viewForensicReport")
AddEventHandler("plt_departments:client:viewForensicReport", function(report)
    if not report then return end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "viewForensicReport", report = report })
end)

RegisterNUICallback("closeForensicReport", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

CreateThread(function()
    
    while true do
        local playerData = Framework.GetPlayerData and Framework.GetPlayerData()
        if playerData and playerData.citizenid then break end
        Wait(100)
    end

    Framework.TriggerCallback("plt_departments:server:getEvidence", function(result)
        evidenceTable = result
    end)
end)

