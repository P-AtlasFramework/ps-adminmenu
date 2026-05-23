-- Open Inventory — atlas_inv exposes OpenInventoryById on the server,
-- which OpenInventory's a content-<cid> grid for the target. The legacy
-- ox / qb fallbacks are kept for non-atlas servers.
RegisterNetEvent('ps-adminmenu:client:openInventory', function(data, selectedData)
    local player = tonumber(selectedData["Player"].value)
    if not player then return end

    if Config.Inventory == 'atlas_inv' then
        TriggerServerEvent("ps-adminmenu:server:OpenInv", player)
    elseif Config.Inventory == 'ox_inventory' then
        TriggerServerEvent("ps-adminmenu:server:OpenInv", player)
    else
        TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", player)
    end
end)

-- Open Stash
RegisterNetEvent('ps-adminmenu:client:openStash', function(data, selectedData)
    local stash = selectedData["Stash"].value

    if Config.Inventory == 'ox_inventory' then
        TriggerServerEvent("ps-adminmenu:server:OpenStash", stash)
    else
        TriggerServerEvent("inventory:server:OpenInventory", "stash", tostring(stash))
        TriggerEvent("inventory:client:SetCurrentStash", tostring(stash))
    end
end)

-- Open Trunk
RegisterNetEvent('ps-adminmenu:client:openTrunk', function(data, selectedData)
    local vehiclePlate = selectedData["Plate"].value

    if Config.Inventory == 'ox_inventory' then
        TriggerServerEvent("ps-adminmenu:server:OpenTrunk", vehiclePlate)
    else
        TriggerServerEvent("inventory:server:OpenInventory", "trunk", tostring(vehiclePlate))
        TriggerEvent("inventory:client:SetCurrentStash", tostring(vehiclePlate))
    end
end)

-- Open the appearance/clothing editor — fired by the admin clothing
-- action from the server side.
RegisterNetEvent('ps-adminmenu:client:openClothing', function()
    pcall(function() exports['atlas_appearance']:openAppearance() end)
end)
