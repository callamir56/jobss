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


local isK9MenuOpen  = false   
local isFollowing   = false   
local followVersion = 0       

function K9Exists()
    return currentK9 and DoesEntityExist(currentK9)
end

function PlayerHasDept()
    return LocalPlayerJob and LocalPlayerJob.dept and LocalPlayerJob.dept ~= "none"
end

function PlayK9Anim(dict, clip, blendIn, blendOut, duration, flag)
    blendIn   = blendIn  or 8.0
    blendOut  = blendOut or -8.0
    duration  = duration or -1
    flag      = flag     or 1

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    TaskPlayAnim(currentK9, dict, clip, blendIn, blendOut, duration, flag, 0, false, false, false)
end

function StartK9FollowTask(targetPed, clearFirst)
    if not K9Exists() then return end
    if not targetPed or targetPed == 0 then return end
    if IsPedInAnyVehicle(currentK9, false) then return end

    if clearFirst then ClearPedTasks(currentK9) end

    SetBlockingOfNonTemporaryEvents(currentK9, true)
    SetPedKeepTask(currentK9, true)
    TaskFollowToOffsetOfEntity(currentK9, targetPed, -0.45, -0.9, 0.0, 3.0, -1, 2.0, true)
end

function StopFollowing(clearTasks)
    isFollowing   = false
    followVersion = followVersion + 1
    if clearTasks and K9Exists() then
        ClearPedTasks(currentK9)
    end
end

