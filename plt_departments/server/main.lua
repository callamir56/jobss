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


if not PLTLibServer or not PLTLibServer.RegisterCoreCallbacks then
    error("plt_departments server lib missing: lib/server/lib.lua")
end

dataLoaded = false

ArmoryStocks        = {}
DepartmentData      = { nodes = {}, links = {}, divisions = {} }
MemberData          = {}
FinanceHistory      = {}
DeptBalances        = {}
AutoPaySettings     = {}
FinanceTransactions = {}
DoorStates          = {}
DelayedPayments     = {}
RadioChannels       = {}
Warrants            = {}
CaseFiles           = {}
Bolos               = {}
Cameras             = {}
DeptNews            = {}
DutyLogs            = {}
DepartmentMail      = {}
SeizedVehicles      = {}

local vehiclesTable  = Framework.Type == "qb" and "player_vehicles" or "owned_vehicles"
local playersTable   = Framework.Type == "qb" and "players"         or "users"
local identifierCol  = Framework.Type == "qb" and "citizenid"       or "identifier"

local addonAccountState = {
    checked   = false,
    available = false,
    hasOwner  = false,
    tableName = "addon_account_data",
}

CoreEngine = {}

function PLTServerDataLoaded()
    return dataLoaded
end

function CoreEngine.GetJobFromNode(nodeId, extra)
    if PLTServerNodes and PLTServerNodes.ResolveDepartment then
        return PLTServerNodes.ResolveDepartment(nodeId, extra)
    end
    return nil
end

function CoreEngine.TranslateToFrameworkJob(deptId)
    if PLTServerNodes and PLTServerNodes.TranslateToFrameworkJob then
        return PLTServerNodes.TranslateToFrameworkJob(deptId, DepartmentData, true)
    end
    return tostring(deptId or ""):lower()
end

function CoreEngine.Initialize()
    InitSQL()
    SetTimeout(3000, function()
        dataLoaded = true
    end)
end

function CoreEngine.ValidateSync(playerId)
    if not dataLoaded then return false end
    if not playerId or playerId <= 0 then return false end
    return true
end

function CoreEngine.IsHired(playerId)
    local player = Framework.GetPlayer(playerId)
    if not player then return false end
    local memberEntry = MemberData[player.citizenid]
    if memberEntry and memberEntry.dept ~= "none" then
        return true
    end
    return false
end

function CoreEngine.RefreshSystem(deptId)
    if not deptId then return end
    UpdateFinanceHistory(deptId)
    if Config.MDT and Config.MDT.enabled then
        RefreshMDTData(deptId)
    end
end

function IsPlayerAuthorized(playerId)
    
    -- ESX group check: ONLY gamemaster has management access (setgroup <id> gamemaster)
    if Framework and Framework.Type == "esx" and Framework.Core and Framework.Core.GetPlayerFromId then
        local xPlayer = Framework.Core.GetPlayerFromId(playerId)
        if xPlayer then
            local group = xPlayer.getGroup()
            if Config.ESXAdminGroups and #Config.ESXAdminGroups > 0 then
                for _, g in ipairs(Config.ESXAdminGroups) do
                    if group == g then return true end
                end
            else
                if group == "gamemaster" then return true end
            end
        end
    end

    if Config.Permission and Config.Permission ~= "" then
        if IsPlayerAceAllowed(playerId, Config.Permission) then
            return true
        end
    end

    if Config.AuthorizedLicenses and #Config.AuthorizedLicenses > 0 then
        local identifiers = GetPlayerIdentifiers(playerId)
        for _, id in ipairs(identifiers or {}) do
            for _, allowed in ipairs(Config.AuthorizedLicenses) do
                if id == allowed then
                    return true
                end
            end
        end
    end

    return false
end

local function ApplyDutyClockChange(citizenId, newOnDuty)
    local member = MemberData[citizenId]
    if not member then return end

    if newOnDuty then
        member.lastClockOn = os.time()
    else
        if member.lastClockOn and member.lastClockOn > 0 then
            local elapsed = os.time() - member.lastClockOn
            member.totalTime = (member.totalTime or 0) + elapsed
            member.lastClockOn = 0
        end
    end
end

local function AppendDutyLog(citizenId, playerName, deptId, actionLabel)
    if not DutyLogs[deptId] then
        DutyLogs[deptId] = {}
    end
    table.insert(DutyLogs[deptId], {
        cid     = citizenId,
        name    = playerName,
        officer = playerName,
        dept    = deptId,
        action  = actionLabel,
        time    = os.date("%I:%M %p"),
        date    = os.date("%Y-%m-%d"),
    })
    if #DutyLogs[deptId] > 50 then
        table.remove(DutyLogs[deptId], 1)
    end
    SaveDutyLogs()
end

local function HandleFrameworkDutyUpdate(playerId, newJobData)
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local citizenId  = player.citizenid
    local memberEntry = MemberData[citizenId]
    if not memberEntry then return end

    local newOnDuty = newJobData.onduty
    if memberEntry.onDuty == newOnDuty then return end

    memberEntry.onDuty = newOnDuty
    ApplyDutyClockChange(citizenId, newOnDuty)

    SaveMember(citizenId)
    SaveMembers()
    TriggerClientEvent("plt_departments:client:SyncMembers", -1, MemberData)

    local deptId     = memberEntry.dept
    local actionLabel = newOnDuty and "Clocked On (Framework)" or "Clocked Off (Framework)"
    AppendDutyLog(citizenId, player.name, deptId, actionLabel)
end

if Framework.Type == "qb" then
    AddEventHandler("QBCore:Server:OnJobUpdate", function(playerId, newJobData)
        HandleFrameworkDutyUpdate(playerId, newJobData)
    end)
end

