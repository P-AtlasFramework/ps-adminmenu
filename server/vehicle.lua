-- Admin Car
RegisterNetEvent('ps-adminmenu:server:SaveCar', function(data, mods, vehicle, _, plate)
    local src = source
    
    if not data or not CheckPerms(src, data.perms) then
        QBCore.Functions.Notify(src, locale("no_perms"), "error", 5000)
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    local ok, existing = pcall(MongoDB.Game.findOne, 'vehicles', { plate = plate })

    if ok and not existing then
        MongoDB.Game.insertOne('vehicles', {
            license   = Player.PlayerData.license,
            citizenid = Player.PlayerData.citizenid,
            vehicle   = vehicle.model,
            hash      = vehicle.hash,
            mods      = mods,
            plate     = plate,
            state     = 0,
            createdAt = os.time(),
        })
        TriggerClientEvent('QBCore:Notify', src, locale("veh_owner"), 'success', 5000)
    else
        TriggerClientEvent('QBCore:Notify', src, locale("u_veh_owner"), 'error', 3000)
    end
end)

-- Give Car
RegisterNetEvent("ps-adminmenu:server:givecar", function(data, selectedData)
    local src = source

    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then
        QBCore.Functions.Notify(src, locale("no_perms"), "error", 5000)
        return
    end

    local vehmodel = selectedData['Vehicle'].value
    local vehicleData = lib.callback.await("ps-adminmenu:client:getvehData", src, vehmodel)

    if not next(vehicleData) then
        return
    end

    local tsrc = selectedData['Player'].value
    local plate = selectedData['Plate (Optional)'] and selectedData['Plate (Optional)'].value or vehicleData.plate
    local garage = selectedData['Garage (Optional)'] and selectedData['Garage (Optional)'].value or Config.DefaultGarage
    local Player = QBCore.Functions.GetPlayer(tsrc)

    if plate and #plate < 1 then
        plate = vehicleData.plate
    end

    if garage and #garage < 1 then
        garage = Config.DefaultGarage
    end

    if plate:len() > 8 then
        QBCore.Functions.Notify(src, locale("plate_max"), "error", 5000)
        return
    end

    if not Player then
        QBCore.Functions.Notify(src, locale("not_online"), "error", 5000)
        return
    end

    if CheckAlreadyPlate(plate) then
        QBCore.Functions.Notify(src, locale("givecar.error.plates_alreadyused", plate:upper()), "error", 5000)
        return
    end

    MongoDB.Game.insertOne('vehicles', {
        license   = Player.PlayerData.license,
        citizenid = Player.PlayerData.citizenid,
        vehicle   = vehmodel,
        hash      = joaat(vehmodel),
        mods      = vehicleData,
        plate     = plate,
        garage    = garage,
        state     = 1,
        createdAt = os.time(),
    })

    QBCore.Functions.Notify(src,
        locale("givecar.success.source", QBCore.Shared.Vehicles[vehmodel].name,
            ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)), "success", 5000)
    QBCore.Functions.Notify(Player.PlayerData.source, locale("givecar.success.target", plate:upper(), garage), "success",
        5000)
end)

-- Give Car
RegisterNetEvent("ps-adminmenu:server:SetVehicleState", function(data, selectedData)
    local src = source

    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then
        QBCore.Functions.Notify(src, locale("no_perms"), "error", 5000)
        return
    end

    local plate = string.upper(selectedData['Plate'].value)
    local state = tonumber(selectedData['State'].value)

    if plate:len() > 8 then
        QBCore.Functions.Notify(src, locale("plate_max"), "error", 5000)
        return
    end

    if not CheckAlreadyPlate(plate) then
        QBCore.Functions.Notify(src, locale("plate_doesnt_exist"), "error", 5000)
        return
    end

    MongoDB.Game.updateOne('vehicles', { plate = plate }, { ['$set'] = { state = state, depotprice = 0 } })

    QBCore.Functions.Notify(src, locale("state_changed"), "success", 5000)
end)

-- Change Plate. In Atlas, vehicle inventory storage (trunk/glovebox) lives
-- on the vehicle document itself or in atlas_inv's stash subsystem, not
-- separate trunkitems/gloveboxitems tables - so we only update the vehicle
-- plate and let downstream resources (atlas_inv, atlas_parking) pick up
-- the change. ox_inventory branch retained for compat.
RegisterNetEvent('ps-adminmenu:server:ChangePlate', function(newPlate, currentPlate)
    local newPlate = newPlate:upper()

    if Config.Inventory == 'ox_inventory' then
        exports.ox_inventory:UpdateVehicle(currentPlate, newPlate)
    end

    MongoDB.Game.updateOne('vehicles', { plate = currentPlate }, { ['$set'] = { plate = newPlate } })
end)

lib.callback.register('ps-adminmenu:server:GetVehicleByPlate', function(source, plate)
    local ok, doc = pcall(MongoDB.Game.findOne, 'vehicles', { plate = plate })
    return (ok and doc and (doc.vehicle or doc.model)) or {}
end)

-- Fix Vehicle for player
RegisterNetEvent('ps-adminmenu:server:FixVehFor', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end
    local src = source
    local playerId = selectedData['Player'].value
    local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
    if Player then
        local name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        TriggerClientEvent('iens:repaira', Player.PlayerData.source)
        TriggerClientEvent('vehiclemod:client:fixEverything', Player.PlayerData.source)
        QBCore.Functions.Notify(src, locale("veh_fixed", name), 'success', 7500)
    else
        TriggerClientEvent('QBCore:Notify', src, locale("not_online"), "error")
    end
end)