function StartFollowing()
    if not K9Exists() then return end

    isFollowing   = true
    followVersion = followVersion + 1
    local myVersion = followVersion

    StartK9FollowTask(PlayerPedId(), true)

    CreateThread(function()
        
        local lastTaskTime   = 0      
        local stuckTimerStart = 0     
        local lastK9Pos      = nil    

        while true do
            
            if not isFollowing then break end
            if myVersion ~= followVersion then break end
            if not K9Exists() then
                isFollowing = false
                break
            end

            local ped = PlayerPedId()
            if not ped or ped == 0 then
                Wait(300)
            else
                local now      = GetGameTimer()
                local playerPos = GetEntityCoords(ped)
                local k9Pos    = GetEntityCoords(currentK9)
                local dist     = #(playerPos - k9Pos)

                if dist > 35.0 then
                    
                    if not IsPedInAnyVehicle(ped, false) and not IsPedInAnyVehicle(currentK9, false) then
                        
                        local behindOffset = GetOffsetFromEntityInWorldCoords(ped, -0.3, -1.2, 0.0)
                        local groundFound, groundZ = GetGroundZFor_3dCoord(
                            behindOffset.x, behindOffset.y, behindOffset.z + 3.0, false
                        )
                        local spawnPos = groundFound
                            and vector3(behindOffset.x, behindOffset.y, groundZ + 0.05)
                            or  behindOffset

                        SetEntityCoordsNoOffset(currentK9, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
                        SetEntityHeading(currentK9, GetEntityHeading(ped))
                        StartK9FollowTask(ped, true)

                        lastTaskTime      = now
                        stuckTimerStart   = 0
                        lastK9Pos         = GetEntityCoords(currentK9)
                    end

                elseif dist > 16.0 then
                    
                    local timeSinceLastTask = now - lastTaskTime
                    if timeSinceLastTask > 3000 then
                        StartK9FollowTask(ped, true)
                        lastTaskTime = now
                    end
                    lastK9Pos = k9Pos

                else
                    
                    if dist > 10.0 and lastK9Pos then
                        local k9Movement = #(k9Pos - lastK9Pos)
                        if k9Movement < 0.03 then
                            
                            if stuckTimerStart == 0 then stuckTimerStart = now end
                            local stuckDuration = now - stuckTimerStart
                            if stuckDuration > 6000 then
                                
                                StartK9FollowTask(ped, true)
                                lastTaskTime    = now
                                stuckTimerStart = 0
                            end
                        else
                            stuckTimerStart = 0   
                        end
                    else
                        stuckTimerStart = 0
                    end
                    lastK9Pos = k9Pos
                end

                Wait(450)
            end
        end
    end)
end

function FindFreeSeat(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    for _, seat in ipairs({ 1, 2, 0, -1 }) do
        if IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end
    return nil
end

function GetK9VehicleEntryCoords(vehicle)
    if not vehicle or vehicle == 0 then return nil end

    local vehPos = GetEntityCoords(vehicle)
    local offsets = {
        vector3(-1.1, -2.9, 0.0),
        vector3( 1.1, -2.9, 0.0),
        vector3(-1.3, -1.8, 0.0),
        vector3( 1.3, -1.8, 0.0),
        vector3( 0.0, -3.4, 0.0),
        
        vector3(-1.5,  0.0, 0.0),
        vector3( 1.5,  0.0, 0.0),
        vector3(-1.3,  1.8, 0.0),
        vector3( 1.3,  1.8, 0.0),
        vector3( 0.0,  2.8, 0.0),
        vector3(-1.1,  2.9, 0.0),
        vector3( 1.1,  2.9, 0.0),
        vector3( 0.0, -1.5, 0.0),
    }

    for _, offset in ipairs(offsets) do
        local worldPos = GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z)
        local found, safePos = GetSafeCoordForPed(worldPos.x, worldPos.y, vehPos.z, false, 16)
        if found and safePos then
            return vector3(safePos.x, safePos.y, safePos.z)
        end
    end

    return vector3(vehPos.x, vehPos.y, vehPos.z)
end

function EjectK9FromVehicle()
    if not K9Exists() then return end
    if not IsPedInAnyVehicle(currentK9, false) then return end

    local vehicle = GetVehiclePedIsIn(currentK9, false)
    if vehicle == 0 then return end

    local dropPos = GetK9VehicleEntryCoords(vehicle) or GetEntityCoords(vehicle)

    SetEntityInvincible(currentK9, true)
    SetPedCanRagdoll(currentK9, false)
    ClearPedTasksImmediately(currentK9)
    TaskLeaveVehicle(currentK9, vehicle, 16)

    CreateThread(function()
        local deadline = GetGameTimer() + 1800
        while IsPedInAnyVehicle(currentK9, false) and GetGameTimer() < deadline do
            Wait(50)
        end

        SetEntityCoordsNoOffset(currentK9, dropPos.x, dropPos.y, dropPos.z + 0.02, false, false, false)
        ClearPedTasks(currentK9)
        Wait(600)
        SetPedCanRagdoll(currentK9, true)
        SetEntityInvincible(currentK9, false)
    end)
end

function ToggleK9Menu(forceClose)
    if forceClose or isK9MenuOpen then
        isK9MenuOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "closeK9Menu" })
        return
    end

    if not PlayerHasDept() then return end

    if not K9Exists() then
        Framework.Notify("You don't have a police dog out!", "error")
        return
    end

    isK9MenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "openK9Menu" })
end

RegisterKeyMapping("k9menu", "Open K9 Control Menu", "keyboard", "F7")

RegisterCommand("k9menu", function()
    ToggleK9Menu()
end, false)

