-- ============================================================
--  Boss Menu: Rank Outfits (ESX Edition)
--  The boss wears an outfit, then saves it to a rank from the
--  boss menu (Safari > OUTFITS tab) or with /setrankoutfit.
-- ============================================================

-- Capture the player's current ped appearance (same shape ApplyOutfit consumes)
function GetMyCurrentOutfit()
    local ped    = PlayerPedId()
    local outfit = {}

    local components = {
        mask = 1, hair = 2, arms = 3, pants = 4, bags = 5, shoes = 6,
        accessory = 7, undershirt = 8, vest = 9, decals = 10, top = 11,
    }
    for name, slot in pairs(components) do
        outfit[name] = {
            item    = GetPedDrawableVariation(ped, slot),
            texture = GetPedTextureVariation(ped, slot),
        }
    end

    local props = { hat = 0, glasses = 1, ears = 2, watch = 6, bracelet = 7 }
    for name, slot in pairs(props) do
        outfit[name] = {
            item    = GetPedPropIndex(ped, slot),
            texture = GetPedPropTextureIndex(ped, slot),
        }
    end

    return outfit
end

-- Boss menu: "Save my current outfit to this rank"
RegisterNUICallback("saveMyOutfitToRank", function(data, cb)
    local rankLevel = tonumber(data and data.rankLevel)
    if not rankLevel then
        cb({ ok = false })
        return
    end
    TriggerServerEvent("plt_departments:server:saveRankOutfit", rankLevel, GetMyCurrentOutfit())
    cb({ ok = true })
end)

-- Boss menu: delete a saved rank outfit
RegisterNUICallback("deleteRankOutfit", function(data, cb)
    local rankLevel = tonumber(data and data.rankLevel)
    if not rankLevel then
        cb({ ok = false })
        return
    end
    TriggerServerEvent("plt_departments:server:deleteRankOutfit", rankLevel)
    cb({ ok = true })
end)

-- Command shortcut: wear the outfit, then /setrankoutfit <rank level>
RegisterCommand("setrankoutfit", function(_, args)
    local rankLevel = tonumber(args and args[1])
    if not rankLevel then
        Framework.Notify(T("outfit_need_rank_arg"), "error")
        return
    end
    TriggerServerEvent("plt_departments:server:saveRankOutfit", rankLevel, GetMyCurrentOutfit())
end, false)
