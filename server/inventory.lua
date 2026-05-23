-- Clear Inventory
RegisterNetEvent('ps-adminmenu:server:ClearInventory', function(data, selectedData)
    local src = source
    data = CheckDataFromKey(data)
    -- CheckPerms requires the SOURCE — the original call passed only
    -- perms and effectively asked "is `data.perms` (a string) allowed
    -- to do `nil`?" — always rejected, so Clear Inventory never fired.
    if not data or not CheckPerms(src, data.perms) then return end

    local player = tonumber(selectedData["Player"].value)
    local Player = Atlas.Functions.GetPlayer(player)

    if not Player then
        return Atlas.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end

    pcall(function() exports['atlas_inv']:ClearInventory(player) end)

    Atlas.Functions.Notify(src,
        locale("invcleared", Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname),
        'success', 7500)
end)

-- Clear Inventory Offline
RegisterNetEvent('ps-adminmenu:server:ClearInventoryOffline', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end

    local src = source
    local citizenId = selectedData["Citizen ID"].value
    local Player = Atlas.Functions.GetPlayerByCitizenId(citizenId)

    if Player then
        pcall(function() exports['atlas_inv']:ClearInventory(Player.PlayerData.source) end)
        Atlas.Functions.Notify(src,
            locale("invcleared", Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname),
            'success', 7500)
    else
        -- Offline path: atlas_inv stores inventories in the `inventories`
        -- collection keyed by `inventoryName` like `content-<cid>` per
        -- the slot ladder in Config.PlayerInventories. Delete all rows
        -- ending in this cid; player char doc lives in `characters` (no
        -- inventory field there post-Phase-13).
        local docs = MongoDB.Game.findMany('characters', { citizenid = citizenId })
        if docs and docs[1] then
            MongoDB.Game.deleteMany('inventories', { name = { ['$regex'] = '-' .. citizenId .. '$' } })
            Atlas.Functions.Notify(src, "Player's inventory cleared (offline)", 'success', 7500)
        else
            Atlas.Functions.Notify(src, locale("player_not_found"), 'error', 7500)
        end
    end
end)

-- Open someone else's pockets. atlas_inv's `OpenInventory` opens the
-- given inventory NAME for the calling source — for player pockets
-- that's `content-<cid>`. Falls back to ox_inventory for non-atlas
-- deployments.
RegisterNetEvent('ps-adminmenu:server:OpenInv', function(targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    if Config.Inventory == 'atlas_inv' then
        local Target = Atlas.Functions.GetPlayer(targetSrc)
        if not Target then return end
        local invName = 'content-' .. Target.PlayerData.citizenid
        pcall(function() exports['atlas_inv']:OpenInventory(src, invName, 'content') end)
    else
        exports.ox_inventory:forceOpenInventory(src, 'player', targetSrc)
    end
end)

-- Open Stash [ox side]
RegisterNetEvent('ps-adminmenu:server:OpenStash', function(data)
    exports.ox_inventory:forceOpenInventory(source, 'stash', data)
end)

-- Open Trunk [ox side]
RegisterNetEvent('ps-adminmenu:server:OpenTrunk', function(data)
    exports.ox_inventory:forceOpenInventory(source, 'trunk', data)
end)

-- Give Item
RegisterNetEvent('ps-adminmenu:server:GiveItem', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end

    local target = selectedData["Player"].value
    local item = selectedData["Item"].value
    local amount = tonumber(selectedData["Amount"].value)
    local Player = Atlas.Functions.GetPlayer(target)

    if not item or not amount or amount <= 0 then return end
    if not Player then
        return Atlas.Functions.Notify(source, locale("not_online"), 'error', 7500)
    end

    if Config.Inventory == 'atlas_inv' then
        exports['atlas_inv']:AddItem(target, item, amount, nil, nil, 'admin_give')
    elseif Config.Inventory == "ox_inventory" then
        exports.ox_inventory:AddItem(target, item, amount)
    elseif Config.Inventory == "qb-inventory" then
        Player.Functions.AddItem(item, amount)
    end

    Atlas.Functions.Notify(source,
        locale("give_item", amount .. " " .. item,
            Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname), "success", 7500)
end)

-- Give Item to All
RegisterNetEvent('ps-adminmenu:server:GiveItemAll', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end

    local item = selectedData["Item"].value
    local amount = tonumber(selectedData["Amount"].value)
    local players = Atlas.Functions.GetPlayers()

    if not item or not amount or amount <= 0 then return end

    for _, id in pairs(players) do
        if Config.Inventory == 'atlas_inv' then
            exports['atlas_inv']:AddItem(id, item, amount, nil, nil, 'admin_give')
        elseif Config.Inventory == "ox_inventory" then
            exports.ox_inventory:AddItem(id, item, amount)
        elseif Config.Inventory == "qb-inventory" then
            local Player = Atlas.Functions.GetPlayer(id)
            if Player then
                Player.Functions.AddItem(item, amount)
            end
        end
    end

    Atlas.Functions.Notify(source, locale("give_item_all", amount .. " " .. item), "success", 7500)
end)