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


local isDispatchVisible = false

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

function PlayerHasDept()
    return LocalPlayerJob and LocalPlayerJob.dept and LocalPlayerJob.dept ~= "none"
end

function GetCurrentGameTime()
    return string.format("%02d:%02d", GetClockHours(), GetClockMinutes())
end

function GetPlayerStreetLocation()
    local coords = GetEntityCoords(PlayerPedId())
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local location = GetStreetNameFromHashKey(streetHash)
    if crossingHash ~= 0 then
        location = location .. " | " .. GetStreetNameFromHashKey(crossingHash)
    end
    return location, coords
end

function CreateDispatchCall(data)
    TriggerServerEvent("plt_departments:server:createDispatchCall", data)
end

function ToggleDispatch(forceState)
    if forceState ~= nil then
        isDispatchVisible = forceState
    else
        isDispatchVisible = not isDispatchVisible
    end
    SendNUIMessage({ action = "toggleDispatch", show = isDispatchVisible })
end

RegisterNUICallback("toggleDispatch", function(data, cb)
    if not PlayerHasDept() then cb("ok") return end
    ToggleDispatch()
    cb("ok")
end)

RegisterNUICallback("lockDispatch", function(data, cb)
    if not exports.plt_departments:isOfficerMenuOpen() then
        SetNuiFocus(false, false)
    end
    Framework.Notify("Dispatch position locked.", "success")
    cb("ok")
end)

RegisterNUICallback("closeDispatch", function(data, cb)
    if not exports.plt_departments:isOfficerMenuOpen() then
        SetNuiFocus(false, false)
    end
    cb("ok")
end)

RegisterNUICallback("setDispatchGPS", function(data, cb)
    if not (data.x and data.y) then return end
    SetNewWaypoint(data.x, data.y)
    Framework.Notify("GPS set to call location.", "success")
    cb("ok")
end)

RegisterCommand("dispatch", function()
    if not PlayerHasDept() then return end
    ToggleDispatch()
end, false)

RegisterCommand("dispatchmove", function()
    if not PlayerHasDept() then return end
    ToggleDispatch(true)
    SetNuiFocus(true, true)
    Framework.Notify("Mouse activated. Drag dispatch and click the lock icon to finish.", "primary")
end, false)

RegisterCommand("dispatch_prev", function()
    if not (isDispatchVisible and PlayerHasDept()) then return end
    SendNUIMessage({ action = "scrollDispatch", direction = "prev" })
end, false)

RegisterCommand("dispatch_next", function()
    if not (isDispatchVisible and PlayerHasDept()) then return end
    SendNUIMessage({ action = "scrollDispatch", direction = "next" })
end, false)

RegisterCommand("dispatch_gps", function()
    if not (isDispatchVisible and PlayerHasDept()) then return end
    SendNUIMessage({ action = "setGPSActive" })
end, false)

RegisterKeyMapping("dispatch_prev", "Scroll Dispatch Left",  "keyboard", "LEFT")
RegisterKeyMapping("dispatch_next", "Scroll Dispatch Right", "keyboard", "RIGHT")
RegisterKeyMapping("dispatch_gps",  "Set GPS to Active Call","keyboard", "E")

RegisterNetEvent("plt_departments:client:addDispatchCall")
AddEventHandler("plt_departments:client:addDispatchCall", function(call)
    if not PlayerHasDept() then return end
    SendNUIMessage({ action = "addDispatchCall", call = call })
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedShooting(ped) then
            local weapon = GetSelectedPedWeapon(ped)
            if not IsWeaponIgnored(weapon) then
                local location, coords = GetPlayerStreetLocation()
                CreateDispatchCall({
                    code     = "10-71",
                    title    = "Shots Fired",
                    location = location,
                    coords   = coords,
                    time     = GetCurrentGameTime(),
                    info     = "Automatic weapon fire reported by citizens.",
                })
                Wait(30000)
            end
        end
        Wait(1)
    end
end)

RegisterCommand("911", function(source, args)
    if #args == 0 then
        Framework.Notify(T("911_no_description"), "error")
        return
    end
    local message  = table.concat(args, " ")
    local location, coords = GetPlayerStreetLocation()
    CreateDispatchCall({
        code     = "911",
        title    = T("911_call_title"),
        location = location,
        coords   = coords,
        time     = GetCurrentGameTime(),
        info     = message,
    })
    Framework.Notify(T("911_sent"), "success")
end, false)

RegisterCommand("testcall", function()
    CreateDispatchCall({
        code     = "10-71",
        title    = "Shots Fired",
        location = "Mission Row",
        coords   = GetEntityCoords(PlayerPedId()),
        time     = GetCurrentGameTime(),
        info     = "Automatic weapon fire reported by citizens.",
    })
end, false)