RegisterNetEvent("qbx_core:server:onJobUpdate")
AddEventHandler("qbx_core:server:onJobUpdate", function(playerId, newJobData)
    HandleFrameworkDutyUpdate(playerId, newJobData)
end)

local function IsESXFramework()
    return Framework.Type == "esx"
end

local function IsOkOkBankingEnabled()
    return Config and Config.OkOkBanking and Config.OkOkBanking.enabled == true
end

local function IsRenewedBankingEnabled()
    return Config and Config.RenewedBanking and Config.RenewedBanking.enabled == true
end

local function GetAddonAccountTable()
    local tbl = (Config and Config.ESXAddonAccount and Config.ESXAddonAccount.table) or "addon_account_data"
    if type(tbl) ~= "string" or tbl == "" then return "addon_account_data" end
    tbl = tbl:gsub("[^%w_]", "")
    if tbl == "" then return "addon_account_data" end
    return tbl
end

local function GetSocietyAccountName(deptId)
    local prefix = (Config and Config.ESXAddonAccount and Config.ESXAddonAccount.prefix) or "society_"

    if IsRenewedBankingEnabled() then
        prefix = (Config and Config.RenewedBanking and Config.RenewedBanking.prefix) or ""
    elseif IsOkOkBankingEnabled() then
        prefix = (Config and Config.OkOkBanking and Config.OkOkBanking.prefix) or "society_"
    end

    local jobName = tostring(CoreEngine.TranslateToFrameworkJob(deptId) or deptId or ""):lower()
    if jobName == "" then return nil end

    if jobName:sub(1, #prefix) == prefix then
        return jobName
    end
    return prefix .. jobName
end

local function EnsureAddonAccountSchema()
    if PLTLibServer and PLTLibServer.ESXEnsureAddonSchema then
        return PLTLibServer.ESXEnsureAddonSchema(addonAccountState, IsESXFramework, GetAddonAccountTable)
    end
    return false
end

local function SyncESXDeptBalance(deptId, balance)
    if PLTLibServer and PLTLibServer.ESXSyncDeptBalance then
        PLTLibServer.ESXSyncDeptBalance(addonAccountState, EnsureAddonAccountSchema, GetSocietyAccountName, deptId, balance)
    end
end

local function SyncOkOkDeptBalance(deptId, balance)
    if PLTLibServer and PLTLibServer.OkOkSyncDeptBalance then
        PLTLibServer.OkOkSyncDeptBalance(GetSocietyAccountName(deptId), balance)
    end
end

local function GetESXDeptBalance(deptId)
    if PLTLibServer and PLTLibServer.ESXGetDeptBalance then
        return PLTLibServer.ESXGetDeptBalance(addonAccountState, EnsureAddonAccountSchema, GetSocietyAccountName, deptId)
    end
    return nil
end

local function GetOkOkDeptBalance(deptId)
    if PLTLibServer and PLTLibServer.OkOkGetDeptBalance then
        return PLTLibServer.OkOkGetDeptBalance(GetSocietyAccountName(deptId))
    end
    return nil
end

local function SyncRenewedDeptBalance(deptId, balance)
    if PLTLibServer and PLTLibServer.RenewedSyncDeptBalance then
        PLTLibServer.RenewedSyncDeptBalance(GetSocietyAccountName(deptId), balance)
    end
end

local function GetRenewedDeptBalance(deptId)
    if PLTLibServer and PLTLibServer.RenewedGetDeptBalance then
        return PLTLibServer.RenewedGetDeptBalance(GetSocietyAccountName(deptId))
    end
    return nil
end

function SyncAllDeptBalancesWithExternal()
    if not IsESXFramework() and not IsOkOkBankingEnabled() and not IsRenewedBankingEnabled() then return end
    if not DepartmentData or not DepartmentData.nodes then return end

    if PLTServerNodes and PLTServerNodes.ForEachDepartment then
        PLTServerNodes.ForEachDepartment(DepartmentData, function(dept)
            local balance = nil
            if IsRenewedBankingEnabled() then
                balance = GetRenewedDeptBalance(dept.id)
            elseif IsOkOkBankingEnabled() then
                balance = GetOkOkDeptBalance(dept.id)
            elseif IsESXFramework() then
                balance = GetESXDeptBalance(dept.id)
            end

            if balance ~= nil then
                DeptBalances[dept.id] = balance
            else
                local current = DeptBalances[dept.id]
                if not current then
                    current = (Config and Config.DefaultDeptBalance) or 0
                end
                DeptBalances[dept.id] = current
                if IsRenewedBankingEnabled() then
                    SyncRenewedDeptBalance(dept.id, current)
                elseif IsOkOkBankingEnabled() then
                    SyncOkOkDeptBalance(dept.id, current)
                elseif IsESXFramework() then
                    SyncESXDeptBalance(dept.id, current)
                end
            end
        end)
    end
end

function InitSQL()
    if PLTLibServer and PLTLibServer.SQLInit then
        PLTLibServer.SQLInit()
    end
end

function SaveSeizures()
    if PLTLibServer and PLTLibServer.SQLSaveSeizures then
        PLTLibServer.SQLSaveSeizures(SeizedVehicles)
    end
end

function SaveDelayedPayments()
    if PLTLibServer and PLTLibServer.SQLSaveDataBlob then
        PLTLibServer.SQLSaveDataBlob("delayed_payments", DelayedPayments)
    end
end

function SaveDoorStates()
    if PLTLibServer and PLTLibServer.SQLSaveDataBlob then
        PLTLibServer.SQLSaveDataBlob("doors", DoorStates)
    end
end

function SaveFinances()
    if PLTLibServer and PLTLibServer.SQLSaveDataBlob then
        PLTLibServer.SQLSaveDataBlob("finances", FinanceHistory)
    end
end

function SaveBalances()
    if PLTLibServer and PLTLibServer.SQLSaveDataBlob then
        PLTLibServer.SQLSaveDataBlob("balances", DeptBalances)
    end
    if IsRenewedBankingEnabled() then
        for deptId, balance in pairs(DeptBalances) do
            SyncRenewedDeptBalance(deptId, balance)
        end
    elseif IsOkOkBankingEnabled() then
        for deptId, balance in pairs(DeptBalances) do
            SyncOkOkDeptBalance(deptId, balance)
        end
    elseif IsESXFramework() then
        for deptId, balance in pairs(DeptBalances) do
            SyncESXDeptBalance(deptId, balance)
        end
    end
end

function SaveTransactions()
    
end

function SaveDepartments()
    if PLTLibServer and PLTLibServer.SQLSaveDataBlob then
        PLTLibServer.SQLSaveDataBlob("departments", DepartmentData)
    end
    TriggerClientEvent("plt_departments:client:SyncJobs", -1, DepartmentData)
end

function SaveMembers()
    TriggerClientEvent("plt_departments:client:SyncMembers", -1, MemberData)
end

function SaveMember(citizenId)
    if PLTLibServer and PLTLibServer.SQLSaveMember then
        PLTLibServer.SQLSaveMember(citizenId, MemberData[citizenId])
    end
end

function SaveCamera(cameraData)
    if PLTLibServer and PLTLibServer.SQLSaveCamera then
        PLTLibServer.SQLSaveCamera(cameraData)
    end
end

function DeleteCameraSQL(cameraId)
    if PLTLibServer and PLTLibServer.SQLDeleteCamera then
        PLTLibServer.SQLDeleteCamera(cameraId)
    end
end

function SaveWarrants()
    TriggerClientEvent("plt_departments:client:SyncWarrants", -1, Warrants)
end

function SaveWarrant(warrantData)
    if PLTLibServer and PLTLibServer.SQLSaveWarrant then
        PLTLibServer.SQLSaveWarrant(warrantData)
    end
end

function DeleteWarrantSQL(warrantId)
    if PLTLibServer and PLTLibServer.SQLDeleteWarrant then
        PLTLibServer.SQLDeleteWarrant(warrantId)
    end
end

function SaveCaseFiles()
    TriggerClientEvent("plt_departments:client:SyncCaseFiles", -1, CaseFiles)
end

function SaveCaseFile(caseData)
    if PLTLibServer and PLTLibServer.SQLSaveCaseFile then
        PLTLibServer.SQLSaveCaseFile(caseData)
    end
end

function DeleteCaseFileSQL(caseId)
    if PLTLibServer and PLTLibServer.SQLDeleteCaseFile then
        PLTLibServer.SQLDeleteCaseFile(caseId)
    end
end

function SaveBolos()
    TriggerClientEvent("plt_departments:client:SyncBolos", -1, Bolos)
end

function SaveBolo(boloData)
    if PLTLibServer and PLTLibServer.SQLSaveBolo then
        PLTLibServer.SQLSaveBolo(boloData)
    end
end

function DeleteBoloSQL(boloId)
    if PLTLibServer and PLTLibServer.SQLDeleteBolo then
        PLTLibServer.SQLDeleteBolo(boloId)
    end
end

function SaveNews()
    if PLTLibServer and PLTLibServer.SQLSaveDataBlob then
        PLTLibServer.SQLSaveDataBlob("news", DeptNews)
    end
    TriggerClientEvent("plt_departments:client:SyncNews", -1, DeptNews)
end

function SaveDutyLogs()
    if PLTLibServer and PLTLibServer.SQLSaveDutyLogs then
        PLTLibServer.SQLSaveDutyLogs(DutyLogs)
    end
    TriggerClientEvent("plt_departments:client:SyncDutyLogs", -1, DutyLogs)
end

function SaveDepartmentMail()
    if PLTLibServer and PLTLibServer.SQLSaveDataBlob then
        PLTLibServer.SQLSaveDataBlob("department_mail", DepartmentMail)
    end
    TriggerClientEvent("plt_departments:client:SyncDepartmentMail", -1, DepartmentMail)
end

function SaveAutoPay()
    if PLTLibServer and PLTLibServer.SQLSaveDataBlob then
        PLTLibServer.SQLSaveDataBlob("autopay", AutoPaySettings)
    end
end

function RefreshMDTData(deptId)
    if PLTLibServer and PLTLibServer.SQLRefreshMDT then
        return PLTLibServer.SQLRefreshMDT(deptId)
    end
end

function UpdateFinanceHistory(deptId)
    if not deptId or deptId == "none" then return end
    if not FinanceHistory[deptId] then FinanceHistory[deptId] = {} end

    local today   = os.date("%m/%d")
    local balance = DeptBalances[deptId] or (Config and Config.DefaultDeptBalance)
    local found   = false

    for _, entry in ipairs(FinanceHistory[deptId]) do
        if entry.date == today then
            entry.balance = balance
            found = true
            break
        end
    end

    if not found then
        table.insert(FinanceHistory[deptId], { date = today, balance = balance })
        if #FinanceHistory[deptId] > 30 then
            table.remove(FinanceHistory[deptId], 1)
        end
    end
    SaveFinances()
end

function AddFinanceTransaction(deptId, txType, amount, officer, target, reason)
    if not deptId or deptId == "none" then return end
    if not FinanceTransactions[deptId] then FinanceTransactions[deptId] = {} end

    local entry = {
        type      = txType,
        amount    = amount,
        officer   = officer,
        target    = target,
        reason    = reason,
        timestamp = os.time(),
        date      = os.date("%m/%d/%Y %H:%M"),
    }
    table.insert(FinanceTransactions[deptId], entry)
    if #FinanceTransactions[deptId] > 50 then
        table.remove(FinanceTransactions[deptId], 1)
    end

    if PLTLibServer and PLTLibServer.SQLInsertFinanceTransaction then
        PLTLibServer.SQLInsertFinanceTransaction(deptId, txType, amount, officer, target, reason, entry.timestamp)
    end
    TriggerClientEvent("plt_departments:client:SyncTransactions", -1, FinanceTransactions)
end

local function HandleTakeArmoryItem(playerId, itemName, amount, armoryId, extra)
    if PLTLibServer and PLTLibServer.HandleTakeArmoryItem then
        PLTLibServer.HandleTakeArmoryItem(playerId, itemName, amount, armoryId, extra)
    end
end

function RegisterStashes()
    local invType = Config and Config.Inventory
    if invType ~= "ox" and invType ~= "tgiann" then return end
    if not DepartmentData or not DepartmentData.nodes then return end

    local stashNodes = {}
    if PLTServerNodes and PLTServerNodes.GetLocationStashNodes then
        stashNodes = PLTServerNodes.GetLocationStashNodes(DepartmentData)
    end

    for _, node in ipairs(stashNodes) do
        local stashId    = "stash_" .. node.id
        local stashLabel = node.label or "Department Stash"
        Inventory.RegisterStash(stashId, stashLabel, 50, 100000)
    end
end

local function DistributeDeptSalariesInternal(deptId, isAuto, sourcePlayerId)
    if PLTLibServer and PLTLibServer.BossDistributeDeptSalaries then
        PLTLibServer.BossDistributeDeptSalaries(deptId, isAuto, sourcePlayerId)
    end
end

local autoSalaryLastPaid = {}

RegisterNetEvent("plt_departments:server:AddCamera")
AddEventHandler("plt_departments:server:AddCamera", function(cameraData)
    local playerId = source
    if not cameraData.deptId or not cameraData.name or not cameraData.coords then return end

    local newCamera = {
        id      = os.time(),
        deptId  = cameraData.deptId,
        name    = cameraData.name,
        coords  = cameraData.coords,
        heading = cameraData.heading or 0.0,
    }
    table.insert(Cameras, newCamera)
    SaveCamera(newCamera)
    TriggerClientEvent("plt_departments:client:SyncCameras", -1, Cameras)
    Framework.Notify(playerId, T("camera_placed", { name = cameraData.name }), "success")
end)

RegisterNetEvent("plt_departments:server:DeleteCamera")
AddEventHandler("plt_departments:server:DeleteCamera", function(cameraId)
    local playerId = source
    for i, cam in ipairs(Cameras) do
        if cam.id == cameraId then
            table.remove(Cameras, i)
            DeleteCameraSQL(cameraId)
            TriggerClientEvent("plt_departments:client:SyncCameras", -1, Cameras)
            Framework.Notify(playerId, T("camera_removed"), "primary")
            break
        end
    end
end)

function __sA0(_, callback)
    callback(Cameras)
end

RegisterNetEvent("plt_departments:server:takeArmoryItem")
AddEventHandler("plt_departments:server:takeArmoryItem", function(itemName, amount, armoryId, extra)
    HandleTakeArmoryItem(source, itemName, amount, armoryId, extra)
end)

RegisterNetEvent("plt_departments:s4")
AddEventHandler("plt_departments:s4", function(itemName, amount, armoryId, extra)
    HandleTakeArmoryItem(source, itemName, amount, armoryId, extra)
end)

RegisterNetEvent("plt_departments:server:toggleAutoPay")
AddEventHandler("plt_departments:server:toggleAutoPay", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.BossToggleAutoPay then
        PLTLibServer.BossToggleAutoPay(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:sg")
AddEventHandler("plt_departments:sg", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.BossToggleAutoPay then
        PLTLibServer.BossToggleAutoPay(playerId, payload)
    end
end)

function SyncPlayerMemberData(playerId)
    if PLTLibServer and PLTLibServer.SyncPlayerMemberData then
        PLTLibServer.SyncPlayerMemberData(playerId)
    end
end

local function OnPlayerLoadedSync(playerId)
    SyncPlayerMemberData(playerId)
    TriggerClientEvent("plt_departments:client:SyncJobs",    playerId, DepartmentData)
    TriggerClientEvent("plt_departments:client:SyncMembers", playerId, MemberData)
end

RegisterNetEvent("QBCore:Server:OnPlayerLoaded")
AddEventHandler("QBCore:Server:OnPlayerLoaded", function()
    OnPlayerLoadedSync(source)
end)

RegisterNetEvent("qbx_core:server:onPlayerLoaded")
AddEventHandler("qbx_core:server:onPlayerLoaded", function(playerId)
    OnPlayerLoadedSync(playerId)
end)

RegisterNetEvent("QBCore:Server:OnJobUpdate")
AddEventHandler("QBCore:Server:OnJobUpdate", function(playerId, _)
    SyncPlayerMemberData(playerId)
end)

RegisterNetEvent("qbx_core:server:onJobUpdate")
AddEventHandler("qbx_core:server:onJobUpdate", function(playerId, _)
    SyncPlayerMemberData(playerId)
end)

RegisterNetEvent("esx:playerLoaded")
AddEventHandler("esx:playerLoaded", function(playerId)
    OnPlayerLoadedSync(playerId)
end)

RegisterNetEvent("esx:setJob")
AddEventHandler("esx:setJob", function(playerId, newJob)
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local citizenId   = player.citizenid
    local memberEntry = MemberData[citizenId]
    if not memberEntry then
        SyncPlayerMemberData(playerId)
        return
    end

    local changed = false

    if memberEntry.grade ~= newJob.grade then
        memberEntry.grade = newJob.grade
        changed = true
    end

    local newDeptId = nil
    if PLTServerNodes and PLTServerNodes.GetNodeIdFromFrameworkJob then
        newDeptId = PLTServerNodes.GetNodeIdFromFrameworkJob(newJob.name, DepartmentData)
    end

    if newDeptId and memberEntry.dept ~= newDeptId then
        memberEntry.dept = newDeptId
        changed = true
    end

    if changed then
        SaveMember(citizenId)
        SaveMembers()
        TriggerClientEvent("plt_departments:client:SyncMembers", -1, MemberData)
        AppendDutyLog(citizenId, player.name, memberEntry.dept, "Job Updated (ESX Framework)")
    end
end)

function __sA1(playerId, callback, extra)
    if PLTLibServer and PLTLibServer.GetImpoundedVehicles then
        return PLTLibServer.GetImpoundedVehicles(playerId, callback, extra)
    end
    callback({})
end

RegisterNetEvent("plt_departments:server:seizeVehicle")
AddEventHandler("plt_departments:server:seizeVehicle", function(plate, reason, extra)
    local playerId = source
    if PLTLibServer and PLTLibServer.SeizeVehicle then
        PLTLibServer.SeizeVehicle(playerId, plate, reason, extra)
    end
end)

function __sA2(playerId, callback, extra)
    if PLTLibServer and PLTLibServer.CanUnimpound then
        return PLTLibServer.CanUnimpound(playerId, callback, extra)
    end
    callback(false)
end

function __sA3(playerId, callback, extra)
    if PLTLibServer and PLTLibServer.GetVehicleInfo then
        return PLTLibServer.GetVehicleInfo(playerId, callback, extra)
    end
    callback(nil)
end

function __sA4(playerId, callback)
    if PLTLibServer and PLTLibServer.BossGetData then
        return PLTLibServer.BossGetData(playerId, callback)
    end
    callback(nil)
end

RegisterNetEvent("plt_departments:server:manageDivision")
AddEventHandler("plt_departments:server:manageDivision", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.ManageDivision then
        PLTLibServer.ManageDivision(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:sc")
AddEventHandler("plt_departments:sc", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.ManageDivision then
        PLTLibServer.ManageDivision(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:server:toggleMemberDivision")
AddEventHandler("plt_departments:server:toggleMemberDivision", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.ToggleMemberDivision then
        PLTLibServer.ToggleMemberDivision(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:sd")
AddEventHandler("plt_departments:sd", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.ToggleMemberDivision then
        PLTLibServer.ToggleMemberDivision(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:server:submitOfficerReport")
AddEventHandler("plt_departments:server:submitOfficerReport", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.SubmitOfficerReport then
        PLTLibServer.SubmitOfficerReport(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:sh")
AddEventHandler("plt_departments:sh", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.SubmitOfficerReport then
        PLTLibServer.SubmitOfficerReport(playerId, payload)
    end
end)

local function HandleDistributeSalaries(playerId, payload)
    if type(payload) ~= "table" then return end

    local hasBossAccess = false
    if PLTServerNodes and PLTServerNodes.HasBossMenuAccess then
        hasBossAccess = PLTServerNodes.HasBossMenuAccess(playerId, DepartmentData, MemberData)
    end

    if not payload.auto then
        if not IsPlayerAuthorized(playerId) and not hasBossAccess then return end
    end

    DistributeDeptSalariesInternal(payload.dept, payload.auto, playerId)
end

RegisterNetEvent("plt_departments:server:distributeSalaries")
AddEventHandler("plt_departments:server:distributeSalaries", function(payload)
    HandleDistributeSalaries(source, payload)
end)

RegisterNetEvent("plt_departments:sf")
AddEventHandler("plt_departments:sf", function(payload)
    HandleDistributeSalaries(source, payload)
end)

RegisterNetEvent("plt_departments:server:financeAction")
AddEventHandler("plt_departments:server:financeAction", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.BossFinanceAction then
        PLTLibServer.BossFinanceAction(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:se")
AddEventHandler("plt_departments:se", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.BossFinanceAction then
        PLTLibServer.BossFinanceAction(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:server:SaveData")
AddEventHandler("plt_departments:server:SaveData", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.BossSaveData then
        PLTLibServer.BossSaveData(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:s9")
AddEventHandler("plt_departments:s9", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.BossSaveData then
        PLTLibServer.BossSaveData(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:server:GetWeapon")
AddEventHandler("plt_departments:server:GetWeapon", function(payload)
    local playerId = source
    local player   = Framework.GetPlayer(playerId)
    if not player then return end

    local citizenId   = player.citizenid
    local memberEntry = MemberData[citizenId]
    if not memberEntry then
        Framework.Notify(playerId, T("not_in_dept"), "error")
        return
    end

    local weaponName = payload.weapon
    local deptId     = memberEntry.dept
    local grade      = memberEntry.grade
    local allowed    = false

    if PLTServerNodes and PLTServerNodes.IsWeaponAllowedForDept then
        allowed = PLTServerNodes.IsWeaponAllowedForDept(deptId, grade, weaponName, DepartmentData)
    end

    if allowed then
        Inventory.AddItem(playerId, weaponName, 1)
    else
        Framework.Notify(playerId, T("not_allowed_weapon"), "error")
    end
end)

function __sA5(playerId, callback, extra)
    if PLTLibServer and PLTLibServer.CheckBolo then
        return PLTLibServer.CheckBolo(playerId, callback, extra)
    end
    callback(false)
end

function __sA6(playerId, callback)
    if PLTLibServer and PLTLibServer.GetPlayers then
        return PLTLibServer.GetPlayers(playerId, callback)
    end
    callback({})
end

RegisterNetEvent("plt_departments:server:hirePlayer")
AddEventHandler("plt_departments:server:hirePlayer", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.HirePlayer then
        PLTLibServer.HirePlayer(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:sa")
AddEventHandler("plt_departments:sa", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.HirePlayer then
        PLTLibServer.HirePlayer(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:server:updateRankSalary")
AddEventHandler("plt_departments:server:updateRankSalary", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.UpdateRankSalary then
        PLTLibServer.UpdateRankSalary(playerId, payload)
    end
end)

RegisterNetEvent("plt_departments:sb")
AddEventHandler("plt_departments:sb", function(payload)
    local playerId = source
    if PLTLibServer and PLTLibServer.UpdateRankSalary then
        PLTLibServer.UpdateRankSalary(playerId, payload)
    end
end)

function __sA7(playerId, callback, extra)
    if PLTLibServer and PLTLibServer.ManageMember then
        return PLTLibServer.ManageMember(playerId, callback, extra)
    end
    callback(false)
end

function __sC1(playerId)
    if IsPlayerAuthorized(playerId) then
        TriggerClientEvent("plt_departments:client:OpenManager", playerId)
    else
        Framework.Notify(playerId, T("no_permission_manage_dept"), "error")
    end
end

function __sC2(playerId)
    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local citizenId   = player.citizenid
    local memberEntry = MemberData[citizenId]
    if not memberEntry or memberEntry.dept == "none" then
        Framework.Notify(playerId, T("not_in_dept"), "error")
        return
    end

    local deptLabel = "Unknown"
    local rankLabel = "Unknown"
    if PLTServerNodes and PLTServerNodes.GetMemberDeptSnapshot then
        local snapshot = PLTServerNodes.GetMemberDeptSnapshot(memberEntry, DepartmentData)
        deptLabel = snapshot.deptLabel
        rankLabel = snapshot.rankLabel
    end

    local statusText  = memberEntry.onDuty and "On Duty"  or "Off Duty"
    local statusColor = memberEntry.onDuty and "~g~"      or "~r~"

    TriggerClientEvent("chat:addMessage", playerId, {
        color     = { 0, 255, 204 },
        multiline = true,
        args      = {
            "Department",
            string.format("Unit: %s | Rank: %s | Status: %s%s",
                deptLabel, rankLabel, statusColor, statusText),
        },
    })
end

RegisterNetEvent("plt_departments:server:OpenStash")
AddEventHandler("plt_departments:server:OpenStash", function(_, stashId)
    local playerId = source
    Inventory.OpenStash(playerId, "stash_" .. stashId, stashId, 50, 100000)
end)

RegisterNetEvent("plt_departments:si")
AddEventHandler("plt_departments:si", function(_, stashId)
    local playerId = source
    Inventory.OpenStash(playerId, "stash_" .. stashId, stashId, 50, 100000)
end)

local function HandleToggleDuty(playerId)
    if PLTLibServer and PLTLibServer.HandleDutyToggle then
        PLTLibServer.HandleDutyToggle(playerId)
    end
end

RegisterNetEvent("plt_departments:server:ToggleDuty")
AddEventHandler("plt_departments:server:ToggleDuty", function()
    HandleToggleDuty(source)
end)

RegisterNetEvent("plt_departments:s3")
AddEventHandler("plt_departments:s3", function()
    HandleToggleDuty(source)
end)

function __sE0(playerId)
    local player = Framework.GetPlayer(playerId)
    if not player then return nil end
    local citizenId = Framework.GetIdentifier(playerId)
    return MemberData[citizenId]
end

function __sE1(playerId)
    local player = Framework.GetPlayer(playerId)
    if not player then return false end
    local citizenId   = Framework.GetIdentifier(playerId)
    local memberEntry = MemberData[citizenId]
    if memberEntry then
        return memberEntry.onDuty
    end
    local playerData = Framework.GetPlayerData(playerId)
    return playerData and playerData.job and playerData.job.onduty
end

function __sE2(playerId)
    local player = Framework.GetPlayer(playerId)
    if not player then return "none" end
    local citizenId   = Framework.GetIdentifier(playerId)
    local memberEntry = MemberData[citizenId]
    if memberEntry then
        return memberEntry.dept
    end
    local playerData = Framework.GetPlayerData(playerId)
    if playerData and playerData.job and playerData.job.name then
        return playerData.job.name
    end
    return "none"
end

function __sE3(boloData)
    if not boloData then return end
    local entry = {
        id          = boloData.id      or os.time(),
        type        = boloData.type    or "Vehicle",
        title       = boloData.title   or "Unknown BOLO",
        description = boloData.description or "",
        plate       = boloData.plate   or "",
        owner       = boloData.owner   or "",
        lastSeen    = boloData.lastSeen or "",
        issuedBy    = boloData.issuedBy or "System",
        issuedDate  = boloData.issuedDate or os.date("%Y-%m-%d %H:%M"),
        status      = "Active",
    }
    table.insert(Bolos, entry)
    SaveBolos()
    return entry.id
end

function __sE4(boloId, updates)
    if not boloId or not updates then return false end
    for i, bolo in ipairs(Bolos) do
        if bolo.id == boloId then
            Bolos[i].title       = updates.title       or bolo.title
            Bolos[i].description = updates.description or bolo.description
            Bolos[i].type        = updates.type        or bolo.type
            Bolos[i].plate       = updates.plate       or bolo.plate
            Bolos[i].owner       = updates.owner       or bolo.owner
            Bolos[i].lastSeen    = updates.lastSeen    or bolo.lastSeen
            SaveBolos()
            return true
        end
    end
    return false
end

function __sE5(boloId)
    if not boloId then return false end
    for i, bolo in ipairs(Bolos) do
        if bolo.id == boloId then
            table.remove(Bolos, i)
            SaveBolos()
            return true
        end
    end
    return false
end

function __sE6(warrantData)
    if not warrantData then return end
    local entry = {
        id          = warrantData.id          or os.time(),
        subject     = warrantData.subject     or "Unknown",
        charges     = warrantData.charges     or "No charges listed",
        priority    = warrantData.priority    or "Standard",
        issuedBy    = warrantData.issuedBy    or "System",
        issuedDate  = warrantData.issuedDate  or os.date("%Y-%m-%d %H:%M"),
        description = warrantData.description or "",
        status      = "Active",
    }
    table.insert(Warrants, entry)
    SaveWarrants()
    return entry.id
end

function __sE7(warrantId, updates)
    if not warrantId or not updates then return false end
    for i, warrant in ipairs(Warrants) do
        if warrant.id == warrantId then
            Warrants[i].subject     = updates.subject     or warrant.subject
            Warrants[i].charges     = updates.charges     or warrant.charges
            Warrants[i].priority    = updates.priority    or warrant.priority
            Warrants[i].description = updates.description or warrant.description
            SaveWarrants()
            return true
        end
    end
    return false
end

function __sE8(warrantId)
    if not warrantId then return false end
    for i, warrant in ipairs(Warrants) do
        if warrant.id == warrantId then
            table.remove(Warrants, i)
            SaveWarrants()
            return true
        end
    end
    return false
end

function __sE9(playerId)
    local player = Framework.GetPlayer(playerId)
    if not player then return nil end
    local citizenId   = player.citizenid
    local memberEntry = MemberData[citizenId]
    if memberEntry and memberEntry.dept ~= "none" then
        return memberEntry.dept
    end
    return nil
end

function __sEA(deptId, amount, reason, sourcePlayerId)
    if not deptId or not amount then return false end
    local parsedAmount = tonumber(amount)
    if not parsedAmount or parsedAmount <= 0 then return false end

    DeptBalances[deptId] = (DeptBalances[deptId] or (Config and Config.DefaultDeptBalance) or 0) + parsedAmount
    SaveBalances()
    UpdateFinanceHistory(deptId)

    local officerName = "External System"
    local officerId   = "MDT"
    if sourcePlayerId and sourcePlayerId > 0 then
        local officerPlayer = Framework.GetPlayer(sourcePlayerId)
        if officerPlayer then
            officerName = officerPlayer.name
            officerId   = officerPlayer.citizenid
        end
    end

    AddFinanceTransaction(deptId, "fine_paid", parsedAmount,
        { name = officerName, cid = officerId },
        { name = "Department Treasury", cid = deptId },
        reason or "External Fine Payment"
    )
    TriggerClientEvent("plt_departments:client:SyncFinances", -1, FinanceHistory, DeptBalances)
    return true
end

local function ResolveDeptIdFromNodes(rawId)
    local id = tostring(rawId or ""):lower()
    if id == "" then return nil end
    if not DepartmentData or not DepartmentData.nodes then return nil end

    for _, node in ipairs(DepartmentData.nodes) do
        if node.type == "department" then
            local nodeId = tostring(node.id or ""):lower()
            if nodeId == id then
                return tostring(node.id):lower()
            end
        end
    end

    if PLTServerNodes and PLTServerNodes.GetNodeIdFromFrameworkJob then
        local resolved = PLTServerNodes.GetNodeIdFromFrameworkJob(id, DepartmentData)
        if resolved then
            return tostring(resolved):lower()
        end
    end
    return nil
end

local function ResolveDeptIdFromAmbulanceJob(rawId)
    local id = tostring(rawId or ""):lower()
    if id == "" then return nil end
    if GetResourceState("plt_ambulance_job") ~= "started" then return nil end

    local ok, catalog = pcall(function()
        return exports.plt_ambulance_job:GetDepartmentCatalog()
    end)
    if not ok or type(catalog) ~= "table" then return nil end

    for _, entry in ipairs(catalog) do
        if type(entry) == "table" then
            local entryId  = tostring(entry.id or entry.deptId or ""):lower()
            local entryJob = tostring(entry.frameworkJob or entry.job or ""):lower()
            if id == entryId or (entryJob ~= "" and id == entryJob) then
                return entryId
            end
        end
    end
    return nil
end

local function ValidateImageUrl(url)
    local str = tostring(url or "")
    if str == "" or #str > 1024 then return nil end
    local lower = str:lower()
    if lower:sub(1, 7) ~= "http://" and lower:sub(1, 8) ~= "https://" then return nil end
    return str
end

function __sEB(fromDeptId, toDeptId, senderName, subject, message, imageUrl)
    local from = ResolveDeptIdFromNodes(fromDeptId)
    local to   = ResolveDeptIdFromNodes(toDeptId)

    if not from or not to then return false end
    if tostring(from) == tostring(to) then return false end  

    if not subject or subject == "" then return false end
    if not message or message == "" then return false end

    if not DepartmentMail[to] then DepartmentMail[to] = {} end

    local mailEntry = {
        id         = os.time() * 1000 + math.random(100, 999),
        fromDept   = from,
        toDept     = to,
        senderName = senderName,
        subject    = subject,
        message    = message,
        imageUrl   = imageUrl,
        date       = os.date("%Y-%m-%d"),
        time       = os.date("%H:%M"),
        timestamp  = os.time(),
    }
    table.insert(DepartmentMail[to], mailEntry)
    if #DepartmentMail[to] > 200 then
        table.remove(DepartmentMail[to], 1)
    end
    SaveDepartmentMail()
    return true
end

RegisterNetEvent("plt_departments:server:sendDepartmentMail")
AddEventHandler("plt_departments:server:sendDepartmentMail", function(payload)
    local playerId = source
    if type(payload) ~= "table" then return end

    local player = Framework.GetPlayer(playerId)
    if not player then return end

    local citizenId   = player.citizenid
    local memberEntry = MemberData[citizenId]
    if not memberEntry or memberEntry.dept == "none" then
        Framework.Notify(playerId, T("not_in_dept"), "error")
        return
    end

    local hasBossAccess = false
    if PLTServerNodes and PLTServerNodes.HasBossMenuAccess then
        hasBossAccess = PLTServerNodes.HasBossMenuAccess(playerId, DepartmentData, MemberData)
    end
    if not IsPlayerAuthorized(playerId) and not hasBossAccess then
        Framework.Notify(playerId, T("no_boss_perms"), "error")
        return
    end

    local fromDeptId = ResolveDeptIdFromNodes(payload.fromDept) or ResolveDeptIdFromNodes(memberEntry.dept)
    local myDeptId   = ResolveDeptIdFromNodes(memberEntry.dept)

    if not fromDeptId or not myDeptId or tostring(fromDeptId) ~= tostring(myDeptId) then
        Framework.Notify(playerId, T("no_permission_manage_dept"), "error")
        return
    end

    local senderName = payload.senderName
    if not senderName or tostring(senderName) == "" then
        senderName = player.name or "Dispatch Center"
    end

    local sent = __sEB(fromDeptId, payload.toDept, senderName, payload.subject, payload.message, payload.imageUrl)
    if sent then
        Framework.Notify(playerId, "Mail sent.", "success")
    else
        Framework.Notify(playerId, "Unable to send mail.", "error")
    end
end)

CreateThread(function()
    local blipColorMap = {}
    while true do
        Wait(2000)
        if dataLoaded then
            local onDutyBlips    = {}
            local onDutyPlayers  = {}

            if DepartmentData and DepartmentData.nodes then
                if PLTServerNodes and PLTServerNodes.GetDepartmentBlipColorMap then
                    blipColorMap = PLTServerNodes.GetDepartmentBlipColorMap(DepartmentData)
                end
            end

            for _, rawId in ipairs(GetPlayers()) do
                local serverId = tonumber(rawId)
                local player   = Framework.GetPlayer(serverId)
                if player then
                    local citizenId   = player.citizenid
                    local memberEntry = MemberData[citizenId]
                    if memberEntry and memberEntry.onDuty and memberEntry.dept ~= "none" then
                        local ped = GetPlayerPed(serverId)
                        if DoesEntityExist(ped) then
                            local coords  = GetEntityCoords(ped)
                            local deptKey = tostring(memberEntry.dept)
                            local color   = blipColorMap[deptKey] or 1
                            table.insert(onDutyBlips, {
                                source = serverId,
                                coords = coords,
                                name   = player.name or "Officer",
                                dept   = deptKey,
                                color  = color,
                            })
                            table.insert(onDutyPlayers, serverId)
                        end
                    end
                end
            end

            if #onDutyPlayers > 0 then
                for _, serverId in ipairs(onDutyPlayers) do
                    TriggerClientEvent("plt_departments:client:UpdateOfficerBlips", serverId, onDutyBlips)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(3600000)
        local now     = os.time()
        local didPay  = false

        for i = #DelayedPayments, 1, -1 do
            local payment = DelayedPayments[i]
            if now >= payment.dueAt then
                local amount = tonumber(payment.amount)
                local target = Framework.GetPlayerByCitizenId(payment.targetCid)

                if target then
                    target.functions.RemoveMoney("bank", amount, "forced-citation-payment")
                elseif PLTLibServer and PLTLibServer.SQLAdjustOfflineBank then
                    PLTLibServer.SQLAdjustOfflineBank(Framework.Type, payment.targetCid, -amount)
                end

                local deptId = payment.deptId
                if deptId and deptId ~= "none" then
                    DeptBalances[deptId] = (DeptBalances[deptId] or 0) + amount
                    UpdateFinanceHistory(deptId)
                    AddFinanceTransaction(deptId, "fine_forced", amount,
                        { name = payment.officerName, cid = payment.officerCid },
                        { name = payment.targetName,  cid = payment.targetCid },
                        "Forced Payment (Denied Citation)"
                    )
                end

                table.remove(DelayedPayments, i)
                didPay = true
            end
        end

        if didPay then
            SaveBalances()
            SaveDelayedPayments()
            TriggerClientEvent("plt_departments:client:SyncFinances",        -1, FinanceHistory, DeptBalances)
            TriggerClientEvent("plt_departments:client:SyncFinancesWithAuto", -1, FinanceHistory, DeptBalances, AutoPaySettings)
        end
    end
end)

CreateThread(function()
    Wait(10000)
    while true do
        Wait(2000)
        local dateTable = os.date("*t")
        local nowTs     = os.time()

        for deptId, schedule in pairs(AutoPaySettings) do
            if schedule and schedule ~= "none" then
                local shouldPay = false

                if schedule == "hourly" then
                    if dateTable.min == 0 then
                        local lastPaid = autoSalaryLastPaid[deptId]
                        if not lastPaid or (nowTs - lastPaid) > 3000 then
                            shouldPay = true
                        end
                    end
                elseif schedule == "daily" then
                    if dateTable.hour == 0 and dateTable.min == 0 then
                        local lastPaid = autoSalaryLastPaid[deptId]
                        if not lastPaid or (nowTs - lastPaid) > 3000 then
                            shouldPay = true
                        end
                    end
                end

                if shouldPay then
                    autoSalaryLastPaid[deptId] = nowTs
                    DistributeDeptSalariesInternal(deptId, true, 0)
                end
            end
        end
    end
end)

PLTLibServer.RegisterCoreCallbacks()

if PLTLibServer.RegisterPublicCallbacksAndExports then
    PLTLibServer.RegisterPublicCallbacksAndExports()
end

if PLTLibServer.StartupLoadThread then
    PLTLibServer.StartupLoadThread()
end

local function MigrateData()
    if PLTLibServer and PLTLibServer.SQLMigrateData then
        return PLTLibServer.SQLMigrateData()
    end
end

if PLTLibServer.SQLReadyGate then
    PLTLibServer.SQLReadyGate(function()
        CoreEngine.Initialize()
    end)
else
    CoreEngine.Initialize()
end
