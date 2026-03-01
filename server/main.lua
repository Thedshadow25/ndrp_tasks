-- ===================================================
-- NDRP Tasks | Server-side v5
-- Production-ready implementation with XP, stats, cooldown enforcement
-- ===================================================

-- Active missions (server-side enforcement)
local activeMissions = {} -- [source] = true
local playerCooldowns = {} -- [license] = os.time() when cooldown expires

-- Debug logging
local function logDebug(message)
    print('^2[ndrp_tasks]^7 ' .. message)
end

local function logError(message)
    print('^1[ndrp_tasks - ERROR]^7 ' .. message)
end

-- ===================================================
-- HELPER: Get player license
-- ===================================================
local function getPlayerLicense(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.find(id, 'license:') then
            return id
        end
    end
    return nil
end

-- ===================================================
-- HELPER: Get/Set player task data (KVP by license)
-- ===================================================
local function getPlayerData(source)
    local license = getPlayerLicense(source)
    if not license then return { xp = 0, level = 1, missionsCompleted = 0, totalEarnings = 0 } end

    local raw = GetResourceKvpString('ndrp_tasks:' .. license)
    if raw then
        local data = json.decode(raw)
        if data then return data end
    end

    return { xp = 0, level = 1, missionsCompleted = 0, totalEarnings = 0 }
end

local function savePlayerData(source, data)
    local license = getPlayerLicense(source)
    if not license then return end
    SetResourceKvp('ndrp_tasks:' .. license, json.encode(data))
end

-- ===================================================
-- HELPER: Calculate level from XP
-- ===================================================
local function calculateLevel(xp)
    local level = 1
    for _, lvlData in ipairs(Config.Levels) do
        if xp >= lvlData.xpRequired then
            level = lvlData.level
        end
    end
    return level
end

-- ===================================================
-- HELPER: Get XP needed for next level
-- ===================================================
local function getNextLevelXP(currentLevel)
    for _, lvlData in ipairs(Config.Levels) do
        if lvlData.level == currentLevel + 1 then
            return lvlData.xpRequired
        end
    end
    return nil -- Max level
end

-- ===================================================
-- CALLBACK: Get player stats (XP, level, etc.)
-- ===================================================
lib.callback.register('ndrp_tasks:getStats', function(source)
    local data = getPlayerData(source)
    data.level = calculateLevel(data.xp)
    local nextXP = getNextLevelXP(data.level)

    -- Calculate current level XP progress
    local currentLevelXP = 0
    for _, lvlData in ipairs(Config.Levels) do
        if lvlData.level == data.level then
            currentLevelXP = lvlData.xpRequired
        end
    end

    return {
        xp = data.xp,
        level = data.level,
        missionsCompleted = data.missionsCompleted,
        totalEarnings = data.totalEarnings,
        nextLevelXP = nextXP or data.xp,
        currentLevelXP = currentLevelXP,
    }
end)

-- ===================================================
-- CALLBACK: Check if player can start mission
-- ===================================================
lib.callback.register('ndrp_tasks:canStartMission', function(source, requiredLevel)
    if not source then
        logError('canStartMission called with invalid source')
        return false
    end
    
    requiredLevel = requiredLevel or 1

    -- Check one-mission-per-player
    if activeMissions[source] then
        return false, 'already_active'
    end

    -- Check cooldown
    local license = getPlayerLicense(source)
    if license and playerCooldowns[license] then
        local remaining = playerCooldowns[license] - os.time()
        if remaining > 0 then
            return false, 'cooldown', remaining
        else
            playerCooldowns[license] = nil
        end
    end

    -- Check level requirement
    local data = getPlayerData(source)
    local playerLevel = calculateLevel(data.xp)
    if playerLevel < requiredLevel then
        return false, 'level_required', requiredLevel
    end

    -- Mark mission as active
    activeMissions[source] = true
    logDebug('Mission started for player ' .. source .. ' (Level: ' .. playerLevel .. ')')
    return true
end)

-- ===================================================
-- CALLBACK: Complete mission (XP, stats, cooldown)
-- ===================================================
lib.callback.register('ndrp_tasks:completeMission', function(source, reward, xpAmount)
    if not source then
        logError('completeMission called with invalid source')
        return false
    end
    
    if not activeMissions[source] then
        logError('Player ' .. source .. ' tried to complete mission but not active')
        return false
    end

    local data = getPlayerData(source)
    if not data then
        logError('Could not get player data for ' .. source)
        return false
    end

    -- Give reward
    if reward and reward > 0 then
        local player = exports.qbx_core:GetPlayer(source)
        if player then
            player.Functions.AddMoney('cash', reward, 'ndrp-tasks-reward')
            logDebug('Reward given to player ' .. source .. ': $' .. reward)
        end
    end

    -- Add XP
    data.xp = (data.xp or 0) + (xpAmount or 0)
    data.level = calculateLevel(data.xp)
    data.missionsCompleted = (data.missionsCompleted or 0) + 1
    data.totalEarnings = (data.totalEarnings or 0) + (reward or 0)

    savePlayerData(source, data)

    -- Set cooldown
    local license = getPlayerLicense(source)
    if license then
        playerCooldowns[license] = os.time() + Config.Cooldown
        logDebug('Cooldown set for player ' .. source)
    end

    -- Clear active mission
    activeMissions[source] = nil

    return true, data.xp, data.level
end)

-- ===================================================
-- CALLBACK: Fail/Cancel mission (cleanup, cooldown, remove items)
-- ===================================================
lib.callback.register('ndrp_tasks:failMission', function(source, itemToRemove, amountToRemove)
    if not source then
        logError('failMission called with invalid source')
        return false
    end
    
    activeMissions[source] = nil

    -- Remove any given/scavenged items if needed
    if itemToRemove and amountToRemove and amountToRemove > 0 then
        local removed = exports.ox_inventory:RemoveItem(source, itemToRemove, amountToRemove)
        if removed then
            logDebug('Items removed from player ' .. source .. ': ' .. amountToRemove .. 'x ' .. itemToRemove)
        end
    end

    -- Set cooldown on fail too
    local license = getPlayerLicense(source)
    if license then
        playerCooldowns[license] = os.time() + Config.Cooldown
        logDebug('Cooldown set for player ' .. source .. ' (mission failed)')
    end

    return true
end)

-- ===================================================
-- CALLBACK: Get cooldown remaining
-- ===================================================
lib.callback.register('ndrp_tasks:getCooldown', function(source)
    local license = getPlayerLicense(source)
    if license and playerCooldowns[license] then
        local remaining = playerCooldowns[license] - os.time()
        if remaining > 0 then
            return remaining
        end
    end
    return 0
end)

-- ===================================================
-- CALLBACK: Give item to player (delivery pickup)
-- ===================================================
lib.callback.register('ndrp_tasks:pickupItem', function(source, item)
    if not source or not item or item == '' then
        logError('Invalid pickupItem callback: source=' .. tostring(source) .. ', item=' .. tostring(item))
        return false
    end
    
    local success = exports.ox_inventory:AddItem(source, item, 1)
    if success then
        logDebug('Item given to player ' .. source .. ': ' .. item)
        return true
    else
        logError('Could not give "' .. item .. '" to player ' .. source)
        return false
    end
end)

-- ===================================================
-- CALLBACK: Remove item + give reward (delivery dropoff)
-- ===================================================
lib.callback.register('ndrp_tasks:dropoffItem', function(source, item)
    if not source or not item or item == '' then
        logError('Invalid dropoffItem callback: source=' .. tostring(source) .. ', item=' .. tostring(item))
        return false
    end
    
    local count = exports.ox_inventory:GetItemCount(source, item)
    if not count or count < 1 then
        return false
    end

    local removed = exports.ox_inventory:RemoveItem(source, item, 1)
    if not removed then
        logError('Could not remove item "' .. item .. '" from player ' .. source)
        return false
    end
    
    logDebug('Item removed from player ' .. source .. ': ' .. item)
    return true
end)

-- ===================================================
-- CALLBACK: Give item with amount (scavenge)
-- ===================================================
lib.callback.register('ndrp_tasks:giveItem', function(source, item, amount)
    if not source or not item or item == '' or not amount or amount < 1 then
        logError('Invalid giveItem callback: source=' .. tostring(source) .. ', item=' .. tostring(item) .. ', amount=' .. tostring(amount))
        return false
    end
    
    local success = exports.ox_inventory:AddItem(source, item, amount)
    if success then
        logDebug('Items given to player ' .. source .. ': ' .. amount .. 'x ' .. item)
        return true
    else
        logError('Could not give ' .. amount .. 'x \"' .. item .. '\" to player ' .. source)
        return false
    end
end)

-- ===================================================
-- CLEANUP: Player dropped
-- ===================================================
AddEventHandler('playerDropped', function()
    local source = source
    activeMissions[source] = nil
end)
