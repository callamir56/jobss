-- ============================================================
--  K9 ox_target (ALT on the dog) + Track player by ID
--  Options: enter/exit vehicle, attack, sit, track nearest
--  Command: /k9track <player id>  (walks to the player, max 100m)
-- ============================================================

PLTK9Target = {}

local k9TargetAttached   = false
local trackingVersion    = 0
local TRACK_MAX_DISTANCE = 100.0

-- ------------------------------------------------------------
-- Track a player: the dog walks to the target and stops there
-- ------------------------------------------------------------
function PLTK9CancelTracking()
    trackingVersion = trackingVersion + 1
end

function PLTK9TrackPlayer(targetServerId)
    if not K9Exists() then
        Framework.Notify(T("no_dog"), "error")
        return
    end

    targetServerId = tonumber(targetServerId)
    if not targetServerId then
        Framework.Notify(T("k9_track_usage"), "error")
        return
    end

    local targetPed = GetPlayerFromServerId(targetServerId)
    if not targetPed or targetPed == -1 or not DoesEntityExist(targetPed) then
        Framework.Notify(T("k9_target_not_found", { id = targetServerId }), "error")
        return
    end

    if IsPedInAnyVehicle(currentK9, false) then
        EjectK9FromVehicle()
        Wait(600)
    end

    local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(targetPed))
    if dist > TRACK_MAX_DISTANCE then
        Framework.Notify(T("k9_target_too_far"), "error")
        return
    end

    StopFollowing(true)
    PLTK9CancelTracking()
    trackingVersion = trackingVersion + 1
    local myVersion = trackingVersion

    Framework.Notify(T("k9_tracking_player", { id = targetServerId }), "success")

    SetBlockingOfNonTemporaryEvents(currentK9, true)
    SetPedKeepTask(currentK9, true)

    CreateThread(function()
        local lastIssue = 0
        while true do
            if myVersion ~= trackingVersion then break end
            if not K9Exists() then break end

            if not DoesEntityExist(targetPed) then
                Framework.Notify(T("k9_target_lost"), "error")
                break
            end

            local k9Pos     = GetEntityCoords(currentK9)
            local targetPos = GetEntityCoords(targetPed)
            local dist      = #(k9Pos - targetPos)

            if dist < 1.8 then
                -- arrived: stop and sit next to the target
                ClearPedTasks(currentK9)
                PlayK9Anim("creatures@rottweiler@amb@world_dog_sitting@idle_a", "idle_b")
                Framework.Notify(T("k9_arrived"), "success")
                break
            end

            local now = GetGameTimer()
            if now - lastIssue > 2500 then
                ClearPedSecondaryTask(currentK9)
                -- walk (speed 1.0) toward the target, keep the task fresh
                TaskGoToEntity(currentK9, targetPed, 5000, 1.5, 1.0, 0.0, 0)
                lastIssue = now
            end

            Wait(700)
        end
    end)
end

function PLTK9TrackNearest()
    if not K9Exists() then
        Framework.Notify(T("no_dog"), "error")
        return
    end

    local targetPlayer, targetDist = Framework.GetClosestPlayer()
    if targetPlayer == -1 or targetDist > TRACK_MAX_DISTANCE then
        Framework.Notify(T("k9_no_target"), "error")
        return
    end

    local serverId = GetPlayerServerId(targetPlayer)
    PLTK9TrackPlayer(serverId)
end

-- ------------------------------------------------------------
-- Vehicle: prefer the vehicle the player is sitting in
-- ------------------------------------------------------------
function PLTK9ToggleVehicle()
    if not K9Exists() then return end

    if IsPedInAnyVehicle(currentK9, false) then
        EjectK9FromVehicle()
        Framework.Notify(T("k9_exited_vehicle"), "primary")
        return
    end

    StopFollowing(false)
    PLTK9CancelTracking()

    local ped     = PlayerPedId()
    local vehicle = 0
    if IsPedInAnyVehicle(ped, false) then
        vehicle = GetVehiclePedIsIn(ped, false)
    else
        vehicle = Framework.GetClosestVehicle()
    end

    if not vehicle or vehicle == 0 then
        Framework.Notify(T("k9_no_vehicle"), "error")
        return
    end

    local seat = FindFreeSeat(vehicle)
    if not seat then
        Framework.Notify(T("k9_no_free_seats"), "error")
        return
    end

    local entryPos = GetK9VehicleEntryCoords(vehicle)
    if entryPos then
        TaskGoToCoordAnyMeans(currentK9, entryPos.x, entryPos.y, entryPos.z, 2.0, 0, 0, 786603, 3212836864)
    end
    Wait(250)
    TaskEnterVehicle(currentK9, vehicle, -1, seat, 1.0, 1, 0)
    Framework.Notify(T("k9_entering_vehicle"), "primary")
