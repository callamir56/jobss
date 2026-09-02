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


local isCameraActive = false
local scriptCam      = nil
local activeCamData  = nil  

function ExitSurveillanceFeed()
    if not isCameraActive then return end
    isCameraActive = false

    RenderScriptCams(false, false, 0, true, true)

    if scriptCam then
        DestroyCam(scriptCam, false)
        scriptCam = nil
    end

    ClearFocus()
    SetFocusEntity(PlayerPedId())
    DisplayHud(true)
    DisplayRadar(true)
    SendNUIMessage({ action = "hideCameraOverlay" })

    TriggerEvent("qb-inventory:client:SetCurrentStash", nil)

    Framework.Notify("Exited surveillance feed.", "primary")
end

RegisterNetEvent("plt_departments:client:ViewCamera")
AddEventHandler("plt_departments:client:ViewCamera", function(camData)
    if isCameraActive then ExitSurveillanceFeed() end

    activeCamData  = camData
    isCameraActive = true

    local coords  = camData.coords
    local heading = camData.heading or 0.0
    local label   = camData.label   or "Unknown Camera"

    DisplayHud(false)
    DisplayRadar(false)
    SendNUIMessage({ action = "showCameraOverlay", label = label })

    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)

    scriptCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(scriptCam, coords.x, coords.y, coords.z + 1.5)
    SetCamRot(scriptCam, -20.0, 0.0, heading, 2)
    SetCamFov(scriptCam, 60.0)
    RenderScriptCams(true, false, 0, true, true)

    CreateThread(function()
        while isCameraActive do
            DisableAllControlActions(0)
            EnableControlAction(0, 1,   true)   
            EnableControlAction(0, 2,   true)   
            EnableControlAction(0, 15,  true)   
            EnableControlAction(0, 16,  true)   
            EnableControlAction(0, 177, true)   
            EnableControlAction(0, 202, true)   

            local rot   = GetCamRot(scriptCam, 2)
            local yawDelta   = GetDisabledControlNormal(0, 1) * -5.0
            local pitchDelta = GetDisabledControlNormal(0, 2) * -5.0

            if yawDelta ~= 0.0 or pitchDelta ~= 0.0 then
                local newPitch = math.max(-70.0, math.min(20.0, rot.x + pitchDelta))
                local newYaw   = rot.z + yawDelta
                SetCamRot(scriptCam, newPitch, 0.0, newYaw, 2)
            end

            local fov = GetCamFov(scriptCam)
            if IsControlPressed(0, 15) or IsDisabledControlPressed(0, 15) then
                SetCamFov(scriptCam, math.max(10.0, fov - 1.0))
            elseif IsControlPressed(0, 16) or IsDisabledControlPressed(0, 16) then
                SetCamFov(scriptCam, math.min(100.0, fov + 1.0))
            end

            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 202) then
                ExitSurveillanceFeed()
            end

            Wait(0)
        end
    end)

    CreateThread(function()
        while isCameraActive do
            SetTimecycleModifier("scanline_cam_cheap")
            SetTimecycleModifierStrength(1.5)
            SendNUIMessage({ action = "updateCameraTime" })
            Wait(1000)
        end
        ClearTimecycleModifier()
    end)
end)

RegisterNUICallback("viewCamera", function(data, cb)
    local nodeId   = data and data.nodeId
    local camIndex = tonumber(data and data.camIndex)

    if not nodeId or camIndex == nil then
        cb("ok")
        return
    end

    local node = nil
    if PLTClientNodes and PLTClientNodes.GetNodeById then
        node = PLTClientNodes.GetNodeById(nodeId, DepartmentData)
    elseif DepartmentData and DepartmentData.nodes then
        for _, n in ipairs(DepartmentData.nodes) do
            if tostring(n.id) == tostring(nodeId) then
                node = n
                break
            end
        end
    end

    local cameraSlot = math.floor(camIndex) + 1   

    if not node or node.type ~= "camera" or not (node.cameras and node.cameras[cameraSlot]) then
        cb("ok")
        return
    end

    local nodeDept   = tostring(GetDepartmentForNode(node.id, DepartmentData))
    local playerDept = tostring(LocalPlayerJob and LocalPlayerJob.dept)
    if nodeDept ~= playerDept then
        cb("ok")
        return
    end

    local camEntry = node.cameras[cameraSlot]
    if not camEntry.coords then
        cb("ok")
        return
    end

    local heading = (camEntry.coords and camEntry.coords.h) or 0.0

    local label = camEntry.label or ("Camera " .. tostring(cameraSlot))

    TriggerEvent("plt_departments:client:ViewCamera", {
        coords  = camEntry.coords,
        label   = label,
        heading = heading,
    })

    cb("ok")
end)

