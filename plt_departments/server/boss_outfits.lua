-- ============================================================
--  Boss Menu: Rank Outfits (ESX Edition)
--  Saves the boss's currently worn outfit to a department rank.
--  Stored in the wardrobe node's outfits table and persisted to
--  the database (plt_departments_data blob) via SaveDepartments().
-- ============================================================

-- Find the wardrobe node belonging to a department (nearest via links)
local function FindWardrobeNodeForDept(deptId)
    if not (deptId and DepartmentData and DepartmentData.nodes and DepartmentData.links) then
        return nil
    end

    local best, bestDepth = nil, math.huge
    for _, node in ipairs(DepartmentData.nodes) do
        if node.type == "wardrobe" then
            local resolved = PLTServerNodes.ResolveDepartment(node.id, DepartmentData)
            if tostring(resolved) == tostring(deptId) then
                -- count link depth to pick the closest wardrobe node
                local depth = 0
                for _, link in ipairs(DepartmentData.links) do
                    if tostring(link.from) == tostring(node.id) or tostring(link.to) == tostring(node.id) then
                        depth = depth + 1
                    end
                end
                if depth < bestDepth then
                    best, bestDepth = node, depth
                end
            end
        end
    end
    return best
end

-- Resolve the player's department id
local function ResolvePlayerDeptId(playerId)
    local player = Framework.GetPlayer(playerId)
    if not player then return nil end

    local memberEntry = MemberData[player.citizenid]
    local deptId = memberEntry and memberEntry.dept or nil
    if deptId ~= nil and deptId ~= "none" then return deptId end

    if player.job and player.job.name and PLTServerNodes.GetNodeIdFromFrameworkJob then
        return PLTServerNodes.GetNodeIdFromFrameworkJob(player.job.name, DepartmentData)
    end
    return nil
end

local function SaveOutfitForRank(src, rankLevel, outfit)
    if not (IsPlayerAuthorized(src) or HasBossMenuAccess(src)) then
        Framework.Notify(src, T("no_permission_manage"), "error")
        return
    end

    rankLevel = tonumber(rankLevel)
    if not rankLevel or type(outfit) ~= "table" then return end

    local deptId = ResolvePlayerDeptId(src)
    if not deptId or deptId == "none" then
        Framework.Notify(src, T("not_in_dept"), "error")
        return
    end

    local wardrobeNode = FindWardrobeNodeForDept(deptId)
    if not wardrobeNode then
        Framework.Notify(src, T("no_wardrobe_node"), "error")
        return
    end

    wardrobeNode.outfits = wardrobeNode.outfits or {}
    wardrobeNode.outfits["rank_" .. rankLevel] = { outfit }

    SaveDepartments() -- persists to SQL + syncs every client

    Framework.Notify(src, T("outfit_saved_for_rank", { rank = rankLevel }), "success")
end

RegisterNetEvent("plt_departments:server:saveRankOutfit")
AddEventHandler("plt_departments:server:saveRankOutfit", function(rankLevel, outfit)
    SaveOutfitForRank(source, rankLevel, outfit)
end)

RegisterNetEvent("plt_departments:server:deleteRankOutfit")
AddEventHandler("plt_departments:server:deleteRankOutfit", function(rankLevel)
    local src = source
    if not (IsPlayerAuthorized(src) or HasBossMenuAccess(src)) then
        Framework.Notify(src, T("no_permission_manage"), "error")
        return
    end

    rankLevel = tonumber(rankLevel)
    if not rankLevel then return end

    local deptId = ResolvePlayerDeptId(src)
    if not deptId or deptId == "none" then
        Framework.Notify(src, T("not_in_dept"), "error")
        return
    end

    local wardrobeNode = FindWardrobeNodeForDept(deptId)
    if not wardrobeNode or not wardrobeNode.outfits or not wardrobeNode.outfits["rank_" .. rankLevel] then
        Framework.Notify(src, T("outfit_not_found_for_rank"), "error")
        return
    end

    wardrobeNode.outfits["rank_" .. rankLevel] = nil
    SaveDepartments()
    Framework.Notify(src, T("outfit_deleted_for_rank", { rank = rankLevel }), "success")
end)
