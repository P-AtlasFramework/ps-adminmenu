local function getVehicles(cid)
    -- Atlas stores vehicles in the Mongo `vehicles` collection (owned by
    -- atlas_dealership / atlas_parking). Filter by citizenid.
    local ok, result = pcall(MongoDB.Game.findMany, 'vehicles', { citizenid = cid })
    if not ok or type(result) ~= 'table' then return {} end
    local vehicles = {}

    for k, v in pairs(result) do
        local model = v.vehicle or v.model
        local vehicleData = Atlas.Shared.Vehicles and Atlas.Shared.Vehicles[model]

        if vehicleData then
            vehicles[#vehicles + 1] = {
                id    = k,
                cid   = cid,
                label = vehicleData.name,
                brand = vehicleData.brand,
                model = vehicleData.model,
                plate = v.plate,
                fuel  = v.fuel,
                engine = v.engine,
                body  = v.body,
            }
        end
    end

    return vehicles
end

local function getPlayers()
    local players = {}

    -- Iterate Atlas.Players directly. It's the authoritative source-keyed
    -- map of online player objects; pairs() yields (src, Player) pairs.
    for k, v in pairs(Atlas.Players) do
        local playerData = v.PlayerData
        local vehicles = getVehicles(playerData.citizenid)

        players[#players + 1] = {
            id = k,
            name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname,
            cid = playerData.citizenid,
            license = Atlas.Functions.GetIdentifier(k, 'license'),
            discord = Atlas.Functions.GetIdentifier(k, 'discord'),
            steam = Atlas.Functions.GetIdentifier(k, 'steam'),
            job = playerData.job.label,
            grade = playerData.job.grade.level,
            dob = playerData.charinfo.birthdate,
            cash = playerData.money.cash,
            bank = playerData.money.bank,
            phone = playerData.charinfo.phone,
            vehicles = vehicles
        }
    end

    table.sort(players, function(a, b) return a.id < b.id end)

    return players
end

lib.callback.register('ps-adminmenu:callback:GetPlayers', function(source)
    return getPlayers()
end)

local function resolveGrade(grades, input)
    if not grades then return nil, nil end

    local gradeKey = tonumber(input) or input
    local gradeData = grades[gradeKey] or grades[tostring(gradeKey)]
    local gradeValue = tonumber(input) or input

    if gradeData then
        if gradeData.grade ~= nil then
            gradeValue = gradeData.grade
        elseif gradeData.level ~= nil then
            gradeValue = gradeData.level
        elseif gradeData.id ~= nil then
            gradeValue = gradeData.id
        end
        return gradeData, gradeValue
    end

    for _, v in pairs(grades) do
        local candidate = v.grade or v.level or v.id or v.rank or v.order
        if candidate ~= nil and tostring(candidate) == tostring(input) then
            return v, candidate
        end
        if v.name and tostring(v.name) == tostring(input) then
            return v, candidate or gradeValue
        end
    end

    return nil, nil
end

-- Set Job
RegisterNetEvent('ps-adminmenu:server:SetJob', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end
    local src = source
    local playerId, Job, Grade = selectedData["Player"].value, selectedData["Job"].value, selectedData["Grade"].value
    local Player = Atlas.Functions.GetPlayer(playerId)
    if not Player then
        Atlas.Functions.Notify(source, locale("not_online"), 'error')
        return
    end
    local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local jobInfo = Atlas.Shared.Jobs[Job]
    local grade, gradeValue = resolveGrade(jobInfo and jobInfo["grades"], Grade)

    if not jobInfo then
        Atlas.Functions.Notify(source, "Not a valid job", 'error')
        return
    end

    if not grade then
        Atlas.Functions.Notify(source, "Not a valid grade", 'error')
        return
    end

    Player.Functions.SetJob(tostring(Job), tonumber(gradeValue) or gradeValue)
    if Config.RenewedPhone then
        exports['qb-phone']:hireUser(tostring(Job), Player.PlayerData.citizenid, tonumber(Grade))
    end

    Atlas.Functions.Notify(src, locale("jobset", name, Job, Grade), 'success', 5000)
end)

-- Set Gang
RegisterNetEvent('ps-adminmenu:server:SetGang', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end
    local src = source
    local playerId, Gang, Grade = selectedData["Player"].value, selectedData["Gang"].value, selectedData["Grade"].value
    local Player = Atlas.Functions.GetPlayer(playerId)
    if not Player then
        Atlas.Functions.Notify(source, locale("not_online"), 'error')
        return
    end
    local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local GangInfo = Atlas.Shared.Gangs[Gang]
    local grade, gradeValue = resolveGrade(GangInfo and GangInfo["grades"], Grade)

    if not GangInfo then
        Atlas.Functions.Notify(source, "Not a valid Gang", 'error')
        return
    end

    if not grade then
        Atlas.Functions.Notify(source, "Not a valid grade", 'error')
        return
    end

    Player.Functions.SetGang(tostring(Gang), tonumber(gradeValue) or gradeValue)
    Atlas.Functions.Notify(src, locale("gangset", name, Gang, Grade), 'success', 5000)
end)

-- Set Perms
RegisterNetEvent("ps-adminmenu:server:SetPerms", function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end
    local src = source
    local rank = selectedData["Permissions"].value
    local targetId = selectedData["Player"].value
    local tPlayer = Atlas.Functions.GetPlayer(tonumber(targetId))

    if not tPlayer then
        Atlas.Functions.Notify(src, locale("not_online"), "error", 5000)
        return
    end

    local name = tPlayer.PlayerData.charinfo.firstname .. ' ' .. tPlayer.PlayerData.charinfo.lastname

    Atlas.Functions.AddPermission(tPlayer.PlayerData.source, tostring(rank))
    Atlas.Functions.Notify(tPlayer.PlayerData.source, locale("player_perms", name, rank), 'success', 5000)
end)

-- Remove Stress
RegisterNetEvent("ps-adminmenu:server:RemoveStress", function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end
    local src = source
    local targetId = selectedData['Player (Optional)'] and tonumber(selectedData['Player (Optional)'].value) or src
    local tPlayer = Atlas.Functions.GetPlayer(tonumber(targetId))

    if not tPlayer then
        Atlas.Functions.Notify(src, locale("not_online"), "error", 5000)
        return
    end

    TriggerClientEvent('ps-adminmenu:client:removeStress', targetId)

    Atlas.Functions.Notify(tPlayer.PlayerData.source, locale("removed_stress_player"), 'success', 5000)
end)