RegisterNUICallback("k9Action", function(data, cb)
    local action = data.action

    if not K9Exists() then
        Framework.Notify("No police dog found!", "error")
        cb("ok")
        return
    end

    if "follow" == action then
        StartFollowing()
        Framework.Notify("Dog is following.", "primary")

    elseif "stay" == action then
        StopFollowing(true)
        TaskStandStill(currentK9, -1)
        Framework.Notify("Dog is staying.", "primary")

    elseif "sit" == action then
        StopFollowing(true)
        ClearPedTasks(currentK9)
        PlayK9Anim("creatures@rottweiler@amb@world_dog_sitting@idle_a", "idle_b")
        Framework.Notify("Dog sat down.", "primary")

    elseif "lay_down" == action then
        StopFollowing(true)
        ClearPedTasks(currentK9)
        PlayK9Anim("creatures@rottweiler@amb@sleep_in_kennel@", "sleep_in_kennel")
        Framework.Notify("Dog lay down.", "primary")

    elseif "bark" == action then
        StopFollowing(true)
        PlayK9Anim("creatures@rottweiler@amb@world_dog_barking@idle_a", "idle_a")
        Framework.Notify("Dog is barking.", "primary")

    elseif "attack" == action then
        StopFollowing(true)
        local targetPlayer, targetDist = Framework.GetClosestPlayer()
        if targetPlayer ~= -1 and targetDist < 10.0 then
            TaskCombatPed(currentK9, GetPlayerPed(targetPlayer), 0, 16)
            Framework.Notify("K9 is attacking!", "error")
        else
            Framework.Notify("No target nearby!", "error")
        end

    elseif "search_veh" == action then
        StopFollowing(true)
        local vehicle = Framework.GetClosestVehicle()
        if vehicle ~= 0 then
            local vehPos = GetEntityCoords(vehicle)
            TaskGoToCoordAnyMeans(currentK9, vehPos.x, vehPos.y, vehPos.z, 1.0, 0, 0, 786603, 3212836864)

            CreateThread(function()
                while true do
                    local k9Pos = GetEntityCoords(currentK9)
                    local dist  = #(k9Pos - vehPos)
                    if dist < 2.5 then
                        ClearPedTasks(currentK9)
                        PlayK9Anim("creatures@rottweiler@amb@world_dog_barking@idle_a", "idle_a")
                        Wait(3000)
                        Framework.Notify("K9 search complete.", "primary")
                        StartFollowing()
                        break
                    end
                    Wait(500)
                end
            end)
        else
            Framework.Notify("No vehicle nearby!", "error")
        end

    elseif "toggle_veh" == action then
        StopFollowing(false)
        if IsPedInAnyVehicle(currentK9, false) then
            EjectK9FromVehicle()
            Framework.Notify("Dog left the vehicle.", "primary")
        else
            local vehicle = Framework.GetClosestVehicle()
            if vehicle ~= 0 then
                local seat = FindFreeSeat(vehicle)
                if seat then
                    local entryPos = GetK9VehicleEntryCoords(vehicle)
                    if entryPos then
                        TaskGoToCoordAnyMeans(currentK9, entryPos.x, entryPos.y, entryPos.z, 2.0, 0, 0, 786603, 3212836864)
                    end
                    Wait(250)
                    TaskEnterVehicle(currentK9, vehicle, -1, seat, 1.0, 1, 0)
                    Framework.Notify("Dog entering vehicle.", "primary")
                else
                    Framework.Notify("No free seats in vehicle!", "error")
                end
            end
        end

    elseif "sniff_person" == action then
        StopFollowing(true)
        local targetPlayer, targetDist = Framework.GetClosestPlayer()
        if targetPlayer ~= -1 and targetDist < 3.0 then
            local targetPos = GetEntityCoords(GetPlayerPed(targetPlayer))
            TaskGoToCoordAnyMeans(currentK9, targetPos.x, targetPos.y, targetPos.z, 1.0, 0, 0, 786603, 3212836864)
            CreateThread(function()
                Wait(2000)
                StartFollowing()
                Framework.Notify("K9 sniffed the person.", "primary")
            end)
        else
            Framework.Notify("No person nearby!", "error")
        end

    elseif "dismiss" == action then
        TriggerEvent("plt_departments:client:RemoveK9")
        ToggleK9Menu(true)
    end

    cb("ok")
end)

RegisterNUICallback("closeK9Menu", function(data, cb)
    isK9MenuOpen = false
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNetEvent("plt_departments:client:closeK9Menu")
AddEventHandler("plt_departments:client:closeK9Menu", function()
    ToggleK9Menu(true)
end)

RegisterNetEvent("plt_departments:client:StartK9Follow")
AddEventHandler("plt_departments:client:StartK9Follow", function()
    StartFollowing()
end)

RegisterNetEvent("plt_departments:client:StopK9Follow")
AddEventHandler("plt_departments:client:StopK9Follow", function(clearTasks)
    StopFollowing(clearTasks == true)
end)
