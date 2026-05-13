-- Clear Inventory
RegisterNetEvent('ps-adminmenu:server:ClearInventory', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(data.perms) then return end

    local src = source
    local player = selectedData["Player"].value
    local Player = Atlas.Functions.GetPlayer(player)

    if not Player then
        return Atlas.Functions.Notify(source, locale("not_online"), 'error', 7500)
    end

    if Config.Inventory == 'atlas_inv' then
        exports['atlas_inv']:ClearInventory(player)
    elseif Config.Inventory == 'ox_inventory' then
        exports.ox_inventory:ClearInventory(player)
    else
        exports[Config.Inventory]:ClearInventory(player, nil)
    end

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
        if Config.Inventory == 'atlas_inv' then
            exports['atlas_inv']:ClearInventory(Player.PlayerData.source)
        elseif Config.Inventory == 'ox_inventory' then
            exports.ox_inventory:ClearInventory(Player.PlayerData.source)
        else
            exports[Config.Inventory]:ClearInventory(Player.PlayerData.source, nil)
        end
        Atlas.Functions.Notify(src,
            locale("invcleared", Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname),
            'success', 7500)
    else
        -- Offline path: read the players collection from Mongo, zero out
        -- the inventory field. atlas_core stores player docs in the `players`
        -- collection of atlas_game; the inventory subdoc is owned by
        -- atlas_inv. Clearing here wipes both server-side and on next login.
        local ok, doc = pcall(MongoDB.Game.findOne, 'players', { citizenid = citizenId })
        if ok and doc then
            MongoDB.Game.updateOne('players', { citizenid = citizenId }, { ['$set'] = { items = {} } })
            Atlas.Functions.Notify(src, "Player's inventory cleared (offline)", 'success', 7500)
        else
            Atlas.Functions.Notify(src, locale("player_not_found"), 'error', 7500)
        end
    end
end)

-- Open Inv [ox side]
RegisterNetEvent('ps-adminmenu:server:OpenInv', function(data)
    exports.ox_inventory:forceOpenInventory(source, 'player', data)
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