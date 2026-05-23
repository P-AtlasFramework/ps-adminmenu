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

-- Lookup helpers that survive a missing/restructured PlayerData field.
-- Phase 13 split moved some lookups around (.org / .job / .crime) and
-- banking balances now live in the atlas_banking accounts collection,
-- not PlayerData.money.bank — those used to throw and abort the whole
-- callback, returning an empty player list in the UI.
local function safeJobLabel(pd)
    local job = pd.job
    if type(job) ~= 'table' then return 'unemployed' end
    return job.label or job.name or 'unemployed'
end

local function safeJobGrade(pd)
    local job = pd.job
    if type(job) ~= 'table' or type(job.grade) ~= 'table' then return 0 end
    return tonumber(job.grade.level) or tonumber(job.grade.id) or 0
end

local function safeMoney(src, pd, kind)
    -- Prefer atlas_banking (authoritative since the Phase 13 split).
    local ok, val = pcall(function() return exports['atlas_banking']:PlayerGetMoney(src, kind) end)
    if ok and type(val) == 'number' then return val end
    -- Fallback to PlayerData.money for legacy reads.
    local m = pd.money or {}
    return tonumber(m[kind]) or 0
end

local function getPlayers()
    local players = {}

    -- IMPORTANT: Atlas.Players from exports['atlas_core']:GetCoreObject()
    -- is a FROZEN SNAPSHOT taken at this resource's boot time (empty),
    -- not the live state. Iterating it returns nothing. The live source
    -- list goes through Atlas.Functions.GetPlayers() which routes back
    -- into atlas_core via the export RPC each call.
    for _, src in ipairs(Atlas.Functions.GetPlayers() or {}) do
        local Player = Atlas.Functions.GetPlayer(src)
        local playerData = Player and Player.PlayerData
        if playerData and playerData.charinfo then
            local vehicles = getVehicles(playerData.citizenid)
            local charinfo = playerData.charinfo

            players[#players + 1] = {
                id       = src,
                name     = ((charinfo.firstname or '?') .. ' ' .. (charinfo.lastname or '?')),
                cid      = playerData.citizenid,
                license  = Atlas.Functions.GetIdentifier(src, 'license'),
                discord  = Atlas.Functions.GetIdentifier(src, 'discord'),
                steam    = Atlas.Functions.GetIdentifier(src, 'steam'),
                job      = safeJobLabel(playerData),
                grade    = safeJobGrade(playerData),
                dob      = charinfo.birthdate,
                cash     = safeMoney(src, playerData, 'cash'),
                bank     = safeMoney(src, playerData, 'bank'),
                phone    = charinfo.phone,
                vehicles = vehicles,
            }
        end
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

    -- Route through atlas_mgmt OrgStore so the per-player Mongo doc,
    -- the cache, and PlayerData.org/job all stay in sync — promotions
    -- via Player.Functions.SetJob alone don't always write back to the
    -- canonical OrgStore record under Phase 13.
    local routed = false
    pcall(function()
        routed = exports['atlas_mgmt']:SetPlayerOrg(playerId, tostring(Job), tonumber(gradeValue) or gradeValue) == true
    end)
    if not routed then
        Player.Functions.SetJob(tostring(Job), tonumber(gradeValue) or gradeValue)
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

    local routed = false
    pcall(function()
        routed = exports['atlas_mgmt']:SetPlayerOrg(playerId, tostring(Gang), tonumber(gradeValue) or gradeValue) == true
    end)
    if not routed then
        Player.Functions.SetGang(tostring(Gang), tonumber(gradeValue) or gradeValue)
    end

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
