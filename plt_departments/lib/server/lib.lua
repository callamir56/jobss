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


PLTServerNodes = PLTServerNodes or {}
PLTLibServer   = PLTLibServer   or {}

local sessionStore = { sessions = {} }   

local actionCooldowns = {
    duty_toggle        = 1200,
    armory_take        = 450,
    seize_vehicle      = 800,
    unimpound_vehicle  = 800,
    get_players        = 0,
    get_vehicle_info   = 800,
    hire_member        = 1200,
    manage_member      = 500,
    rank_salary        = 900,
    division_manage    = 700,
    division_toggle    = 350,
    officer_report     = 1000,
    boss_finance       = 400,
}

local function HashString(value)
    local str  = tostring(value or "")
    local hash = 0
    for i = 1, #str do
        hash = (hash + string.byte(str, i) * i) % 100003
    end
    return hash
end

local function TableByteSize(tbl)
    if type(tbl) ~= "table" then return 0 end
    local size = 0
    for k, v in pairs(tbl) do
        size = size + #tostring(k) + #tostring(v)
    end
    return size
end

local function ValidateActionPayload(action, payload)
    if type(payload) ~= "table" then payload = {} end

    if action == "armory_take" then
        local itemName = tostring(payload.itemName or "")
        local itemType = tostring(payload.itemType or "")
        local qty      = tonumber(payload.quantity) or 1
        if itemName == "" or #itemName > 80                then return false end
        if itemType ~= "weapon" and itemType ~= "item"     then return false end
        if payload.nodeId == nil                           then return false end
        local cap = (qty < 1) and 1 or 1000
        if qty > cap                                       then return false end

    elseif action == "hire_member" then
        local playerId = tonumber(payload.playerId)
        local job      = tostring(payload.job   or "")
        local grade    = tonumber(payload.grade) or 0
        if not playerId or playerId <= 0                   then return false end
        if job == "" or #job > 80                          then return false end
        if grade < 0 or grade > 50                         then return false end

    elseif action == "manage_member" then
        local cid = tostring(payload.cid    or "")
        local act = tostring(payload.action or "")
        if cid == "" or #cid > 80                          then return false end
        if (act ~= "" and #act or 0) > 40                 then return false end

    elseif action == "rank_salary" then
        local level = tonumber(payload.level)
        local pay   = tonumber(payload.pay)
        if not level or level < 0 or level > 50            then return false end
        local maxPay = (pay and pay >= 0) and 500000 or 0
        if pay and pay > maxPay                            then return false end

    elseif action == "division_manage" then
        local act = tostring(payload.action or "")
        if act ~= "create" and act ~= "delete"             then return false end
        if act == "create" then
            local nameLen = (tostring(payload.name or "") ~= "") and #tostring(payload.name) or 0
            if nameLen > 64                                then return false end
        end

    elseif action == "officer_report" then
        local fields = { "knowledge", "communication", "situation_management",
                         "decision_making", "report_writing", "overall" }
        for _, field in ipairs(fields) do
            local val = tonumber(payload[field])
            if not val or val < 0 or val > 10             then return false end
        end

    elseif action == "boss_finance" then
        local dept   = tostring(payload.dept   or "")
        local act    = tostring(payload.action or "")
        local amount = tonumber(payload.amount)
        if dept == "" or #dept > 80                        then return false end
        if act ~= "deposit" and act ~= "withdraw"          then return false end
        if not amount or amount <= 0 or amount > 50000000  then return false end
    end

    return true
end

local function GetFrameworkTableNames()
    local fw = Framework.Type
    return
        (fw == "qb") and "player_vehicles" or "owned_vehicles",
        (fw == "qb") and "players"         or "users",
        (fw == "qb") and "citizenid"       or "identifier"
end

local function SafeToString(id)
    if id == nil then return nil end
    return tostring(id)
end

function PLTLibServer.SQLReadyGate(callback)
    MySQL.ready(function()
        if callback then callback() end
    end)
end

function PLTLibServer.ESXEnsureAddonSchema(schemaState, isESXFn, tableNameFn)
    if not isESXFn() then return false end
    if schemaState.checked then return schemaState.available end

    local tableName = tableNameFn()
    schemaState.tableName = tableName

    local rows = MySQL.Sync.fetchAll("SHOW TABLES LIKE ?", { tableName })
    if not rows or #rows == 0 then
        schemaState.checked   = true
        schemaState.available = false
        return false
    end

    local ownerCheck  = MySQL.Sync.fetchAll(
        ("SHOW COLUMNS FROM `%s` LIKE \"owner\""):format(tableName), {})
    schemaState.hasOwner  = ownerCheck and #ownerCheck > 0
    schemaState.checked   = true
    schemaState.available = true
    return true
end

function PLTLibServer.ESXSyncDeptBalance(schemaState, isESXFn, accountNameFn, amount, newBalance)
    if not isESXFn() then return end
    local accountName = accountNameFn(amount)
    if not accountName then return end

    local balance = tonumber(newBalance) or 0
    local tbl     = schemaState.tableName

    if schemaState.hasOwner then
        local sql = ("UPDATE `%s` SET money = ? WHERE account_name = ? AND (owner IS NULL OR owner = \"\")"):format(tbl)
        local affected = MySQL.Sync.execute(sql, { balance, accountName })
        if affected == 0 then
            pcall(function()
                MySQL.Sync.execute(
                    ("INSERT INTO `%s` (account_name, money, owner) VALUES (?, ?, NULL)"):format(tbl),
                    { accountName, balance })
            end)
        end
    else
        local sql = ("UPDATE `%s` SET money = ? WHERE account_name = ?"):format(tbl)
        local affected = MySQL.Sync.execute(sql, { balance, accountName })
        if affected == 0 then
            pcall(function()
                MySQL.Sync.execute(
                    ("INSERT INTO `%s` (account_name, money) VALUES (?, ?)"):format(tbl),
                    { accountName, balance })
            end)
        end
    end
end

function PLTLibServer.ESXGetDeptBalance(schemaState, isESXFn, accountNameFn, deptId)
    if not isESXFn() then return nil end
    local accountName = accountNameFn(deptId)
    if not accountName then return nil end

    local tbl = schemaState.tableName
    local rows
    if schemaState.hasOwner then
        rows = MySQL.Sync.fetchAll(
            ("SELECT money FROM `%s` WHERE account_name = ? AND (owner IS NULL OR owner = \"\") LIMIT 1"):format(tbl),
            { accountName })
    else
        rows = MySQL.Sync.fetchAll(
            ("SELECT money FROM `%s` WHERE account_name = ? LIMIT 1"):format(tbl),
            { accountName })
    end

    if rows and rows[1] and rows[1].money ~= nil then
        return tonumber(rows[1].money) or 0
    end
    return nil
end

function PLTLibServer.OkOkGetDeptBalance(society)
    if not society then return nil end
    local rows = MySQL.Sync.fetchAll(
        "SELECT value FROM `okokbanking_societies` WHERE society = ? LIMIT 1", { society })
    if rows and rows[1] and rows[1].value ~= nil then
        return tonumber(rows[1].value) or 0
    end
    return nil
end

function PLTLibServer.OkOkSyncDeptBalance(society, newBalance)
    if not society then return end
    MySQL.Sync.execute(
        "UPDATE `okokbanking_societies` SET value = ? WHERE society = ?",
        { tonumber(newBalance) or 0, society })
end

function PLTLibServer.RenewedGetDeptBalance(society)
    if not society then return nil end
    if GetResourceState("Renewed-Banking") ~= "started" then return nil end
    local ok, result = pcall(function()
        return exports["Renewed-Banking"]:getAccountMoney(society)
    end)
    if not ok or result == false or result == nil then return nil end
    return tonumber(result) or 0
end

function PLTLibServer.RenewedSyncDeptBalance(society, newBalance)
    if not society then return end
    if GetResourceState("Renewed-Banking") ~= "started" then return end
    local current = PLTLibServer.RenewedGetDeptBalance(society)
    local target  = tonumber(newBalance) or 0
    local delta   = target - (current or 0)
    if current == nil then
        pcall(function() exports["Renewed-Banking"]:addAccountMoney(society, target) end)
    elseif delta > 0 then
        pcall(function() exports["Renewed-Banking"]:addAccountMoney(society, delta) end)
    elseif delta < 0 then
        pcall(function() exports["Renewed-Banking"]:removeAccountMoney(society, math.abs(delta)) end)
    end
end

function PLTLibServer.SQLInit()
    local statements = {
        [[CREATE TABLE IF NOT EXISTS `plt_departments_data` (
            `key` VARCHAR(50) NOT NULL PRIMARY KEY,
            `value` LONGTEXT NOT NULL
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_members` (
            `cid` VARCHAR(50) NOT NULL PRIMARY KEY,
            `name` VARCHAR(100) DEFAULT NULL,
            `dept` VARCHAR(50) DEFAULT 'none',
            `grade` INT DEFAULT 0,
            `onDuty` TINYINT(1) DEFAULT 0,
            `lastClockOn` BIGINT DEFAULT 0,
            `totalTime` INT DEFAULT 0,
            `medals` LONGTEXT,
            `divisions` LONGTEXT,
            `ratings` LONGTEXT,
            INDEX (`dept`),
            INDEX (`onDuty`)
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_warrants` (
            `id` BIGINT NOT NULL PRIMARY KEY,
            `subject` VARCHAR(100) NOT NULL,
            `charges` TEXT DEFAULT NULL,
            `priority` VARCHAR(20) DEFAULT 'Standard',
            `issuedBy` VARCHAR(100) DEFAULT NULL,
            `issuedDate` VARCHAR(50) DEFAULT NULL,
            `description` TEXT DEFAULT NULL,
            `status` VARCHAR(20) DEFAULT 'Active',
            INDEX (`subject`)
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_bolos` (
            `id` BIGINT NOT NULL PRIMARY KEY,
            `type` VARCHAR(50) DEFAULT 'Vehicle',
            `title` VARCHAR(100) NOT NULL,
            `description` TEXT DEFAULT NULL,
            `plate` VARCHAR(20) DEFAULT NULL,
            `owner` VARCHAR(100) DEFAULT NULL,
            `lastSeen` VARCHAR(255) DEFAULT NULL,
            `issuedBy` VARCHAR(100) DEFAULT NULL,
            `issuedDate` VARCHAR(50) DEFAULT NULL,
            `status` VARCHAR(20) DEFAULT 'Active',
            INDEX (`plate`),
            INDEX (`title`)
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_cases` (
            `id` BIGINT NOT NULL PRIMARY KEY,
            `title` VARCHAR(255) NOT NULL,
            `description` TEXT DEFAULT NULL,
            `summary` TEXT DEFAULT NULL,
            `status` VARCHAR(50) DEFAULT 'Open',
            `issuedBy` VARCHAR(100) DEFAULT NULL,
            `issuedDate` VARCHAR(50) DEFAULT NULL,
            `officers` TEXT DEFAULT NULL,
            INDEX (`title`)
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_duty_logs` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `cid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) DEFAULT NULL,
            `officer` VARCHAR(100) DEFAULT NULL,
            `dept` VARCHAR(50) DEFAULT NULL,
            `action` VARCHAR(50) DEFAULT NULL,
            `time` VARCHAR(50) DEFAULT NULL,
            `date` VARCHAR(50) DEFAULT NULL,
            INDEX (`cid`),
            INDEX (`dept`)
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_transactions` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `deptId` VARCHAR(50) NOT NULL,
            `type` VARCHAR(50) NOT NULL,
            `amount` INT NOT NULL,
            `from_cid` VARCHAR(50) DEFAULT NULL,
            `from_name` VARCHAR(100) DEFAULT NULL,
            `to_cid` VARCHAR(50) DEFAULT NULL,
            `to_name` VARCHAR(100) DEFAULT NULL,
            `reason` TEXT DEFAULT NULL,
            `timestamp` BIGINT DEFAULT 0,
            INDEX (`deptId`)
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_seizures` (
            `plate` VARCHAR(20) NOT NULL PRIMARY KEY,
            `data` LONGTEXT NOT NULL
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_radars` (
            `id` VARCHAR(100) NOT NULL PRIMARY KEY,
            `data` LONGTEXT NOT NULL
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_cameras` (
            `id` BIGINT NOT NULL PRIMARY KEY,
            `deptId` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `coords` TEXT NOT NULL,
            `heading` FLOAT DEFAULT 0.0,
            INDEX (`deptId`)
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_trackers` (
            `plate` VARCHAR(20) NOT NULL PRIMARY KEY,
            `deptId` VARCHAR(50) NOT NULL,
            `model` VARCHAR(50) DEFAULT NULL,
            `placedBy` VARCHAR(100) DEFAULT NULL,
            `timestamp` BIGINT DEFAULT 0,
            INDEX (`deptId`)
        );]],
        [[CREATE TABLE IF NOT EXISTS `plt_departments_comms` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `fromDept` VARCHAR(50) NOT NULL,
            `toDept` VARCHAR(50) NOT NULL,
            `senderName` VARCHAR(100) DEFAULT NULL,
            `message` TEXT DEFAULT NULL,
            `timestamp` BIGINT DEFAULT 0,
            INDEX (`fromDept`),
            INDEX (`toDept`)
        );]],
    }

    for _, sql in ipairs(statements) do
        local ok, err = pcall(function() MySQL.Sync.execute(sql, {}) end)
        if not ok then
            print("^1[plt_departments] ERROR: Failed to execute SQL query!^7")
            print("^1Query: " .. tostring(sql) .. "^7")
            print("^1Error: " .. tostring(err) .. "^7")
        end
    end
end

function PLTLibServer.SQLSaveDataBlob(key, value)
    MySQL.Async.execute(
        "INSERT INTO plt_departments_data (`key`, `value`) VALUES (@key, @value) ON DUPLICATE KEY UPDATE `value` = @value",
        { ["@key"] = key, ["@value"] = json.encode(value) })
end

function PLTLibServer.SQLSaveSeizures(seizures)
    for plate, data in pairs(seizures or {}) do
        MySQL.Async.execute(
            "INSERT INTO plt_departments_seizures (plate, data) VALUES (@plate, @data) ON DUPLICATE KEY UPDATE data = @data",
            { ["@plate"] = plate, ["@data"] = json.encode(data) })
    end
end

function PLTLibServer.SQLSaveMember(cid, memberData)
    if not memberData then
        MySQL.Async.execute("DELETE FROM plt_departments_members WHERE cid = ?", { cid })
        return
    end
    MySQL.Async.execute(
        "INSERT INTO plt_departments_members "
        .. "(cid, name, dept, grade, onDuty, medals, divisions, ratings) VALUES (?, ?, ?, ?, ?, ?, ?, ?) "
        .. "ON DUPLICATE KEY UPDATE name=VALUES(name), dept=VALUES(dept), grade=VALUES(grade), "
        .. "onDuty=VALUES(onDuty), medals=VALUES(medals), divisions=VALUES(divisions), ratings=VALUES(ratings)",
        {
            cid,
            memberData.name      or "Unknown",
            memberData.dept      or "none",
            memberData.grade     or 0,
            memberData.onDuty    and 1 or 0,
            json.encode(memberData.medals    or {}),
            json.encode(memberData.divisions or {}),
            json.encode(memberData.ratings   or {}),
        })
end

function PLTLibServer.SQLSaveCamera(camera)
    MySQL.Async.execute(
        "INSERT INTO plt_departments_cameras (id, deptId, name, coords, heading) VALUES (?, ?, ?, ?, ?) "
        .. "ON DUPLICATE KEY UPDATE name=VALUES(name), coords=VALUES(coords), heading=VALUES(heading)",
        { camera.id, camera.deptId, camera.name, json.encode(camera.coords), camera.heading or 0.0 })
end

function PLTLibServer.SQLDeleteCamera(cameraId)
    MySQL.Async.execute("DELETE FROM plt_departments_cameras WHERE id = ?", { cameraId })
end

function PLTLibServer.SQLSaveWarrant(warrant)
    MySQL.Async.execute(
        "INSERT INTO plt_departments_warrants "
        .. "(id, subject, charges, priority, issuedBy, issuedDate, description, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?) "
        .. "ON DUPLICATE KEY UPDATE subject=VALUES(subject), charges=VALUES(charges), priority=VALUES(priority), "
        .. "issuedBy=VALUES(issuedBy), issuedDate=VALUES(issuedDate), description=VALUES(description), status=VALUES(status)",
        {
            warrant.id,
            warrant.subject,
            warrant.charges,
            warrant.priority    or "Standard",
            warrant.issuedBy    or "System",
            warrant.issuedDate  or os.date("%Y-%m-%d %H:%M"),
            warrant.description or "",
            warrant.status      or "Active",
        })
end

function PLTLibServer.SQLDeleteWarrant(warrantId)
    MySQL.Async.execute("DELETE FROM plt_departments_warrants WHERE id = ?", { warrantId })
end

function PLTLibServer.SQLSaveCaseFile(caseFile)
    MySQL.Async.execute(
        "INSERT INTO plt_departments_cases "
        .. "(id, title, description, summary, status, issuedBy, issuedDate, officers) VALUES (?, ?, ?, ?, ?, ?, ?, ?) "
        .. "ON DUPLICATE KEY UPDATE title=VALUES(title), description=VALUES(description), summary=VALUES(summary), "
        .. "status=VALUES(status), issuedBy=VALUES(issuedBy), issuedDate=VALUES(issuedDate), officers=VALUES(officers)",
        {
            caseFile.id,
            caseFile.title,
            caseFile.description or "",
            caseFile.summary     or "",
            caseFile.status      or "Open",
            caseFile.issuedBy    or "System",
            caseFile.issuedDate  or os.date("%Y-%m-%d %H:%M"),
            json.encode(caseFile.officers or {}),
        })
end

function PLTLibServer.SQLDeleteCaseFile(caseId)
    MySQL.Async.execute("DELETE FROM plt_departments_cases WHERE id = ?", { caseId })
end

function PLTLibServer.SQLSaveBolo(bolo)
    MySQL.Async.execute(
        "INSERT INTO plt_departments_bolos "
        .. "(id, type, title, description, plate, owner, lastSeen, issuedBy, issuedDate, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
        .. "ON DUPLICATE KEY UPDATE type=VALUES(type), title=VALUES(title), description=VALUES(description), "
        .. "plate=VALUES(plate), owner=VALUES(owner), lastSeen=VALUES(lastSeen), issuedBy=VALUES(issuedBy), "
        .. "issuedDate=VALUES(issuedDate), status=VALUES(status)",
        {
            bolo.id,
            bolo.type        or "Vehicle",
            bolo.title,
            bolo.description,
            bolo.plate       or "",
            bolo.owner       or "",
            bolo.lastSeen    or "",
            bolo.issuedBy    or "System",
            bolo.issuedDate  or os.date("%Y-%m-%d %H:%M"),
            bolo.status      or "Active",
        })
end

function PLTLibServer.SQLDeleteBolo(boloId)
    MySQL.Async.execute("DELETE FROM plt_departments_bolos WHERE id = ?", { boloId })
end

function PLTLibServer.SQLSaveDutyLogs(dutyLogsByDept)
    MySQL.Async.execute("DELETE FROM plt_departments_duty_logs", {}, function()
        for deptId, logs in pairs(dutyLogsByDept or {}) do
            for _, entry in ipairs(logs) do
                MySQL.Async.execute(
                    "INSERT INTO plt_departments_duty_logs (cid, name, officer, dept, action, time, date) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    {
                        entry.cid     or "Unknown",
                        entry.name    or "Unknown",
                        entry.officer or entry.name or "Unknown",
                        entry.dept    or deptId,
                        entry.action  or "Unknown",
                        entry.time    or os.date("%I:%M %p"),
                        entry.date    or os.date("%Y-%m-%d"),
                    })
            end
        end
    end)
end

function PLTLibServer.SQLInsertFinanceTransaction(deptId, txType, amount, fromPlayer, toPlayer, reason, timestamp)
    MySQL.Async.execute(
        "INSERT INTO plt_departments_transactions "
        .. "(deptId, type, amount, from_cid, from_name, to_cid, to_name, reason, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        { deptId, txType, amount, fromPlayer.cid, fromPlayer.name, toPlayer.cid, toPlayer.name, reason, timestamp })
end

function PLTLibServer.SQLAdjustOfflineBank(frameworkType, identifier, amount)
    local delta = tonumber(amount) or 0
    if delta == 0 then return end
    if frameworkType == "qb" then
        MySQL.update(
            "UPDATE players SET money = JSON_SET(money, \"$.bank\", JSON_EXTRACT(money, \"$.bank\") + ?) WHERE citizenid = ?",
            { delta, identifier })
    else
        MySQL.update(
            "UPDATE users SET accounts = JSON_SET(accounts, \"$.bank\", JSON_EXTRACT(accounts, \"$.bank\") + ?) WHERE identifier = ?",
            { delta, identifier })
    end
end

function PLTLibServer.SQLUpdateOfflineJob(frameworkType, identifier, jobName, gradeLevel)
    if not identifier or not jobName then return end
    if frameworkType == "qb" then
        MySQL.update(
            "UPDATE players SET job = JSON_SET(job, \"$.name\", ?), job = JSON_SET(job, \"$.grade.level\", ?) WHERE citizenid = ?",
            { jobName, gradeLevel, identifier })
    elseif frameworkType == "esx" then
        MySQL.update(
            "UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?",
            { jobName, gradeLevel, identifier })
    end
end

function PLTLibServer.SQLUpdateRankSalary(frameworkType, jobName, gradeLevel, salary)
    if not jobName then return end
    if frameworkType == "esx" then
        MySQL.update(
            "UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?",
            { tonumber(salary) or 0, jobName, tonumber(gradeLevel) or 0 })
    end
end

function PLTLibServer.SQLRefreshMDT(callback)
    if not (Config.MDT and Config.MDT.enabled) then
        if callback then callback() end
        return
    end

    local mdtType = Config.MDT.type

    if mdtType == "ps-mdt" or mdtType == "qb-mdt" then
        MySQL.Async.fetchAll("SELECT * FROM mdt_bolos", {}, function(rows)
            if rows then
                local out = {}
                for _, r in ipairs(rows) do
                    table.insert(out, {
                        id          = r.id,
                        type        = r.type        or "Vehicle",
                        title       = r.title       or "Unknown BOLO",
                        description = r.description or r.details or "",
                        plate       = r.plate       or "",
                        owner       = r.owner       or "",
                        lastSeen    = r.lastseen    or "",
                        issuedBy    = r.author      or "System",
                        issuedDate  = r.date        or os.date("%Y-%m-%d %H:%M"),
                        status      = "Active",
                    })
                end
                Bolos = out
            end
            MySQL.Async.fetchAll("SELECT * FROM mdt_warrants", {}, function(wRows)
                if wRows then
                    local out = {}
                    for _, r in ipairs(wRows) do
                        table.insert(out, {
                            id          = r.id,
                            subject     = r.title  or r.name or "Unknown",
                            charges     = r.charges or "See Details",
                            priority    = "Standard",
                            issuedBy    = r.author  or "System",
                            issuedDate  = r.date    or os.date("%Y-%m-%d %H:%M"),
                            description = "",
                            status      = "Active",
                        })
                    end
                    Warrants = out
                end
                if callback then callback() end
            end)
        end)
        return
    end

    local mdtCfg = Config.MDT
    if mdtCfg and mdtCfg.bolos and mdtCfg.bolos.table then
        MySQL.Async.fetchAll("SELECT * FROM " .. mdtCfg.bolos.table, {}, function(rows)
            if rows then
                local cols = mdtCfg.bolos.columns
                local out  = {}
                for _, r in ipairs(rows) do
                    table.insert(out, {
                        id          = r[cols.id],
                        type        = r[cols.type]        or "Vehicle",
                        title       = r[cols.title]       or "Unknown BOLO",
                        description = r[cols.description] or "",
                        plate       = r[cols.plate]       or "",
                        owner       = r[cols.owner]       or "",
                        lastSeen    = r[cols.lastSeen]    or "",
                        issuedBy    = r[cols.issuedBy]    or "System",
                        issuedDate  = r[cols.issuedDate]  or os.date("%Y-%m-%d %H:%M"),
                        status      = "Active",
                    })
                end
                Bolos = out
            end
            if mdtCfg.warrants and mdtCfg.warrants.table then
                MySQL.Async.fetchAll("SELECT * FROM " .. mdtCfg.warrants.table, {}, function(wRows)
                    if wRows then
                        local cols = mdtCfg.warrants.columns
                        local out  = {}
                        for _, r in ipairs(wRows) do
                            table.insert(out, {
                                id          = r[cols.id],
                                subject     = r[cols.subject]     or r[cols.name] or "Unknown",
                                charges     = r[cols.charges]     or "See Details",
                                priority    = "Standard",
                                issuedBy    = r[cols.issuedBy]    or "System",
                                issuedDate  = r[cols.issuedDate]  or os.date("%Y-%m-%d %H:%M"),
                                description = r[cols.description] or "",
                                status      = "Active",
                            })
                        end
                        Warrants = out
                    end
                    if callback then callback() end
                end)
            else
                if callback then callback() end
            end
        end)
    elseif callback then
        callback()
    end
end

function PLTLibServer.GetFrameworkJobRanks(source, callback, jobName)
    local fwType = (Framework and Framework.Type) or "auto"
    local job    = tostring(jobName or "police"):lower()
    local ranks  = {}

    if fwType == "esx" then
        local rows = MySQL.Sync.fetchAll(
            "SELECT grade, label, salary FROM job_grades WHERE LOWER(job_name) = LOWER(?) ORDER BY grade ASC", { job })
        for _, row in ipairs(rows or {}) do
            local level = tonumber(row.grade) or 0
            local name  = (row.label and tostring(row.label) ~= "") and row.label or ("Grade " .. level)
            table.insert(ranks, { level = level, name = name, pay = tonumber(row.salary) or 0 })
        end
    else
        
        local jobsTable = nil
        if Framework and Framework.Core and Framework.Core.Shared and Framework.Core.Shared.Jobs then
            jobsTable = Framework.Core.Shared.Jobs
        end
        if not jobsTable and GetResourceState("qbx_core") == "started" then
            pcall(function() jobsTable = exports.qbx_core:GetJobs() end)
        end
        if not jobsTable and GetResourceState("qb-core") == "started" then
            pcall(function()
                local core = exports["qb-core"]:GetCoreObject()
                if core and core.Shared and core.Shared.Jobs then jobsTable = core.Shared.Jobs end
            end)
        end

        local jobEntry = nil
        if type(jobsTable) == "table" then
            jobEntry = jobsTable[job] or jobsTable[job:upper()] or jobsTable[job:lower()]
        end

        local grades = jobEntry and jobEntry.grades
        if grades and type(grades) == "table" then
            for k, grade in pairs(grades) do
                local level = tonumber((grade and grade.level) or k) or 0
                local name  = (grade and (grade.name or grade.label)) or ("Grade " .. level)
                local pay   = tonumber(grade and (grade.payment or grade.salary)) or 0
                table.insert(ranks, { level = level, name = name, pay = pay })
            end
        end
    end

    table.sort(ranks, function(a, b)
        return (tonumber(a.level) or 0) < (tonumber(b.level) or 0)
    end)
    callback({ framework = fwType, job = job, ranks = ranks })
end

function PLTLibServer.SyncESXMembersWithRoster()
    if Framework.Type ~= "esx" then return end
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src then
            PLTLibServer.SyncPlayerMemberData(src)
        end
    end
end

function PLTLibServer.StartupLoadThread()
    CreateThread(function()

        local blobs = MySQL.Sync.fetchAll("SELECT * FROM plt_departments_data", {})
        for _, row in ipairs(blobs or {}) do
            local key  = row.key
            local data = json.decode(row.value)

            if key == "members" and data and next(data) then
                for cid, member in pairs(data) do
                    MySQL.Sync.execute(
                        "INSERT IGNORE INTO plt_departments_members "
                        .. "(cid, name, dept, grade, onDuty, medals, divisions, ratings) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        {
                            cid,
                            member.name   or "Unknown",
                            member.dept   or "none",
                            member.grade  or 0,
                            member.onDuty and 1 or 0,
                            json.encode(member.medals    or {}),
                            json.encode(member.divisions or {}),
                            json.encode(member.ratings   or {}),
                        })
                end
                MySQL.Async.execute("UPDATE plt_departments_data SET `value` = \"{}\" WHERE `key` = \"members\"")

            elseif key == "warrants" and data and next(data) then
                for _, warrant in ipairs(data) do
                    MySQL.Sync.execute(
                        "INSERT IGNORE INTO plt_departments_warrants "
                        .. "(id, subject, charges, priority, issuedBy, issuedDate, description, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        {
                            warrant.id or os.time(),
                            warrant.subject, warrant.charges, warrant.priority,
                            warrant.issuedBy, warrant.issuedDate, warrant.description, warrant.status,
                        })
                end
                MySQL.Async.execute("UPDATE plt_departments_data SET `value` = \"[]\" WHERE `key` = \"warrants\"")

            elseif key == "bolos" and data and next(data) then
                for _, bolo in ipairs(data) do
                    MySQL.Sync.execute(
                        "INSERT IGNORE INTO plt_departments_bolos "
                        .. "(id, type, title, description, plate, owner, lastSeen, issuedBy, issuedDate, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        {
                            bolo.id or os.time(), bolo.type, bolo.title, bolo.description,
                            bolo.plate, bolo.owner, bolo.lastSeen, bolo.issuedBy, bolo.issuedDate, bolo.status,
                        })
                end
                MySQL.Async.execute("UPDATE plt_departments_data SET `value` = \"[]\" WHERE `key` = \"bolos\"")

            elseif key == "cases" and data and next(data) then
                for _, case in ipairs(data) do
                    MySQL.Sync.execute(
                        "INSERT IGNORE INTO plt_departments_cases "
                        .. "(id, title, description, summary, status, issuedBy, issuedDate, officers) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        {
                            case.id or os.time(), case.title, case.description, case.summary,
                            case.status, case.issuedBy, case.issuedDate, json.encode(case.officers or {}),
                        })
                end
                MySQL.Async.execute("UPDATE plt_departments_data SET `value` = \"[]\" WHERE `key` = \"cases\"")

            elseif key == "departments"      and data then DepartmentData  = data
            elseif key == "balances"         and data then DeptBalances     = data or DeptBalances
            elseif key == "autopay"          and data then AutoPaySettings  = data or AutoPaySettings
            elseif key == "doors"            and data then DoorStates       = data or DoorStates
            elseif key == "delayed_payments" and data then DelayedPayments  = data or DelayedPayments
            elseif key == "news"             and data then DeptNews         = data or DeptNews
            elseif key == "department_mail"  and data then DepartmentMail   = data or DepartmentMail
            end
        end

        PLTLibServer.SyncESXMembersWithRoster()
        if SyncAllDeptBalancesWithExternal then SyncAllDeptBalancesWithExternal() end

        if not (DepartmentData and DepartmentData.nodes and #DepartmentData.nodes > 0) then
            DepartmentData = { nodes = {}, links = {} }
            local xOffset = 100
            for i, dept in ipairs(Config.DefaultNodes.departments) do
                table.insert(DepartmentData.nodes, {
                    id    = dept.id,
                    label = dept.label,
                    type  = "department",
                    x     = xOffset + (i - 1) * 250,
                    y     = 150,
                })
            end
            for i, perm in ipairs(Config.DefaultNodes.permissions) do
                table.insert(DepartmentData.nodes, {
                    id    = perm.id,
                    label = perm.label,
                    type  = "permission",
                    x     = xOffset + (i - 1) * 200,
                    y     = 400,
                })
            end
            SaveDepartments()
        end

        SaveBalances()

        MemberData = {}
        for _, row in ipairs(MySQL.Sync.fetchAll("SELECT * FROM plt_departments_members", {}) or {}) do
            MemberData[row.cid] = {
                name        = row.name,
                dept        = row.dept,
                grade       = row.grade,
                onDuty      = row.onDuty == 1,
                lastClockOn = row.lastClockOn,
                totalTime   = row.totalTime,
                medals      = json.decode(row.medals    or "[]"),
                divisions   = json.decode(row.divisions or "[]"),
                ratings     = json.decode(row.ratings   or "[]"),
            }
        end

        Warrants = {}
        for _, row in ipairs(MySQL.Sync.fetchAll("SELECT * FROM plt_departments_warrants", {}) or {}) do
            table.insert(Warrants, row)
        end

        Bolos = {}
        for _, row in ipairs(MySQL.Sync.fetchAll("SELECT * FROM plt_departments_bolos", {}) or {}) do
            table.insert(Bolos, row)
        end

        CaseFiles = {}
        for _, row in ipairs(MySQL.Sync.fetchAll("SELECT * FROM plt_departments_cases", {}) or {}) do
            row.officers = json.decode(row.officers or "[]")
            table.insert(CaseFiles, row)
        end

        FinanceTransactions = {}
        for _, row in ipairs(MySQL.Sync.fetchAll("SELECT * FROM plt_departments_transactions ORDER BY id DESC", {}) or {}) do
            if not FinanceTransactions[row.deptId] then
                FinanceTransactions[row.deptId] = {}
            end
            if #FinanceTransactions[row.deptId] < 50 then
                table.insert(FinanceTransactions[row.deptId], 1, {
                    type      = row.type,
                    amount    = row.amount,
                    officer   = { cid = row.from_cid,  name = row.from_name },
                    target    = { cid = row.to_cid,    name = row.to_name   },
                    reason    = row.reason,
                    timestamp = row.timestamp,
                    date      = os.date("%m/%d/%Y %H:%M", row.timestamp),
                })
            end
        end

        for _, row in ipairs(MySQL.Sync.fetchAll("SELECT * FROM plt_departments_duty_logs", {}) or {}) do
            if row.dept then
                if not DutyLogs[row.dept] then DutyLogs[row.dept] = {} end
                table.insert(DutyLogs[row.dept], row)
            end
        end

        for _, row in ipairs(MySQL.Sync.fetchAll("SELECT * FROM plt_departments_seizures", {}) or {}) do
            SeizedVehicles[row.plate] = json.decode(row.data)
        end

        Cameras = {}
        for _, row in ipairs(MySQL.Sync.fetchAll("SELECT * FROM plt_departments_cameras", {}) or {}) do
            row.coords = json.decode(row.coords)
            table.insert(Cameras, row)
        end

        RefreshMDTData()
        RegisterStashes()

        dataLoaded = true
        TriggerEvent("plt_departments:server:Ready", DepartmentData)

        SetTimeout(3000, function()
            if DepartmentData and DepartmentData.nodes and PLTServerNodes and PLTServerNodes.ForEachDepartment then
                PLTServerNodes.ForEachDepartment(DepartmentData, function(dept)
                    UpdateFinanceHistory(dept.id)
                end)
            end
            for _, playerId in ipairs(GetPlayers()) do
                local src = tonumber(playerId)
                SyncPlayerMemberData(src)
                TriggerClientEvent("plt_departments:client:SyncJobs",    src, DepartmentData)
                TriggerClientEvent("plt_departments:client:SyncMembers", src, MemberData)
            end
        end)
    end)
end

local SESSION_CHALLENGE_CLIENT = "plt_departments:c:k"
local SESSION_CHALLENGE_REPLY  = "plt_departments:s:k"
local SESSION_KEEPALIVE        = "plt_departments:s:p"

function PLTServerNodes.GetNodeById(nodeId, deptData)
    if not (deptData and deptData.nodes) then return nil end
    local idStr = SafeToString(nodeId)
    if not idStr then return nil end
    for _, node in ipairs(deptData.nodes) do
        if SafeToString(node.id) == idStr then return node end
    end
    return nil
end

function PLTServerNodes.ResolveDepartment(nodeId, deptData)
    if not (deptData and deptData.links) then return nil end
    local idStr = SafeToString(nodeId)
    if not idStr then return nil end

    local startNode = PLTServerNodes.GetNodeById(nodeId, deptData)
    if startNode and startNode.type == "department" then return startNode.id end

    local visited = { [idStr] = true }
    local queue   = { idStr }

    while #queue > 0 do
        local current = table.remove(queue, 1)
        for _, link in ipairs(deptData.links) do
            local neighbour = nil
            if SafeToString(link.to) == current then
                neighbour = SafeToString(link.from)
            elseif SafeToString(link.from) == current then
                neighbour = SafeToString(link.to)
            end
            if neighbour and not visited[neighbour] then
                local node = PLTServerNodes.GetNodeById(neighbour, deptData)
                if node then
                    if node.type == "department" then return node.id end
                    visited[neighbour] = true
                    table.insert(queue, neighbour)
                end
            end
        end
    end

    return nil
end

function PLTServerNodes.GetLinkedRankNode(nodeId, deptData)
    if not (nodeId and deptData and deptData.links) then return nil end
    local idStr = tostring(nodeId)
    for _, link in ipairs(deptData.links) do
        local neighbour = nil
        if tostring(link.from) == idStr then neighbour = link.to
        elseif tostring(link.to) == idStr then neighbour = link.from end
        if neighbour then
            local node = PLTServerNodes.GetNodeById(neighbour, deptData)
            if node and node.type == "rank" then return node end
        end
    end
    return nil
end

function PLTServerNodes.GetRankLabel(deptId, gradeLevel, deptData, fallback)
    fallback = fallback or "Unknown"
    local rankNode = PLTServerNodes.GetLinkedRankNode(deptId, deptData)
    if not (rankNode and rankNode.ranks) then return fallback end
    for _, rank in ipairs(rankNode.ranks) do
        if tonumber(rank.level) == tonumber(gradeLevel) then
            return rank.name or fallback
        end
    end
    return fallback
end

function PLTServerNodes.GetDepartmentLabel(nodeId, deptData, fallback)
    fallback = fallback or "Unknown"
    if not (nodeId and deptData) then return fallback end
    local node = PLTServerNodes.GetNodeById(nodeId, deptData)
    if node and node.type == "department" then return node.label or fallback end
    return fallback
end

function PLTServerNodes.TranslateToFrameworkJob(nodeId, deptData, lowercase)
    local idStr = tostring(nodeId or "")
    if idStr == "" then return idStr end
    if not (deptData and deptData.nodes) then
        return lowercase and idStr:lower() or idStr
    end
    local idLower = idStr:lower()
    for _, node in ipairs(deptData.nodes) do
        if tostring(node.id):lower() == idLower and node.type == "department" then
            local fj = node.frameworkJob
            if not fj or fj == "" then break end
            return lowercase and tostring(fj):lower() or tostring(fj)
        end
    end
    return lowercase and idStr:lower() or idStr
end

function PLTServerNodes.GetNodeIdFromFrameworkJob(jobName, deptData)
    if not (jobName and deptData and deptData.nodes) then return nil end
    local jobLower = tostring(jobName):lower()
    for _, node in ipairs(deptData.nodes) do
        if node.type == "department" and node.frameworkJob then
            if tostring(node.frameworkJob):lower() == jobLower then return node.id end
        end
    end
    for _, node in ipairs(deptData.nodes) do
        if node.type == "department" then
            if tostring(node.id):lower() == jobLower then return node.id end
        end
    end
    return nil
end

function PLTServerNodes.IsDepartmentJob(jobName, deptData)
    if not (jobName and deptData and deptData.nodes) then return false end
    local jobLower = tostring(jobName):lower()
    for _, node in ipairs(deptData.nodes) do
        if node.type == "department" then
            local fjLower = node.frameworkJob and tostring(node.frameworkJob):lower()
            local idLower = tostring(node.id):lower()
            if fjLower == jobLower or idLower == jobLower then return true end
        end
    end
    return false
end

function PLTServerNodes.ForEachDepartment(deptData, callback)
    if not (deptData and deptData.nodes and type(callback) == "function") then return end
    for _, node in ipairs(deptData.nodes) do
        if node.type == "department" and node.id then callback(node) end
    end
end

function PLTServerNodes.DepartmentHasNodeType(deptId, nodeType, deptData)
    if not (deptId and deptId ~= "none" and nodeType and deptData and deptData.nodes) then
        return false
    end
    for _, node in ipairs(deptData.nodes) do
        if node.type == nodeType then
            local resolved = PLTServerNodes.ResolveDepartment(node.id, deptData)
            if tostring(resolved) == tostring(deptId) then return true end
        end
    end
    return false
end

function PLTServerNodes.GetLinkedDepartmentIdsForNode(nodeId, deptData)
    local result = {}
    if not (nodeId and deptData and deptData.links) then return result end
    local idStr = tostring(nodeId)
    for _, link in ipairs(deptData.links) do
        local neighbour = nil
        if tostring(link.from) == idStr then neighbour = link.to
        elseif tostring(link.to) == idStr then neighbour = link.from end
        if neighbour then
            local node = PLTServerNodes.GetNodeById(neighbour, deptData)
            if node and node.type == "department" and node.id then
                table.insert(result, node.id)
            end
        end
    end
    return result
end

function PLTServerNodes.IsWeaponAllowedForDept(deptId, weaponModel, gradeLevel, deptData)
    if not (deptId and deptData and deptData.nodes) then return false end
    local grade = tonumber(gradeLevel) or 0
    for _, node in ipairs(deptData.nodes) do
        if node.type == "armory" then
            local resolved = PLTServerNodes.ResolveDepartment(node.id, deptData)
            if tostring(resolved) == tostring(deptId) and node.weapons then
                for _, weapon in ipairs(node.weapons) do
                    if tostring(weapon.model) == tostring(weaponModel) then
                        if grade >= (tonumber(weapon.minGrade) or 0) then return true end
                    end
                end
            end
        end
    end
    return false
end

function PLTServerNodes.GetLocationStashNodes(deptData)
    local result = {}
    if not (deptData and deptData.nodes) then return result end
    for _, node in ipairs(deptData.nodes) do
        if node.type == "location" and node.coordsList and node.coordsList.stash then
            table.insert(result, node)
        end
    end
    return result
end

function PLTServerNodes.GetDepartmentBlipColorMap(deptData)
    local colorMap = {}
    PLTServerNodes.ForEachDepartment(deptData, function(dept)
        colorMap[tostring(dept.id)] = tonumber(dept.officerBlipColor) or 1
    end)
    return colorMap
end

function PLTServerNodes.GetMemberJob(source, memberData)
    local player = Framework.GetPlayer(source)
    if not player then return nil end
    return memberData and memberData[player.citizenid]
end

function PLTServerNodes.GetMemberRankLabel(memberRecord, deptData, fallback)
    fallback = fallback or "Officer"
    if not (memberRecord and memberRecord.dept ~= "none") then return fallback end
    return PLTServerNodes.GetRankLabel(memberRecord.dept, memberRecord.grade, deptData, fallback)
end

function PLTServerNodes.GetMemberDeptSnapshot(memberRecord, deptData)
    if not (memberRecord and memberRecord.dept ~= "none") then
        return { deptId = "none", deptLabel = "Unemployed", rankLabel = "None", grade = 0 }
    end
    local deptId = tostring(memberRecord.dept)
    local grade  = tonumber(memberRecord.grade) or 0
    return {
        deptId    = deptId,
        deptLabel = PLTServerNodes.GetDepartmentLabel(deptId, deptData, "Unknown"),
        rankLabel = PLTServerNodes.GetRankLabel(deptId, grade, deptData, "Unknown"),
        grade     = grade,
    }
end

function PLTServerNodes.HasBossMenuAccess(source, deptData, memberData)
    local memberJob = PLTServerNodes.GetMemberJob(source, memberData)
    if not (memberJob and memberJob.dept and memberJob.dept ~= "none") then return false end
    local rankNode = PLTServerNodes.GetLinkedRankNode(memberJob.dept, deptData)
    if not (rankNode and rankNode.ranks) then return false end
    local grade = tonumber(memberJob.grade) or 0
    for _, rank in ipairs(rankNode.ranks) do
        if tonumber(rank.level) == grade then
            return rank.bossMenu == true or rank.bossMenu == 1
        end
    end
    return false
end

function PLTServerNodes.UpdateRankPayByLevel(nodeId, gradeLevel, newPay, deptData)
    if not nodeId then return false end
    local rankNode = PLTServerNodes.GetNodeById(nodeId, deptData)
    if not (rankNode and rankNode.type == "rank" and rankNode.ranks) then return false end
    for _, rank in ipairs(rankNode.ranks) do
        if tonumber(rank.level) == tonumber(gradeLevel) then
            rank.pay = newPay
            return true
        end
    end
    return false
end

function PLTServerNodes.ValidateArmoryTakeRequest(source, itemModel, itemType, nodeId, quantity, deptData, memberData)
    if not (source and itemModel and nodeId) then return false, "must_be_in_dept_armory", nil end

    quantity = tonumber(quantity) or 1
    if quantity < 1 or quantity > 1000 then return false, "armory_limit_reached", nil end

    local memberJob = PLTServerNodes.GetMemberJob(source, memberData)
    if not (memberJob and memberJob.dept ~= "none") then return false, "must_be_in_dept_armory", nil end

    local armoryNode = PLTServerNodes.GetNodeById(nodeId, deptData)
    if not (armoryNode and armoryNode.type == "armory") then return false, "must_be_in_dept_armory", nil end

    local armoryDept = PLTServerNodes.ResolveDepartment(armoryNode.id, deptData)
    local memberDept = memberJob.dept
    if PLTServerNodes.GetNodeIdFromFrameworkJob then
        memberDept = PLTServerNodes.GetNodeIdFromFrameworkJob(memberDept, deptData) or memberDept
    end
    if tostring(armoryDept):lower() ~= tostring(memberDept):lower() then
        return false, "must_be_in_dept_armory", nil
    end

    local list = (itemType == "weapon") and armoryNode.weapons or armoryNode.items
    if not list then return false, "not_allowed_weapon", nil end

    local entry = nil
    for _, item in ipairs(list) do
        if tostring(item.model) == tostring(itemModel) then entry = item break end
    end
    if not entry then return false, "not_allowed_weapon", nil end

    if (tonumber(entry.minGrade) or 0) > (tonumber(memberJob.grade) or 0) then
        return false, "not_allowed_weapon", nil
    end

    local limit = tonumber(entry.limit) or 0
    if limit > 0 and quantity > limit then return false, "armory_limit_reached", nil end

    armoryNode._stock = armoryNode._stock or {}
    local key     = tostring(itemModel)
    local used    = tonumber(armoryNode._stock[key]) or 0
    local newUsed = used + quantity
    if limit > 0 and newUsed > limit then return false, "armory_limit_reached", nil end
    armoryNode._stock[key] = newUsed

    return true, nil, {
        nodeId    = armoryNode.id,
        itemLabel = entry.label or itemModel,
        quantity  = quantity,
    }
end

function PLTServerNodes.ReleaseArmoryStock(nodeId, itemModel, quantity)
    local armoryNode = DepartmentData and PLTServerNodes.GetNodeById(nodeId, DepartmentData)
    if not (armoryNode and armoryNode._stock) then return end
    local key = tostring(itemModel)
    armoryNode._stock[key] = math.max(0, (tonumber(armoryNode._stock[key]) or 0) - quantity)
end

function PLTServerNodes.BuildDispatchCallForSource(source, callData, memberData, deptData)
    if not source or source <= 0 or type(callData) ~= "table" then return nil, "no_permission" end

    local memberJob = PLTServerNodes.GetMemberJob(source, memberData)
    local isOfficer = memberJob and memberJob.dept and memberJob.dept ~= "none"

    local function clamp(str, max) return str and #str <= max and str or nil end
    local code     = clamp(callData.code,     12)
    local title    = clamp(callData.title,    64)
    local info     = clamp(callData.info,    220)
    local location = clamp(callData.location, 96)

    local coords = callData.coords
    local ped    = GetPlayerPed(source)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        coords  = vector3(c.x, c.y, c.z)
    end
    if not coords then return nil, "no_permission" end

    local callerName = "ID " .. tostring(source)
    if memberData then
        local playerData = Framework.GetPlayer(source)
        if playerData and playerData.name then callerName = playerData.name end
    end

    local result = {
        code     = (code and code ~= "")         and code     or (isOfficer and "10-00" or "911"),
        title    = (title and title ~= "")       and title    or (isOfficer and "Dispatch Call" or T("911_call_title")),
        location = (location and location ~= "") and location or "Unknown",
        info     = (info and info ~= "")         and info     or "No details provided.",
        coords   = coords,
        caller   = callerName,
    }
    if not isOfficer then
        result.code  = "911"
        result.title = T("911_call_title")
    end
    return result, nil
end

function GetDepartmentForNode(nodeId, deptData)
    return PLTServerNodes.ResolveDepartment(nodeId, deptData)
end

function DoesDeptHaveEvidenceNode(deptId)
    return PLTServerNodes.DepartmentHasNodeType(deptId, "evidence", DepartmentData)
end

function IsDepartmentJob(jobName)
    return PLTServerNodes.IsDepartmentJob(jobName, DepartmentData)
end

function HasBossMenuAccess(source)
    return PLTServerNodes.HasBossMenuAccess(source, DepartmentData, MemberData)
end

function GetNodeIdFromFrameworkJob(jobName)
    return PLTServerNodes.GetNodeIdFromFrameworkJob(jobName, DepartmentData)
end

function GetFrameworkJobFromNodeId(nodeId)
    return PLTServerNodes.TranslateToFrameworkJob(nodeId, DepartmentData, false)
end

function PLTLibServer.IsActionAuthorized(source, action, payload)
    local session = sessionStore.sessions[source]
    if not (session and session.verified) then return false end
    if os.time() - (session.lastSeen or 0) > 180 then return false end   

    local player = Framework.GetPlayer(source)
    if not (player and player.citizenid) then return false end

    if not session.cid then session.cid = player.citizenid end
    if session.cid ~= player.citizenid then return false end

    if not ValidateActionPayload(action, payload) then return false end

    local now     = GetGameTimer()
    local cd      = actionCooldowns[tostring(action or "unknown")] or 0
    session.lastActionAt = session.lastActionAt or {}
    local lastAt  = session.lastActionAt[action] or 0
    if cd > 0 and now - lastAt < cd then return false end
    session.lastActionAt[action] = now

    local memberRecord = MemberData and MemberData[session.cid]
    if not (memberRecord and memberRecord.dept ~= "none") then
        local mj = PLTServerNodes.GetMemberJob(source, MemberData)
        if mj and mj.dept and mj.dept ~= "none" then memberRecord = mj end
    end

    local requiresDept = action == "armory_take" or action == "seize_vehicle" or action == "unimpound_vehicle"
    if requiresDept and not (memberRecord and memberRecord.dept ~= "none") then return false end

    local requiresBoss = (
        action == "hire_member"    or action == "manage_member"   or action == "boss_finance"   or
        action == "rank_salary"    or action == "division_manage" or action == "division_toggle" or
        action == "officer_report" or action == "get_players"
    )
    if requiresBoss and not (IsPlayerAuthorized(source) or HasBossMenuAccess(source)) then
        return false
    end

    local roll = session.roll or ((session.nonce or 0) * 37 % 100003)
    roll = (roll + HashString(tostring(action))) % 100003
    roll = (roll + TableByteSize(payload or {}))  % 100003
    roll = (roll + (tonumber(memberRecord and memberRecord.grade) or 0)) % 100003
    roll = (roll + #tostring(memberRecord and memberRecord.dept or "none")) % 100003
    session.roll = (roll * 17 + 29) % 100003

    return true
end

local syncInProgress = {}

function PLTLibServer.SyncPlayerMemberData(source)
    if not dataLoaded then return end
    if syncInProgress[source] then return end
    syncInProgress[source] = true

    local player = Framework.GetPlayer(source)
    if not player then syncInProgress[source] = nil return end

    local cid      = player.citizenid
    local jobName  = (player.job and player.job.name) and tostring(player.job.name):lower() or ""
    local jobGrade = (player.job and tonumber(player.job.grade)) or 0
    local member   = MemberData and MemberData[cid]

    if member and member.dept ~= "none" then
        local nodeId  = (jobName ~= "") and GetNodeIdFromFrameworkJob(jobName) or nil
        local deptJob = tostring(GetFrameworkJobFromNodeId(member.dept) or ""):lower()

        if jobName ~= "" and not IsDepartmentJob(jobName) then
            MemberData[cid] = nil
            SaveMember(cid)
            SaveMembers()
            syncInProgress[source] = nil
            return
        end

        if nodeId and tostring(nodeId) ~= tostring(member.dept) then
            member.dept   = nodeId
            member.grade  = jobGrade
            member.onDuty = (player.job and player.job.onduty) == true
            SaveMember(cid)
            SaveMembers()
            syncInProgress[source] = nil
            return
        end

        local deptHasFWJob = false
        if DepartmentData and DepartmentData.nodes then
            for _, node in ipairs(DepartmentData.nodes) do
                if tostring(node.id) == tostring(member.dept) and node.type == "department" then
                    deptHasFWJob = (node.frameworkJob and node.frameworkJob ~= "")
                    break
                end
            end
        end

        if deptHasFWJob and jobName == deptJob then
            if jobGrade ~= (tonumber(member.grade) or 0) then
                if player.functions and player.functions.SetJob then
                    player.functions.SetJob(deptJob, member.grade)
                end
            end
            local fwOnDuty = (player.job and player.job.onduty) == true
            if fwOnDuty ~= member.onDuty then
                if player.functions and player.functions.SetDuty then
                    player.functions.SetDuty(member.onDuty)
                end
            end
        end

        syncInProgress[source] = nil
        return
    end

    if jobName ~= "" and IsDepartmentJob(jobName) and not (MemberData and MemberData[cid]) then
        local nodeId = GetNodeIdFromFrameworkJob(jobName)
        if nodeId then
            MemberData[cid] = {
                name        = player.name,
                dept        = nodeId,
                grade       = jobGrade,
                onDuty      = false,
                medals      = {},
                divisions   = {},
                ratings     = {},
                totalTime   = 0,
                lastClockOn = 0,
            }
            SaveMember(cid)
            SaveMembers()
        end
    end

    syncInProgress[source] = nil
end

function PLTLibServer.HandleTakeArmoryItem(source, itemModel, itemType, nodeId, rawQuantity)
    local quantity = tonumber(rawQuantity) or 1

    if not PLTLibServer.IsActionAuthorized(source, "armory_take", {
        itemName = itemModel, itemType = itemType, nodeId = nodeId, quantity = quantity,
    }) then return end

    local ok, errKey, itemInfo = PLTServerNodes.ValidateArmoryTakeRequest(
        source, itemModel, itemType, nodeId, quantity, DepartmentData, MemberData)

    if not ok then
        Framework.Notify(source, T(errKey), "error")
        return
    end

    local gave = Inventory.AddItem(source, itemModel, quantity)
    if gave then
        local label = (itemType == "weapon") and itemModel:gsub("weapon_", ""):upper() or itemModel
        local msg   = T("took_item", { label = label })
        if quantity > 1 then msg = msg .. " x" .. tostring(quantity) end
        Framework.Notify(source, msg, "success")
    else
        PLTServerNodes.ReleaseArmoryStock((itemInfo and itemInfo.nodeId) or nodeId, itemModel, quantity)
        Framework.Notify(source, T("could_not_give_item"), "error")
    end
end

function PLTLibServer.HandleDutyToggle(source)
    if not PLTLibServer.IsActionAuthorized(source, "duty_toggle", {}) then return end

    local player = Framework.GetPlayer(source)
    if not player then return end

    local cid    = player.citizenid
    local member = MemberData and MemberData[cid]
    if not member then return end

    member.onDuty = not member.onDuty

    if member.onDuty then
        member.lastClockOn = os.time()
    else
        if member.lastClockOn and member.lastClockOn > 0 then
            member.totalTime   = (member.totalTime or 0) + (os.time() - member.lastClockOn)
            member.lastClockOn = 0
        end
    end

    SaveMember(cid)
    SaveMembers()

    if player.functions and player.functions.SetDuty then
        player.functions.SetDuty(member.onDuty)
    end

    TriggerClientEvent("plt_departments:client:SyncMembers", -1, MemberData)

    Framework.Notify(source,
        T(member.onDuty and "now_on_duty" or "now_off_duty"),
        member.onDuty and "success" or "error")
end

function PLTLibServer.GetVehicleInfo(source, callback, rawPlate)
    if not PLTLibServer.IsActionAuthorized(source, "get_vehicle_info", { plate = rawPlate }) then
        callback(nil) return
    end
    if not rawPlate then callback(nil) return end

    local plate                          = tostring(rawPlate):gsub("%s+", ""):upper()
    local vehTable, playerTable, idCol   = GetFrameworkTableNames()

    local rows = MySQL.query.await("SELECT * FROM " .. vehTable .. " WHERE plate = ?", { rawPlate })
    if not (rows and rows[1]) then
        rows = MySQL.query.await(
            "SELECT * FROM " .. vehTable .. " WHERE REPLACE(plate, \" \", \"\") = ?", { plate })
    end
    if not (rows and rows[1]) then callback(nil) return end

    local row     = rows[1]
    local owner   = "Unknown"
    local ownerId = row[idCol]

    if Framework.Type == "qb" then
        local r = MySQL.query.await("SELECT charinfo FROM " .. playerTable .. " WHERE " .. idCol .. " = ?", { ownerId })
        if r and r[1] then
            local ci = json.decode(r[1].charinfo)
            if ci then owner = ci.firstname .. " " .. ci.lastname end
        end
    else
        local r = MySQL.query.await("SELECT firstname, lastname FROM " .. playerTable .. " WHERE " .. idCol .. " = ?", { ownerId })
        if r and r[1] then owner = r[1].firstname .. " " .. r[1].lastname end
    end

    callback({
        owner = owner,
        plate = rawPlate,
        model = row.vehicle or row.model,
        props = json.decode((Framework.Type == "qb") and (row.mods or "{}") or (row.vehicle or "{}")),
    })
end

function PLTLibServer.SeizeVehicle(source, vehNetId, reason, price)
    if not PLTLibServer.IsActionAuthorized(source, "seize_vehicle",
        { vehNetId = vehNetId, reason = reason, price = price }) then return end

    local player = Framework.GetPlayer(source)
    if not player then return end

    local entity = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(entity) then return end

    local plate = ""
    if Framework and type(Framework.GetPlate) == "function" then
        plate = Framework.GetPlate(entity) or ""
    end
    if plate == "" then
        local raw = GetVehicleNumberPlateText(entity)
        if raw then plate = raw:gsub("^%s*(.-)%s*$", "%1") end
    end

    local vehTable = GetFrameworkTableNames()
    SeizedVehicles[plate] = { reason = reason, price = price, deptId = player.job.name, officer = player.name }
    SaveSeizures()
    MySQL.update("UPDATE " .. vehTable .. " SET state = 2 WHERE plate = ?", { plate })
    if DoesEntityExist(entity) then DeleteEntity(entity) end
    Framework.Notify(source, T("vehicle_seized", { plate = plate }), "success")
end

function PLTLibServer.CanUnimpound(source, callback, plate)
    if not PLTLibServer.IsActionAuthorized(source, "unimpound_vehicle", { plate = plate }) then
        callback(false) return
    end

    local player   = Framework.GetPlayer(source)
    if not player then callback(false) return end

    local seizure  = SeizedVehicles[plate]
    local vehTable = GetFrameworkTableNames()

    if seizure and (seizure.price or 0) > 0 then
        local removed = player.functions.RemoveMoney("bank", seizure.price, "vehicle-unimpound")
        if removed then
            if seizure.deptId and DeptBalances[seizure.deptId] then
                DeptBalances[seizure.deptId] = DeptBalances[seizure.deptId] + seizure.price
                SaveBalances()
                AddFinanceTransaction(seizure.deptId, "deposit", seizure.price,
                    { name = "System", cid = "SYSTEM" },
                    { name = player.name, cid = player.citizenid },
                    "Impound retrieval fee: " .. plate)
            end
            Framework.Notify(source, T("paid_unimpound", { amount = seizure.price }), "success")
            SeizedVehicles[plate] = nil
            SaveSeizures()
            MySQL.update("UPDATE " .. vehTable .. " SET state = 1 WHERE plate = ?", { plate })
            callback(true)
        else
            Framework.Notify(source, T("not_enough_money_bank"), "error")
            callback(false)
        end
    else
        SeizedVehicles[plate] = nil
        SaveSeizures()
        MySQL.update("UPDATE " .. vehTable .. " SET state = 1 WHERE plate = ?", { plate })
        callback(true)
    end
end

function PLTLibServer.GetImpoundedVehicles(source, callback)
    local vehTable, playerTable, idCol = GetFrameworkTableNames()
    local result = {}

    local rows = MySQL.query.await("SELECT * FROM " .. vehTable .. " WHERE state = 2") or {}
    for _, row in ipairs(rows) do
        local owner = "Unknown"
        if Framework.Type == "qb" then
            local r = MySQL.query.await("SELECT charinfo FROM " .. playerTable .. " WHERE " .. idCol .. " = ?", { row.citizenid })
            if r and r[1] then
                local ci = json.decode(r[1].charinfo)
                if ci then owner = ci.firstname .. " " .. ci.lastname end
            end
        else
            local r = MySQL.query.await("SELECT firstname, lastname FROM " .. playerTable .. " WHERE " .. idCol .. " = ?", { row.identifier })
            if r and r[1] then owner = r[1].firstname .. " " .. r[1].lastname end
        end

        local seizure = SeizedVehicles[row.plate]
        local model   = row.vehicle or row.model or ""
        table.insert(result, {
            plate         = row.plate,
            model         = model,
            label         = model:upper() .. " [" .. row.plate .. "]",
            owner         = owner,
            props         = json.decode((Framework.Type == "qb") and (row.mods or "{}") or (row.vehicle or "{}")),
            isImpounded   = true,
            seizureReason = (seizure and seizure.reason) or "Standard Impound",
            seizurePrice  = (seizure and seizure.price)  or 0,
            deptId        = (seizure and seizure.deptId) or nil,
        })
    end
    callback(result)
end

function PLTLibServer.CheckBolo(source, callback, rawPlate)
    if not rawPlate then callback(false) return end

    if GetResourceState("plt_mdt") == "started" then
        local hasBolo = false
        pcall(function() hasBolo = exports.plt_mdt:HasActiveBolo(rawPlate) end)
        if hasBolo then callback(true) return end
    end

    local cleanPlate = rawPlate:gsub("%s+", ""):upper()
    for _, bolo in ipairs(Bolos or {}) do
        if bolo.plate and bolo.plate:gsub("%s+", ""):upper() == cleanPlate then
            callback(true)
            return
        end
    end
    callback(false)
end

function PLTLibServer.ManageDivision(source, data)
    if not PLTLibServer.IsActionAuthorized(source, "division_manage", data or {}) then return end

    local action = data.action
    local deptId = data.deptId

    if action == "create" then
        local divId = "div_" .. os.time() .. "_" .. math.random(100, 999)
        DepartmentData.divisions = DepartmentData.divisions or {}
        DepartmentData.divisions[deptId] = DepartmentData.divisions[deptId] or {}
        table.insert(DepartmentData.divisions[deptId], { id = divId, name = data.name })
        SaveDepartments()
        Framework.Notify(source, T("division_created", { name = data.name }), "success")

    elseif action == "delete" then
        if DepartmentData.divisions and DepartmentData.divisions[deptId] then
            for i, div in ipairs(DepartmentData.divisions[deptId]) do
                if div.id == data.divId then table.remove(DepartmentData.divisions[deptId], i) break end
            end
            for _, member in pairs(MemberData or {}) do
                if member.divisions then
                    for j, d in ipairs(member.divisions) do
                        if d == data.divId then table.remove(member.divisions, j) break end
                    end
                end
            end
            SaveDepartments()
            SaveMembers()
            Framework.Notify(source, T("division_removed"), "primary")
        end
    end
end

function PLTLibServer.ToggleMemberDivision(source, data)
    if not PLTLibServer.IsActionAuthorized(source, "division_toggle", data or {}) then return end

    local member = MemberData and MemberData[data.cid]
    if not member then return end

    member.divisions = member.divisions or {}
    local removed = false
    for i, d in ipairs(member.divisions) do
        if d == data.divId then table.remove(member.divisions, i) removed = true break end
    end
    if not removed then table.insert(member.divisions, data.divId) end

    SaveMember(data.cid)
    SaveMembers()
    Framework.Notify(source, T(removed and "division_removed_member" or "division_assigned_member"), "success")
end

function PLTLibServer.SubmitOfficerReport(source, data)
    if not PLTLibServer.IsActionAuthorized(source, "officer_report", data or {}) then return end

    local cid = data.cid
    if not (MemberData and MemberData[cid]) then return end

    local reviewer = Framework.GetPlayer(source)
    if not reviewer then return end

    MemberData[cid].ratings = MemberData[cid].ratings or {}
    table.insert(MemberData[cid].ratings, {
        author               = reviewer.name,
        date                 = os.date("%Y-%m-%d"),
        knowledge            = data.knowledge,
        communication        = data.communication,
        situation_management = data.situation_management,
        decision_making      = data.decision_making,
        report_writing       = data.report_writing,
        overall              = data.overall,
    })
    SaveMember(cid)
    SaveMembers()
    Framework.Notify(source, T("report_submitted", { cid = cid }), "success")
end

function PLTLibServer.UpdateRankSalary(source, data)
    if not PLTLibServer.IsActionAuthorized(source, "rank_salary", data or {}) then return end

    local nodeId = data.nodeId
    local level  = tonumber(data.level)
    local newPay = tonumber(data.pay)

    local updated = PLTServerNodes.UpdateRankPayByLevel(nodeId, level, newPay, DepartmentData)
    if updated then
        SaveDepartments()
        if nodeId then
            local deptId = PLTServerNodes.ResolveDepartment(nodeId, DepartmentData)
            if deptId then
                PLTLibServer.SQLUpdateRankSalary(
                    Framework.Type,
                    tostring(GetFrameworkJobFromNodeId(deptId) or ""):lower(),
                    level, newPay)
                UpdateFinanceHistory(deptId)
            else
                for _, linkedId in ipairs(PLTServerNodes.GetLinkedDepartmentIdsForNode(nodeId, DepartmentData)) do
                    UpdateFinanceHistory(linkedId)
                end
            end
        end
        Framework.Notify(source, T("salary_updated"), "success")
    else
        Framework.Notify(source, T("failed_update_salary"), "error")
    end
end

function PLTLibServer.GetPlayers(source, callback)
    PLTLibServer.IsActionAuthorized(source, "get_players", {})

    local result = {}
    for cid, member in pairs(MemberData or {}) do
        local playerData   = Framework.GetPlayerByCitizenId and Framework.GetPlayerByCitizenId(cid)
        local onlineSource = playerData and playerData.source
        local name         = "Unknown"
        local jobLabel, jobGradeLabel = "", ""

        if playerData then
            name = playerData.name or name
            if playerData.job then
                jobLabel      = playerData.job.label      or ""
                jobGradeLabel = playerData.job.gradeLabel or ""
            end
        end

        table.insert(result, {
            id            = onlineSource or -1,
            cid           = cid,
            name          = name,
            jobLabel      = jobLabel,
            jobGradeLabel = jobGradeLabel,
            jobName       = member.dept,
            jobGradeLevel = member.grade,
            isOnline      = playerData ~= nil,
            medals        = member.medals    or {},
            divisions     = member.divisions or {},
        })
    end

    if Config.ShowFakePlayers and Config.FakePlayers then
        for _, fake in ipairs(Config.FakePlayers) do
            table.insert(result, {
                id            = -1,
                cid           = fake.cid,
                name          = fake.name,
                jobLabel      = fake.jobLabel,
                jobGradeLabel = fake.jobGradeLabel,
                jobName       = fake.jobName,
                jobGradeLevel = fake.jobGradeLevel,
                isOnline      = fake.isOnline,
                medals        = {},
                divisions     = {},
            })
        end
    end

    callback(result)
end

function PLTLibServer.BossGetData(source, callback)
    local ok, data = pcall(function()
        local waited = 0
        while not dataLoaded and waited < 100 do Wait(100) waited = waited + 1 end
        if not dataLoaded then return nil end

        local catalog = {}
        if GetResourceState("plt_departments") == "started" then
            pcall(function() catalog = exports.plt_departments:GetDepartmentCatalog(1000) or {} end)
        end

        return {
            departments       = DepartmentData        or { nodes = {}, links = {} },
            departmentCatalog = catalog,
            members           = MemberData            or {},
            finances          = FinanceHistory         or {},
            balances          = DeptBalances           or {},
            autoPay           = AutoPaySettings        or {},
            transactions      = FinanceTransactions    or {},
            warrants          = Warrants               or {},
            cases             = CaseFiles              or {},
            bolos             = Bolos                  or {},
            news              = DeptNews               or {},
            dutyLogs          = DutyLogs               or {},
            mails             = DepartmentMail         or {},
            radars            = ActiveRadars           or {},
            isAuthorized      = IsPlayerAuthorized(source) or HasBossMenuAccess(source),
            mdtEnabled        = Config.MDT and Config.MDT.enabled,
        }
    end)
    callback(ok and data or nil)
end

function PLTLibServer.BossToggleAutoPay(source, data)
    if not PLTLibServer.IsActionAuthorized(source, "division_manage", data or {}) then return end

    local dept    = data.dept
    local payType = data.type
    if not dept or dept == "none" then return end

    AutoPaySettings[dept] = payType
    SaveAutoPay()
    TriggerClientEvent("plt_departments:client:SyncFinancesWithAuto", -1, FinanceHistory, DeptBalances, AutoPaySettings)
    Framework.Notify(source, T("auto_pay_updated", { type = tostring(payType or ""):upper() }), "success")
end

function PLTLibServer.BossDistributeDeptSalaries(deptId, isDryRun, notifySource)
    if not deptId or deptId == "none" then return end

    local balance  = DeptBalances[deptId] or Config.DefaultDeptBalance or 0
    local rankNode = PLTServerNodes.GetLinkedRankNode(deptId, DepartmentData)

    if not (rankNode and rankNode.ranks) then
        if not isDryRun and notifySource and notifySource > 0 then
            Framework.Notify(notifySource, T("no_rank_structure"), "error")
        end
        return
    end

    local totalPay = 0
    local payList  = {}

    for cid, member in pairs(MemberData or {}) do
        if member.dept == deptId then
            for _, rank in ipairs(rankNode.ranks) do
                if tonumber(rank.level) == tonumber(member.grade) then
                    local pay = tonumber(rank.pay) or 0
                    if pay > 0 then
                        totalPay = totalPay + pay
                        table.insert(payList, { cid = cid, amount = pay })
                    end
                    break
                end
            end
        end
    end

    if #payList == 0 then
        if not isDryRun and notifySource and notifySource > 0 then
            Framework.Notify(notifySource, T("no_employees_salary"), "error")
        end
        return
    end

    if balance < totalPay then
        if not isDryRun and notifySource and notifySource > 0 then
            Framework.Notify(notifySource, T("not_enough_dept_funds", { amount = totalPay }), "error")
        end
        return
    end

    local paid = 0
    for _, entry in ipairs(payList) do
        local onlinePlayer = Framework.GetPlayerByCitizenId and Framework.GetPlayerByCitizenId(entry.cid)
        if onlinePlayer then
            onlinePlayer.functions.AddMoney("bank", entry.amount, "Department Salary")
            Framework.Notify(onlinePlayer.source, T("received_salary", { amount = entry.amount, dept = deptId }), "success")
        else
            PLTLibServer.SQLAdjustOfflineBank(Framework.Type, entry.cid, entry.amount)
        end
        paid = paid + 1
    end

    DeptBalances[deptId] = balance - totalPay
    SaveBalances()
    UpdateFinanceHistory(deptId)
    TriggerClientEvent("plt_departments:client:SyncFinancesWithAuto", -1, FinanceHistory, DeptBalances, AutoPaySettings)

    if not isDryRun and notifySource and notifySource > 0 then
        Framework.Notify(notifySource, T("salary_distributed", { amount = totalPay, count = paid }), "success")
    end
end

function PLTLibServer.BossFinanceAction(source, data)
    if not PLTLibServer.IsActionAuthorized(source, "boss_finance", data or {}) then return end

    local player = Framework.GetPlayer(source)
    if not player then return end

    local deptId = data.dept
    local action = data.action
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 or not deptId or deptId == "none" then return end

    if action == "deposit" then
        if player.functions.RemoveMoney("bank", amount, "Department Deposit") then
            DeptBalances[deptId] = (DeptBalances[deptId] or Config.DefaultDeptBalance or 0) + amount
            SaveBalances()
            UpdateFinanceHistory(deptId)
            AddFinanceTransaction(deptId, "deposit", amount,
                { name = player.name, cid = player.citizenid },
                { name = "Department Treasury", cid = deptId },
                "Direct Deposit")
            TriggerClientEvent("plt_departments:client:SyncFinances", -1, FinanceHistory, DeptBalances)
            Framework.Notify(source, T("deposited_balance", { amount = amount }), "success")
        else
            Framework.Notify(source, T("not_enough_cash"), "error")
        end

    elseif action == "withdraw" then
        local current = DeptBalances[deptId] or Config.DefaultDeptBalance or 0
        if amount > current then Framework.Notify(source, T("dept_no_funds"), "error") return end

        local target = Framework.GetPlayerByCitizenId and Framework.GetPlayerByCitizenId(player.citizenid)
        if not target then Framework.Notify(source, T("member_not_found"), "error") return end

        target.functions.AddMoney("bank", amount, "Department Withdrawal")
        DeptBalances[deptId] = current - amount
        SaveBalances()
        UpdateFinanceHistory(deptId)
        AddFinanceTransaction(deptId, "withdraw", amount,
            { name = player.name, cid = player.citizenid },
            { name = "Department Treasury", cid = deptId },
            "Direct Withdrawal")
        TriggerClientEvent("plt_departments:client:SyncFinances", -1, FinanceHistory, DeptBalances)
        Framework.Notify(source, T("withdrew_balance", { amount = amount }), "success")
    end
end

function PLTLibServer.BossSaveData(source, newDepartmentData)
    if not (IsPlayerAuthorized(source) or HasBossMenuAccess(source)) then
        Framework.Notify(source, T("no_permission_manage"), "error")
        return
    end
    if type(newDepartmentData) ~= "table" then
        Framework.Notify(source, T("failed_fetch_data"), "error")
        return
    end
    DepartmentData = newDepartmentData
    SaveDepartments()
    RegisterStashes()
    Framework.Notify(source, T("config_saved"), "success")
end

function PLTLibServer.RegisterCoreCallbacks()

    RegisterNetEvent(SESSION_CHALLENGE_REPLY, function(clientAnswer)
        local src     = source
        local session = sessionStore.sessions[src]
        if not (session and session.nonce) then return end
        if tonumber(clientAnswer) == (session.nonce * 7 + 13) % 1000000 then
            session.verified = true
            session.lastSeen = os.time()
        end
    end)

    RegisterNetEvent(SESSION_KEEPALIVE, function()
        local session = sessionStore.sessions[source]
        if session and session.verified then session.lastSeen = os.time() end
    end)

    local function OnPlayerConnect(src)
        local waited = 0
        while not (PLTServerDataLoaded and PLTServerDataLoaded()) and waited < 200 do
            Wait(50) waited = waited + 1
        end
        if not (PLTServerDataLoaded and PLTServerDataLoaded()) then return end

        local nonce = math.random(100000, 999999)
        sessionStore.sessions[src] = { nonce = nonce, verified = false, lastSeen = 0 }
        TriggerClientEvent(SESSION_CHALLENGE_CLIENT, src, nonce)

        local player = Framework.GetPlayer(src)
        if player and MemberData and MemberData[player.citizenid] then
            if player.functions and player.functions.SetDuty then
                player.functions.SetDuty(MemberData[player.citizenid].onDuty)
            end
        end

        TriggerClientEvent("plt_departments:client:SyncJobs",          src, DepartmentData)
        TriggerClientEvent("plt_departments:client:SyncMembers",       src, MemberData)
        TriggerClientEvent("plt_departments:client:SyncAllDoors",      src, DoorStates)
        TriggerClientEvent("plt_departments:client:SyncRadioChannels", src, RadioChannels)
        TriggerClientEvent("plt_departments:client:SyncFinances",      src, FinanceHistory, DeptBalances)
        TriggerClientEvent("plt_departments:client:SyncTransactions",  src, FinanceTransactions)
        TriggerClientEvent("plt_departments:client:SyncWarrants",      src, Warrants)
        TriggerClientEvent("plt_departments:client:SyncBolos",         src, Bolos)
        TriggerClientEvent("plt_departments:client:SyncNews",          src, DeptNews)
    end

    RegisterNetEvent("plt_departments:server:RequestSync", function() OnPlayerConnect(source) end)
    RegisterNetEvent("plt_departments:s0",                 function() OnPlayerConnect(source) end)

    local function HandleJoinRadio(src, channel)
        local player = Framework.GetPlayer(src)
        if not player then return end

        local cid       = player.citizenid
        local member    = MemberData and MemberData[cid]
        local rankLabel = (member and PLTServerNodes.GetMemberRankLabel(member, DepartmentData, "Officer")) or "Officer"

        for _, listeners in pairs(RadioChannels or {}) do
            for i, entry in ipairs(listeners) do
                if entry.cid == cid then table.remove(listeners, i) break end
            end
        end

        local key = tostring(channel)
        RadioChannels[key] = RadioChannels[key] or {}
        table.insert(RadioChannels[key], { cid = cid, name = player.name, rank = rankLabel })
        TriggerClientEvent("plt_departments:client:SyncRadioChannels", -1, RadioChannels)
    end

    local function HandleLeaveRadio(src)
        local player = Framework.GetPlayer(src)
        if not player then return end
        local cid = player.citizenid
        for _, listeners in pairs(RadioChannels or {}) do
            for i, entry in ipairs(listeners) do
                if entry.cid == cid then table.remove(listeners, i) break end
            end
        end
        TriggerClientEvent("plt_departments:client:SyncRadioChannels", -1, RadioChannels)
    end

    RegisterNetEvent("plt_departments:server:JoinRadio",  function(ch) HandleJoinRadio(source, ch) end)
    RegisterNetEvent("plt_departments:s6",                function(ch) HandleJoinRadio(source, ch) end)
    RegisterNetEvent("plt_departments:server:LeaveRadio", function()   HandleLeaveRadio(source)    end)
    RegisterNetEvent("plt_departments:s7",                function()   HandleLeaveRadio(source)    end)

    RegisterNetEvent("plt_departments:server:addWarrant", function(data)
        local src    = source
        local player = Framework.GetPlayer(src)
        if not player then return end
        local warrant = {
            id          = os.time(),
            subject     = data.subject,
            charges     = data.charges,
            priority    = data.priority    or "Standard",
            issuedBy    = player.name,
            issuedDate  = os.date("%Y-%m-%d %H:%M"),
            description = data.description or "",
            status      = "Active",
        }
        table.insert(Warrants, warrant)
        SaveWarrant(warrant)
        SaveWarrants()
        Framework.Notify(src, T("warrant_issued"), "success")
    end)

    RegisterNetEvent("plt_departments:server:updateWarrant", function(data)
        local src = source
        if not data.id then return end
        for i, w in ipairs(Warrants or {}) do
            if w.id == data.id then
                Warrants[i].subject  = data.subject
                Warrants[i].priority = data.priority
                Warrants[i].charges  = data.charges
                SaveWarrant(Warrants[i])
                break
            end
        end
        SaveWarrants()
        Framework.Notify(src, T("warrant_updated"), "success")
    end)

    RegisterNetEvent("plt_departments:server:completeWarrant", function(warrantId)
        local src = source
        if not warrantId then return end
        for i, w in ipairs(Warrants or {}) do
            if w.id == warrantId then Warrants[i].status = "Completed" SaveWarrant(Warrants[i]) break end
        end
        SaveWarrants()
        Framework.Notify(src, T("warrant_completed"), "success")
    end)

    RegisterNetEvent("plt_departments:server:deleteWarrant", function(warrantId)
        local src = source
        if not (IsPlayerAuthorized(src) or HasBossMenuAccess(src)) then
            Framework.Notify(src, T("no_permission"), "error") return
        end
        for i, w in ipairs(Warrants or {}) do
            if w.id == warrantId then table.remove(Warrants, i) break end
        end
        DeleteWarrantSQL(warrantId)
        SaveWarrants()
        Framework.Notify(src, T("warrant_deleted"), "success")
    end)

    RegisterNetEvent("plt_departments:server:addCaseFile", function(data)
        local src    = source
        local player = Framework.GetPlayer(src)
        if not player then return end
        local caseFile = {
            id         = os.time(),
            title      = data.title,
            summary    = data.summary,
            status     = data.status or "Open",
            issuedBy   = player.name,
            issuedDate = os.date("%Y-%m-%d %H:%M"),
            details    = data.details or "",
            officers   = {},
        }
        table.insert(CaseFiles, caseFile)
        SaveCaseFile(caseFile)
        SaveCaseFiles()
        Framework.Notify(src, T("case_file_created"), "success")
    end)

    RegisterNetEvent("plt_departments:server:updateCaseFile", function(data)
        local src = source
        if not data.id then return end
        for i, c in ipairs(CaseFiles or {}) do
            if c.id == data.id then
                CaseFiles[i].title   = data.title
                CaseFiles[i].summary = data.summary
                CaseFiles[i].status  = data.status
                CaseFiles[i].details = data.details
                SaveCaseFile(CaseFiles[i])
                break
            end
        end
        SaveCaseFiles()
        Framework.Notify(src, T("case_file_updated"), "success")
    end)

    RegisterNetEvent("plt_departments:server:deleteCaseFile", function(caseId)
        local src = source
        if not (IsPlayerAuthorized(src) or HasBossMenuAccess(src)) then
            Framework.Notify(src, T("no_permission"), "error") return
        end
        for i, c in ipairs(CaseFiles or {}) do
            if c.id == caseId then table.remove(CaseFiles, i) break end
        end
        DeleteCaseFileSQL(caseId)
        SaveCaseFiles()
        Framework.Notify(src, T("case_file_archived"), "success")
    end)

    RegisterNetEvent("plt_departments:server:addBolo", function(data)
        local src    = source
        local player = Framework.GetPlayer(src)
        if not player then return end
        local bolo = {
            id          = os.time(),
            type        = data.type or "Vehicle",
            title       = data.title,
            description = data.description,
            plate       = data.plate    or "",
            owner       = data.owner    or "",
            lastSeen    = data.lastSeen or "",
            issuedBy    = player.name,
            issuedDate  = os.date("%Y-%m-%d %H:%M"),
            status      = "Active",
        }
        table.insert(Bolos, bolo)
        SaveBolo(bolo)
        SaveBolos()
        Framework.Notify(src, T("bolo_issued"), "success")
    end)

    RegisterNetEvent("plt_departments:server:updateBolo", function(data)
        local src = source
        if not data.id then return end
        for i, b in ipairs(Bolos or {}) do
            if b.id == data.id then
                Bolos[i].title       = data.title
                Bolos[i].description = data.description
                Bolos[i].type        = data.type
                Bolos[i].plate       = data.plate
                Bolos[i].owner       = data.owner
                Bolos[i].lastSeen    = data.lastSeen
                SaveBolo(Bolos[i])
                break
            end
        end
        SaveBolos()
        Framework.Notify(src, T("bolo_updated"), "success")
    end)

    RegisterNetEvent("plt_departments:server:deleteBolo", function(boloId)
        local src = source
        for i, b in ipairs(Bolos or {}) do
            if b.id == boloId then table.remove(Bolos, i) break end
        end
        DeleteBoloSQL(boloId)
        SaveBolos()
        Framework.Notify(src, T("bolo_archived"), "success")
    end)

    RegisterNetEvent("plt_departments:server:addNews", function(data)
        local src    = source
        local player = Framework.GetPlayer(src)
        if not player then return end
        table.insert(DeptNews, {
            id      = os.time(),
            title   = data.title,
            content = data.content,
            author  = player.name,
            date    = os.date("%B %d, %Y"),
        })
        SaveNews()
        Framework.Notify(src, T("article_posted"), "success")
    end)

    RegisterNetEvent("plt_departments:server:deleteNews", function(articleId)
        local src = source
        for i, article in ipairs(DeptNews or {}) do
            if article.id == articleId then table.remove(DeptNews, i) break end
        end
        SaveNews()
        Framework.Notify(src, T("article_deleted"), "success")
    end)
end

function PLTLibServer.RegisterPublicCallbacksAndExports()

    Framework.CreateCallback("plt_departments:server:getCameras",            function(src, cb)        if __sA0 then __sA0(src, cb)        else cb({})    end end)
    Framework.CreateCallback("plt_departments:server:getImpoundedVehicles",  function(src, cb)        if __sA1 then __sA1(src, cb)        else cb({})    end end)
    Framework.CreateCallback("plt_departments:server:canUnimpound",          function(src, cb, plate) if __sA2 then __sA2(src, cb, plate) else cb(false) end end)
    Framework.CreateCallback("plt_departments:server:getVehicleInfo",        function(src, cb, plate) if __sA3 then __sA3(src, cb, plate) else cb(nil)   end end)
    Framework.CreateCallback("plt_departments:server:GetData",               function(src, cb)        if __sA4 then __sA4(src, cb)        else cb(nil)   end end)
    Framework.CreateCallback("plt_departments:server:checkBolo",             function(src, cb, plate) if __sA5 then __sA5(src, cb, plate) else cb(false) end end)
    Framework.CreateCallback("plt_departments:server:getPlayers",            function(src, cb)        if __sA6 then __sA6(src, cb)        else cb({})    end end)
    Framework.CreateCallback("plt_departments:server:manageMember",          function(src, cb, data)  if __sA7 then __sA7(src, cb, data)  else cb(false) end end)

    Framework.CreateCallback("plt_departments:server:getFrameworkJobRanks", function(src, cb, jobName)
        PLTLibServer.GetFrameworkJobRanks(src, cb, jobName)
    end)

    exports("GetMemberData",       function(cid)                       return __sE0 and __sE0(cid)                                  end)
    exports("IsOnDuty",            function(cid)                       return __sE1 and __sE1(cid) or false                         end)
    exports("GetDepartment",       function(cid)                       return __sE2 and __sE2(cid) or "none"                        end)
    exports("AddBolo",             function(data)                      return __sE3 and __sE3(data)                                 end)
    exports("UpdateBolo",          function(id, data)                  return __sE4 and __sE4(id, data) or false                    end)
    exports("DeleteBolo",          function(id)                        return __sE5 and __sE5(id) or false                          end)
    exports("AddWarrant",          function(data)                      return __sE6 and __sE6(data)                                 end)
    exports("UpdateWarrant",       function(id, data)                  return __sE7 and __sE7(id, data) or false                    end)
    exports("DeleteWarrant",       function(id)                        return __sE8 and __sE8(id) or false                          end)
    exports("GetPlayerDepartment", function(src)                       return __sE9 and __sE9(src)                                  end)
    exports("AddMoneyToDept",      function(deptId, amt, from, reason) return __sEA and __sEA(deptId, amt, from, reason) or false   end)
    exports("SendDepartmentMail",  function(a, b, c, d, e, f)         return __sEB and __sEB(a, b, c, d, e, f) or false            end)

    exports("IsDepartmentsReady", function()
        return dataLoaded == true
    end)

    exports("GetDepartmentsData", function(timeoutMs)
        local limit = tonumber(timeoutMs) or 10000
        local elapsed = 0
        while not (dataLoaded and DepartmentData and DepartmentData.nodes) and limit > elapsed do
            Wait(50) elapsed = elapsed + 50
        end
        return (DepartmentData and DepartmentData.nodes) and DepartmentData or nil
    end)

    exports("GetDepartmentCatalog", function(timeoutMs)
        local limit = tonumber(timeoutMs) or 10000
        local elapsed = 0
        while not (dataLoaded and DepartmentData and DepartmentData.nodes) and limit > elapsed do
            Wait(50) elapsed = elapsed + 50
        end
        if not (DepartmentData and DepartmentData.nodes) then return {} end

        local catalog = {}
        local seen    = {}

        for _, node in ipairs(DepartmentData.nodes) do
            if node.type == "department" then
                local idStr = tostring(node.id)
                local fwJob = PLTServerNodes.TranslateToFrameworkJob(node.id, DepartmentData, false) or idStr
                table.insert(catalog, { id = idStr, label = node.label, frameworkJob = fwJob })
                seen[idStr:lower()] = true
            end
        end

        if GetResourceState("plt_ambulance_job") == "started" then
            local ok, ambCatalog = pcall(function()
                return exports.plt_ambulance_job:GetDepartmentCatalog()
            end)
            if ok and type(ambCatalog) == "table" then
                for _, entry in ipairs(ambCatalog) do
                    if type(entry) == "table" then
                        local entryId = tostring(entry.id or entry.deptId or ""):lower()
                        if entryId ~= "" and not seen[entryId] then
                            table.insert(catalog, {
                                id                = entryId,
                                label             = entry.label or entry.name or entryId,
                                frameworkJob      = entry.frameworkJob or entry.job or entryId,
                                isAmbulanceScript = true,
                            })
                            seen[entryId] = true
                        end
                    end
                end
            end
        end

        return catalog
    end)

    exports("ResolveDepartmentFromJob", function(jobName, timeoutMs)
        local limit = tonumber(timeoutMs) or 10000
        local elapsed = 0
        while not (dataLoaded and DepartmentData and DepartmentData.nodes) and limit > elapsed do
            Wait(50) elapsed = elapsed + 50
        end
        if not (DepartmentData and DepartmentData.nodes) then return nil end

        local jobLower = tostring(jobName or ""):lower()
        if jobLower == "" then return nil end

        for _, node in ipairs(DepartmentData.nodes) do
            if node.type == "department" then
                if tostring(node.id):lower() == jobLower then return node.id end
                local fwJob = PLTServerNodes.TranslateToFrameworkJob(node.id, DepartmentData, false)
                if fwJob and tostring(fwJob):lower() == jobLower then return node.id end
            end
        end

        if GetResourceState("plt_ambulance_job") == "started" then
            local ok, ambCatalog = pcall(function()
                return exports.plt_ambulance_job:GetDepartmentCatalog()
            end)
            if ok and type(ambCatalog) == "table" then
                for _, entry in ipairs(ambCatalog) do
                    if type(entry) == "table" then
                        local entryId  = tostring(entry.id or entry.deptId or ""):lower()
                        local entryJob = tostring(entry.frameworkJob or entry.job or ""):lower()
                        if jobLower == entryId or (entryJob ~= "" and jobLower == entryJob) then
                            return entryId
                        end
                    end
                end
            end
        end

        return nil
    end)

    CreateThread(function()
        local waited = 0
        while not (__sC1 and __sC2) and waited < 200 do Wait(50) waited = waited + 1 end
        if not (__sC1 and __sC2) then return end

        if Framework.Type == "qb" then
            Framework.Core.Commands.Add(Config.CommandName, "Manage departments", {}, false, function(src)
                if __sC1 then __sC1(src) end
            end)
            Framework.Core.Commands.Add("mydept", "Check your current department", {}, false, function(src)
                if __sC2 then __sC2(src) end
            end)
        else
            Framework.Core.RegisterCommand("mydept", "user", function(player)
                if __sC2 then __sC2(player.source) end
            end, false, { help = "Check your current department" })
        end
    end)
end