end

-- ------------------------------------------------------------
-- Simple commands reused by the target menu
-- ------------------------------------------------------------
function PLTK9Attack()
    if not K9Exists() then return end
    StopFollowing(true)
    PLTK9CancelTracking()

    local targetPlayer, targetDist = Framework.GetClosestPlayer()
    if targetPlayer ~= -1 and targetDist < 10.0 then
        TaskCombatPed(currentK9, GetPlayerPed(targetPlayer), 0, 16)
        Framework.Notify(T("k9_attack_started"), "error")
    else
        Framework.Notify(T("k9_no_target"), "error")
    end
end

function PLTK9Sit()
    if not K9Exists() then return end
    StopFollowing(true)
    PLTK9CancelTracking()
    ClearPedTasks(currentK9)
    PlayK9Anim("creatures@rottweiler@amb@world_dog_sitting@idle_a", "idle_b")
    Framework.Notify(T("k9_sat"), "primary")
end

-- ------------------------------------------------------------
-- Attach / detach ox_target (ALT) options on the dog
-- ------------------------------------------------------------
function PLTK9Target.Attach(k9Entity)
    if k9TargetAttached then return end
    if not k9Entity or not DoesEntityExist(k9Entity) then return end

    local canInteract = function()
        return K9Exists() and PlayerHasDept()
    end

    local options = {
        {
            name          = "plt_k9_vehicle",
            icon          = "fas fa-car",
            label         = T("k9_toggle_vehicle"),
            distance      = 4.0,
            canInteract   = canInteract,
            onSelect      = function() PLTK9ToggleVehicle() end,
        },
        {
            name          = "plt_k9_attack",
            icon          = "fas fa-hand-fist",
            label         = T("k9_attack"),
            distance      = 4.0,
            canInteract   = canInteract,
            onSelect      = function() PLTK9Attack() end,
        },
        {
            name          = "plt_k9_sit",
            icon          = "fas fa-chair",
            label         = T("k9_sit"),
            distance      = 4.0,
            canInteract   = canInteract,
            onSelect      = function() PLTK9Sit() end,
        },
        {
            name          = "plt_k9_track_nearest",
            icon          = "fas fa-location-crosshairs",
            label         = T("k9_track_nearest"),
            distance      = 4.0,
            canInteract   = canInteract,
            onSelect      = function() PLTK9TrackNearest() end,
        },
        {
            name          = "plt_k9_menu",
            icon          = "fas fa-bars",
            label         = T("k9_open_menu"),
            distance      = 4.0,
            canInteract   = canInteract,
            onSelect      = function() ToggleK9Menu() end,
        },
    }

    local targetSystem = GetTargetSystem()
    local ok = false

    if targetSystem == "ox_target" then
        ok = pcall(function()
            exports.ox_target:addLocalEntity(k9Entity, options)
        end)
    else
        ok = pcall(function()
            local qbOptions = {}
            for _, opt in ipairs(options) do
                table.insert(qbOptions, {
                    icon        = opt.icon,
                    label       = opt.label,
                    canInteract = opt.canInteract,
                    action      = opt.onSelect,
                })
            end
            exports["qb-target"]:AddTargetEntity(k9Entity, {
                options  = qbOptions,
                distance = 4.0,
            })
        end)
    end

    k9TargetAttached = ok and true or false
end

function PLTK9Target.Detach(k9Entity)
    if not k9TargetAttached then return end

    local targetSystem = GetTargetSystem()
    if k9Entity and DoesEntityExist(k9Entity) then
        if targetSystem == "ox_target" then
            pcall(function() exports.ox_target:removeLocalEntity(k9Entity) end)
        else
            pcall(function() exports["qb-target"]:RemoveTargetEntity(k9Entity) end)
        end
    else
        -- entity already gone: best-effort cleanup by model
        pcall(function()
            if targetSystem == "ox_target" then
                exports.ox_target:removeModel(GetHashKey("a_c_shepherd"))
            else
                exports["qb-target"]:RemoveTargetModel(GetHashKey("a_c_shepherd"))
            end
        end)
    end

    k9TargetAttached = false
end

-- ------------------------------------------------------------
-- Command: /k9track <player id>
-- ------------------------------------------------------------
RegisterCommand("k9track", function(_, args)
    local id = tonumber(args and args[1])
    if not id then
        Framework.Notify(T("k9_track_usage"), "error")
        return
    end
    PLTK9TrackPlayer(id)
end, false)

-- Keep tracking state in sync when the dog is dismissed
RegisterNetEvent("plt_departments:client:RemoveK9")
AddEventHandler("plt_departments:client:RemoveK9", function()
    PLTK9CancelTracking()
end)
