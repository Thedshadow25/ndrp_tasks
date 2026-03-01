-- ===================================================
-- NDRP Tasks | Client-side v5
-- Supports: delivery + scavenge + cartheft + smuggle
-- Features: cooldown, failure, damage penalty, cancel, prop carrying, XP/stats, NPC dialogue
-- ===================================================

local stationPed = nil
local stationBlip = nil

-- Active task state
local activeTask = nil
local activeCategory = nil
local taskInProgress = false
local hasPickedUp = false

-- Delivery state
local dropoffPed = nil
local dropoffBlip = nil
local deliveryPropObj = nil  -- attached box prop
local boxInTrunk = false     -- is the box currently in the trunk?
local carryAnimActive = false

-- Scavenge state
local spawnedProps = {}
local searchAreaBlip = nil
local searchRadiusBlip = nil
local scavengedItemsCount = 0
local boxesSearched = 0
local totalItems = 0

-- Car theft state
local theftCar = nil
local theftGuard = nil
local theftCarBlip = nil
local theftDeliveryBlip = nil
local theftRadiusBlip = nil
local guardDefeated = false
local carStolen = false

-- Smuggle state
local smuggleVehicle = nil
local smuggleVehicleBlip = nil
local smuggleDropoffPed = nil
local smuggleDropoffBlip = nil
local smuggleRadiusBlip = nil
local smuggleCarStolen = false

-- ===================================================
-- HELPER: Lation UI notification
-- ===================================================
local function notify(title, message, nType, icon)
    exports.lation_ui:notify({
        title = title,
        message = message,
        type = nType or 'info',
        icon = icon,
        duration = 5000,
        position = 'top',
    })
end

-- ===================================================
-- HELPER: Spawn a ped (with error handling)
-- ===================================================
local function spawnPed(model, coords)
    if not model or not coords then return nil end
    
    lib.requestModel(model)
    local ped = CreatePed(0, model, coords.x, coords.y, coords.z, coords.w, false, true)
    
    if not DoesEntityExist(ped) then
        return nil
    end
    
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    return ped
end

-- ===================================================
-- HELPER: Create a blip
-- ===================================================
local function createBlip(coords, blipConfig)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipConfig.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipConfig.scale)
    SetBlipColour(blip, blipConfig.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipConfig.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ===================================================
-- HELPER: Create a radius blip (circle)
-- ===================================================
local function createRadiusBlip(coords, radius, color)
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    SetBlipHighDetail(blip, true)
    SetBlipColour(blip, color)
    SetBlipAlpha(blip, 80)
    return blip
end

-- ===================================================
-- HELPER: Set waypoint
-- ===================================================
local function setWaypoint(coords)
    SetNewWaypoint(coords.x, coords.y)
end

-- ===================================================
-- HELPER: Attach delivery prop to player hand
-- ===================================================
local function attachDeliveryProp()
    if deliveryPropObj then return end
    local cfg = Config.DeliveryProp
    lib.requestModel(cfg.model)
    local playerPed = PlayerPedId()
    deliveryPropObj = CreateObject(cfg.model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(deliveryPropObj, playerPed,
        GetPedBoneIndex(playerPed, cfg.bone),
        cfg.pos.x, cfg.pos.y, cfg.pos.z,
        cfg.rot.x, cfg.rot.y, cfg.rot.z,
        true, true, false, true, 0, true)
end

local function removeDeliveryProp()
    if deliveryPropObj and DoesEntityExist(deliveryPropObj) then
        DeleteEntity(deliveryPropObj)
    end
    deliveryPropObj = nil
end

-- ===================================================
-- HELPER: Start/stop carry animation
-- ===================================================
local function startCarryAnim()
    if carryAnimActive then return end
    carryAnimActive = true
    local dict = 'anim@heists@box_carry@'
    lib.requestAnimDict(dict)
    local playerPed = PlayerPedId()
    TaskPlayAnim(playerPed, dict, 'idle', 2.0, 2.0, -1, 49, 0, false, false, false)
end

local function stopCarryAnim()
    if not carryAnimActive then return end
    carryAnimActive = false
    local playerPed = PlayerPedId()
    StopAnimTask(playerPed, 'anim@heists@box_carry@', 'idle', 1.0)
end

-- ===================================================
-- HELPER: Put box in trunk (progress bar)
-- ===================================================
local function putBoxInTrunk(data)
    if boxInTrunk then return end
    if not activeTask or activeTask.type ~= 'delivery' then return end

    local vehicle = data.entity
    if not vehicle or not DoesEntityExist(vehicle) then return end

    stopCarryAnim()
    removeDeliveryProp()

    -- Open trunk
    SetVehicleDoorOpen(vehicle, 5, false, false)

    local success = exports.lation_ui:progressBar({
        label = 'Putting box in trunk...',
        duration = 3000,
        icon = 'fas fa-box-archive',
        iconAnimation = 'bounce',
        canCancel = false,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
    })

    if success then
        boxInTrunk = true
        SetVehicleDoorShut(vehicle, 5, false)
        notify('Delivery', 'Box placed in trunk.', 'info', 'fas fa-box-archive')

        local timelineId = 'ndrp_task_' .. activeTask.id
        exports.lation_ui:updateTimelineTask(timelineId, {
            { id = 'pickup', status = 'completed' },
            { id = 'trunk',  status = 'completed' },
            { id = 'drive',  status = 'active' },
        })
    end
end

-- ===================================================
-- HELPER: Take box from trunk (progress bar)
-- ===================================================
local function takeBoxFromTrunk(data)
    if not boxInTrunk then return end
    if not activeTask or activeTask.type ~= 'delivery' then return end

    local vehicle = data.entity
    if not vehicle or not DoesEntityExist(vehicle) then return end

    SetVehicleDoorOpen(vehicle, 5, false, false)

    local success = exports.lation_ui:progressBar({
        label = 'Taking box from trunk...',
        duration = 3000,
        icon = 'fas fa-box-open',
        iconAnimation = 'bounce',
        canCancel = false,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
    })

    if success then
        boxInTrunk = false
        if DoesEntityExist(vehicle) then
            SetVehicleDoorShut(vehicle, 5, false)
        end
        attachDeliveryProp()
        startCarryAnim()
        notify('Delivery', 'Box taken from trunk.', 'info', 'fas fa-box')

        local timelineId = 'ndrp_task_' .. activeTask.id
        exports.lation_ui:updateTimelineTask(timelineId, {
            { id = 'pickup', status = 'completed' },
            { id = 'trunk',  status = 'completed' },
            { id = 'drive',  status = 'completed' },
            { id = 'unload', status = 'completed' },
            { id = 'deliver', status = 'active' },
        })
    end
end

-- ===================================================
-- CLEANUP: Delivery
-- ===================================================
local function cleanupDelivery()
    if dropoffPed and DoesEntityExist(dropoffPed) then
        exports.ox_target:removeLocalEntity(dropoffPed, 'ndrp_tasks_dropoff')
        DeleteEntity(dropoffPed)
        dropoffPed = nil
    end
    if dropoffBlip then RemoveBlip(dropoffBlip); dropoffBlip = nil end
    stopCarryAnim()
    removeDeliveryProp()
    boxInTrunk = false
    carryAnimActive = false
    -- Remove global vehicle trunk targets
    pcall(function() exports.ox_target:removeGlobalVehicle('ndrp_tasks_trunk_put') end)
    pcall(function() exports.ox_target:removeGlobalVehicle('ndrp_tasks_trunk_take') end)
end

-- ===================================================
-- CLEANUP: Scavenge
-- ===================================================
local function cleanupScavenge()
    for i, prop in ipairs(spawnedProps) do
        if prop.entity and DoesEntityExist(prop.entity) then
            exports.ox_target:removeLocalEntity(prop.entity, 'ndrp_tasks_box_' .. i)
            DeleteEntity(prop.entity)
        end
    end
    spawnedProps = {}
    if searchAreaBlip then RemoveBlip(searchAreaBlip); searchAreaBlip = nil end
    if searchRadiusBlip then RemoveBlip(searchRadiusBlip); searchRadiusBlip = nil end
    boxesSearched = 0
    totalItems = 0
end

-- ===================================================
-- CLEANUP: Car theft
-- ===================================================
local function cleanupCarTheft()
    if theftGuard and DoesEntityExist(theftGuard) then
        DeleteEntity(theftGuard)
        theftGuard = nil
    end
    if theftCar and DoesEntityExist(theftCar) then
        if not IsPedInVehicle(PlayerPedId(), theftCar, false) then
            DeleteEntity(theftCar)
        else
            SetEntityAsMissionEntity(theftCar, false, true)
        end
        theftCar = nil
    end
    if theftCarBlip then RemoveBlip(theftCarBlip); theftCarBlip = nil end
    if theftDeliveryBlip then RemoveBlip(theftDeliveryBlip); theftDeliveryBlip = nil end
    if theftRadiusBlip then RemoveBlip(theftRadiusBlip); theftRadiusBlip = nil end
    guardDefeated = false
    carStolen = false
end

-- ===================================================
-- CLEANUP: Smuggle
-- ===================================================
local function cleanupSmuggle()
    if smuggleDropoffPed and DoesEntityExist(smuggleDropoffPed) then
        exports.ox_target:removeLocalEntity(smuggleDropoffPed, 'ndrp_tasks_smuggle_dropoff')
        DeleteEntity(smuggleDropoffPed)
        smuggleDropoffPed = nil
    end
    if smuggleVehicle and DoesEntityExist(smuggleVehicle) then
        if not IsPedInVehicle(PlayerPedId(), smuggleVehicle, false) then
            DeleteEntity(smuggleVehicle)
        else
            SetEntityAsMissionEntity(smuggleVehicle, false, true)
        end
        smuggleVehicle = nil
    end
    if smuggleVehicleBlip then RemoveBlip(smuggleVehicleBlip); smuggleVehicleBlip = nil end
    if smuggleDropoffBlip then RemoveBlip(smuggleDropoffBlip); smuggleDropoffBlip = nil end
    if smuggleRadiusBlip then RemoveBlip(smuggleRadiusBlip); smuggleRadiusBlip = nil end
    smuggleCarStolen = false
end

-- ===================================================
-- RESET: All task state
-- ===================================================
local function resetTask()
    cleanupDelivery()
    cleanupScavenge()
    cleanupCarTheft()
    cleanupSmuggle()
    activeTask = nil
    activeCategory = nil
    hasPickedUp = false
    taskInProgress = false
    scavengedItemsCount = 0
end

-- ===================================================
-- FAIL: Mission failed
-- ===================================================
local function failMission(reason)
    if not taskInProgress then return end

    notify('Mission Failed!', reason or 'You failed the mission.', 'error', 'fas fa-skull')

    local itemToRemove = nil
    local amountToRemove = 0

    if activeTask then
        pcall(function()
            exports.lation_ui:hideTimeline('ndrp_task_' .. activeTask.id)
        end)

        if activeTask.type == 'delivery' and hasPickedUp then
            itemToRemove = activeTask.item
            amountToRemove = 1
        elseif activeTask.type == 'scavenge' and scavengedItemsCount > 0 then
            itemToRemove = activeTask.item
            amountToRemove = scavengedItemsCount
        end
    end

    lib.callback.await('ndrp_tasks:failMission', false, itemToRemove, amountToRemove)
    resetTask()
end

-- ===================================================
-- COMPLETE: Mission completed
-- ===================================================
local function completeMission(reward)
    if not taskInProgress or not activeCategory then return end

    local xpReward = activeCategory.xpReward or 0
    local success, newXP, newLevel = lib.callback.await('ndrp_tasks:completeMission', false, reward, xpReward)

    if success then
        if newXP and newLevel then
            notify('XP', ('+%d XP — Nivå %d'):format(xpReward, newLevel), 'success', 'fas fa-star')
        end
    end
end

-- ===================================================
-- NUI: Open task menu
-- ===================================================
local function openTaskMenu()
    -- Fetch stats + cooldown from server
    local stats = lib.callback.await('ndrp_tasks:getStats', false)
    local cooldown = lib.callback.await('ndrp_tasks:getCooldown', false)

    local nuiCategories = {}
    for _, cat in ipairs(Config.Categories) do
        nuiCategories[#nuiCategories + 1] = {
            id = cat.id,
            name = cat.name,
            description = cat.description,
            icon = cat.icon,
            reward = cat.reward,
            difficulty = cat.difficulty or '',
            requiredLevel = cat.requiredLevel or 1,
            locked = (stats.level or 1) < (cat.requiredLevel or 1),
        }
    end

    SendNUIMessage({
        action = 'showTaskMenu',
        tasks = nuiCategories,
        stats = stats,
        cooldown = cooldown or 0,
    })
    SetNuiFocus(true, true)
end

-- ===================================================
-- NUI: Close task menu
-- ===================================================
local function closeTaskMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideTaskMenu' })
end

-- Forward declaration
local onDropoff

-- ===================================================
-- START: Delivery task
-- ===================================================
local function startDeliveryTask()
    local itemGiven = lib.callback.await('ndrp_tasks:pickupItem', false, activeTask.item)
    if not itemGiven then
        notify('Task', 'Could not start the mission.', 'error')
        lib.callback.await('ndrp_tasks:failMission', false)
        resetTask()
        return
    end

    hasPickedUp = true
    boxInTrunk = false

    -- Attach delivery prop + carry animation
    attachDeliveryProp()
    startCarryAnim()

    exports.lation_ui:showTimeline({
        id = 'ndrp_task_' .. activeTask.id,
        title = activeTask.name,
        description = activeTask.description,
        position = Config.Timeline.position,
        icon = Config.Timeline.icon,
        iconColor = Config.Timeline.iconColor,
        opacity = Config.Timeline.opacity,
        tasks = {
            { id = 'pickup',  label = 'Pick Up Delivery',   description = 'Package received', status = 'completed', icon = 'fas fa-box' },
            { id = 'trunk',   label = 'Put In Trunk',     description = 'Place package in trunk', status = 'active', icon = 'fas fa-car-side' },
            { id = 'drive',   label = 'Drive To Dropoff', description = 'Follow GPS', status = 'pending', icon = 'fas fa-location-dot' },
            { id = 'unload',  label = 'Take From Trunk',   description = 'Remove box at dropoff', status = 'pending', icon = 'fas fa-box-open' },
            { id = 'deliver', label = 'Deliver Package',   description = 'Hand over to customer', status = 'pending', icon = 'fas fa-flag-checkered' },
        },
    })

    dropoffPed = spawnPed(activeTask.dropoff.pedModel, activeTask.dropoff.coords)
    dropoffBlip = createBlip(activeTask.dropoff.coords, activeTask.dropoff.blip)

    if dropoffPed then
        exports.ox_target:addLocalEntity(dropoffPed, {
            {
                name = 'ndrp_tasks_dropoff',
                icon = 'fas fa-box-open',
                label = 'Drop Off Delivery',
                onSelect = function() onDropoff() end,
                distance = 2.5,
            },
        })
    end

    setWaypoint(activeTask.dropoff.coords)
    notify('Uppdrag accepterat!', activeTask.name .. ' - Lägg lådan i bagaget på ett fordon.', 'success', 'fas fa-check')

    -- Add global vehicle target for trunk interactions
    exports.ox_target:addGlobalVehicle({
        {
            name = 'ndrp_tasks_trunk_put',
            icon = 'fas fa-box-archive',
            label = 'Put Box In Trunk',
            bones = { 'boot' },
            onSelect = putBoxInTrunk,
            distance = 2.5,
            canInteract = function()
                return activeTask and activeTask.type == 'delivery' and not boxInTrunk and deliveryPropObj ~= nil
            end,
        },
        {
            name = 'ndrp_tasks_trunk_take',
            icon = 'fas fa-box-open',
            label = 'Take Box From Trunk',
            bones = { 'boot' },
            onSelect = takeBoxFromTrunk,
            distance = 2.5,
            canInteract = function()
                return activeTask and activeTask.type == 'delivery' and boxInTrunk
            end,
        },
    })
end

-- ===================================================
-- START: Scavenge task
-- ===================================================
local function startScavengeTask()
    local area = activeTask.searchArea

    exports.lation_ui:showTimeline({
        id = 'ndrp_task_' .. activeTask.id,
        title = activeTask.name,
        description = activeTask.description,
        position = Config.Timeline.position,
        icon = 'fas fa-magnifying-glass',
        iconColor = Config.Timeline.iconColor,
        opacity = Config.Timeline.opacity,
        tasks = {
            { id = 'drive',  label = 'Kör till sökområdet',  description = 'Följ GPS:en', status = 'active', icon = 'fas fa-location-dot' },
            { id = 'search', label = 'Sök igenom lådor',     description = 'Hitta material i lådorna', status = 'pending', icon = 'fas fa-magnifying-glass' },
            { id = 'done',   label = 'Samling klar',          description = 'Ta med dig bytet', status = 'pending', icon = 'fas fa-check' },
        },
    })

    searchAreaBlip = createBlip(area.center, area.blip)
    searchRadiusBlip = createRadiusBlip(area.center, area.radius, area.blip.color)

    local propModel = activeTask.props.model
    lib.requestModel(propModel)

    for i, pos in ipairs(activeTask.props.locations) do
        local obj = CreateObject(propModel, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(obj, pos.w)
        FreezeEntityPosition(obj, true)
        PlaceObjectOnGroundProperly(obj)

        local propData = { entity = obj, searched = false, index = i }
        spawnedProps[#spawnedProps + 1] = propData
    end

    -- Main search loop
    CreateThread(function()
        local boxesSearched = 0
        scavengedItemsCount = 0

        while activeTask and activeTask.type == 'scavenge' and taskInProgress do
            local playerCoords = GetEntityCoords(PlayerPedId())
            for _, propData in ipairs(spawnedProps) do
                if not propData.searched and DoesEntityExist(propData.entity) then
                    local propName = 'ndrp_tasks_box_' .. propData.index
                    -- Ensure target exists as long as not searched
                    exports.ox_target:addLocalEntity(propData.entity, {
                        {
                            name = propName,
                            icon = 'fas fa-magnifying-glass',
                            label = 'Search Box',
                            onSelect = function()
                                if propData.searched then
                                    notify('Uppdrag', 'Redan genomsökt.', 'error')
                                    return
                                end

                                local progressCfg = activeTask.progress.search
                                local success = exports.lation_ui:progressBar({
                                    label = progressCfg.label,
                                    description = 'Undersöker innehållet...',
                                    duration = progressCfg.duration,
                                    icon = progressCfg.icon,
                                    iconAnimation = 'spin',
                                    canCancel = true,
                                    steps = progressCfg.steps,
                                    disable = { car = true, move = true, combat = true },
                                    anim = { dict = progressCfg.anim.dict, clip = progressCfg.anim.clip },
                                })

                                if success then
                                    local amount = math.random(activeTask.itemMin, activeTask.itemMax)
                                    local given = lib.callback.await('ndrp_tasks:giveItem', false, activeTask.item, amount)

                                    if given then
                                        propData.searched = true
                                        boxesSearched = boxesSearched + 1
                                        scavengedItemsCount = scavengedItemsCount + amount

                                        notify('Material Found!', ('You found %dx %s. (Total: %d)'):format(amount, activeTask.item, scavengedItemsCount), 'success', 'fas fa-cubes-stacked')

                                        local timelineId = 'ndrp_task_' .. activeTask.id
                                        if boxesSearched >= #spawnedProps then
                                            exports.lation_ui:updateTimelineTask(timelineId, {
                                                { id = 'drive',  status = 'completed' },
                                                { id = 'search', status = 'completed' },
                                                { id = 'done',   status = 'completed' },
                                            })

                                            notify('Task Complete!', ('You got %s kr + %dx %s.'):format(activeTask.reward, scavengedItemsCount, activeTask.item), 'success', 'fas fa-trophy')

                                            completeMission(activeTask.reward)

                                            SetTimeout(3000, function()
                                                exports.lation_ui:hideTimeline(timelineId)
                                                resetTask()
                                            end)
                                        else
                                            exports.lation_ui:updateTimelineTask(timelineId, {
                                                { id = 'drive',  status = 'completed' },
                                                { id = 'search', status = 'active' },
                                            })
                                        end

                                        if DoesEntityExist(propData.entity) then
                                            exports.ox_target:removeLocalEntity(propData.entity, propName)
                                            DeleteEntity(propData.entity)
                                        end
                                    else
                                        notify('Task', 'Something went wrong.', 'error')
                                    end
                                else
                                    notify('Task', 'Cancelled.', 'error')
                                end
                            end,
                            distance = 2.0,
                        },
                    })
                end
            end
            Wait(1000)
        end
    end)

    setWaypoint(area.center)
    notify('Task Accepted!', activeTask.name .. ' - Follow GPS.', 'success', 'fas fa-check')

    -- Detect arrival
    CreateThread(function()
        local arrived = false
        while activeTask and activeTask.type == 'scavenge' and not arrived do
            local playerCoords = GetEntityCoords(PlayerPedId())
            if #(playerCoords - area.center) < area.radius then
                arrived = true
                exports.lation_ui:updateTimelineTask('ndrp_task_' .. activeTask.id, {
                    { id = 'drive',  status = 'completed' },
                    { id = 'search', status = 'active' },
                })
            end
            Wait(1000)
        end
    end)
end

-- ===================================================
-- START: Car theft task
-- ===================================================
local function startCarTheftTask()
    local carCfg = activeTask.car
    local guardCfg = activeTask.guard
    local timelineId = 'ndrp_task_' .. activeTask.id

    exports.lation_ui:showTimeline({
        id = timelineId,
        title = activeTask.name,
        description = activeTask.description,
        position = Config.Timeline.position,
        icon = 'fas fa-car',
        iconColor = Config.Timeline.iconColor,
        opacity = Config.Timeline.opacity,
        tasks = {
            { id = 'drive',   label = 'Drive To Vehicle',   description = 'Follow GPS', status = 'active', icon = 'fas fa-location-dot' },
            { id = 'fight',   label = 'Defeat Guard',        description = 'Guard is armed', status = 'pending', icon = 'fas fa-fist-raised' },
            { id = 'steal',   label = 'Steal Vehicle',       description = 'Get in', status = 'pending', icon = 'fas fa-car' },
            { id = 'deliver', label = 'Deliver Vehicle',     description = 'Drive to dropoff', status = 'pending', icon = 'fas fa-flag-checkered' },
        },
    })

    -- Spawn car
    lib.requestModel(carCfg.model)
    theftCar = CreateVehicle(carCfg.model, carCfg.coords.x, carCfg.coords.y, carCfg.coords.z, carCfg.coords.w, true, false)
    SetEntityAsMissionEntity(theftCar, true, true)
    SetVehicleDoorsLocked(theftCar, 2)
    SetVehicleOnGroundProperly(theftCar)

    -- Spawn guard
    lib.requestModel(guardCfg.model)
    theftGuard = CreatePed(4, guardCfg.model, guardCfg.offset.x, guardCfg.offset.y, guardCfg.offset.z, guardCfg.offset.w, true, true)
    SetEntityAsMissionEntity(theftGuard, true, true)
    FreezeEntityPosition(theftGuard, false)
    SetEntityInvincible(theftGuard, false)
    SetPedMaxHealth(theftGuard, 200)
    SetEntityHealth(theftGuard, 200)
    GiveWeaponToPed(theftGuard, GetHashKey(guardCfg.weapon), 1, false, true)
    SetCurrentPedWeapon(theftGuard, GetHashKey(guardCfg.weapon), true)
    SetBlockingOfNonTemporaryEvents(theftGuard, true)
    SetPedFleeAttributes(theftGuard, 0, false)
    SetPedCombatAttributes(theftGuard, 46, true)
    SetPedCombatAttributes(theftGuard, 5, true)
    SetPedCombatMovement(theftGuard, 2)
    SetPedCombatRange(theftGuard, 2)

    theftCarBlip = createBlip(carCfg.coords, carCfg.blip)
    setWaypoint(carCfg.coords)

    notify('Task Accepted!', activeTask.name .. ' - Watch out for the guard!', 'warning', 'fas fa-skull-crossbones')

    -- Main loop
    CreateThread(function()
        local arrivedAtCar = false
        local guardEngaged = false

        while activeTask and activeTask.type == 'cartheft' do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            -- Check player death
            if IsEntityDead(playerPed) then
                failMission('Du dog under uppdraget.')
                break
            end

            -- Check car destroyed
            if carStolen and theftCar and DoesEntityExist(theftCar) and IsVehicleDriveable(theftCar) == false then
                failMission('Vehicle was destroyed!')
                break
            end

            -- Phase 1: Arrival
            if not arrivedAtCar and theftCar and DoesEntityExist(theftCar) then
                if #(playerCoords - GetEntityCoords(theftCar)) < 50.0 then
                    arrivedAtCar = true
                    exports.lation_ui:updateTimelineTask(timelineId, {
                        { id = 'drive', status = 'completed' },
                        { id = 'fight', status = 'active' },
                    })
                    if theftGuard and DoesEntityExist(theftGuard) then
                        TaskCombatPed(theftGuard, playerPed, 0, 16)
                        guardEngaged = true
                        notify('Warning!', 'Guard has spotted you!', 'warning', 'fas fa-triangle-exclamation')
                    end
                end
            end

            -- Phase 2: Guard defeated
            if guardEngaged and not guardDefeated and theftGuard then
                if not DoesEntityExist(theftGuard) or IsEntityDead(theftGuard) then
                    guardDefeated = true
                    exports.lation_ui:updateTimelineTask(timelineId, {
                        { id = 'drive', status = 'completed' },
                        { id = 'fight', status = 'completed' },
                        { id = 'steal', status = 'active' },
                    })
                    if theftCar and DoesEntityExist(theftCar) then
                        SetVehicleDoorsLocked(theftCar, 1)
                    end
                    notify('Guard Defeated!', 'Vehicle is unlocked.', 'success', 'fas fa-unlock')
                    if theftGuard and DoesEntityExist(theftGuard) then
                        SetTimeout(5000, function()
                            if theftGuard and DoesEntityExist(theftGuard) then
                                DeleteEntity(theftGuard)
                                theftGuard = nil
                            end
                        end)
                    end
                end
            end

            -- Phase 3: Car stolen
            if guardDefeated and not carStolen and theftCar and DoesEntityExist(theftCar) then
                if IsPedInVehicle(playerPed, theftCar, false) then
                    carStolen = true
                    if theftCarBlip then RemoveBlip(theftCarBlip); theftCarBlip = nil end

                    local delivery = activeTask.delivery
                    theftDeliveryBlip = createBlip(delivery.center, delivery.blip)
                    theftRadiusBlip = createRadiusBlip(delivery.center, delivery.radius, delivery.blip.color)
                    setWaypoint(delivery.center)

                    exports.lation_ui:updateTimelineTask(timelineId, {
                        { id = 'drive',   status = 'completed' },
                        { id = 'fight',   status = 'completed' },
                        { id = 'steal',   status = 'completed' },
                        { id = 'deliver', status = 'active' },
                    })
                        notify('Vehicle Stolen!', 'Drive to the dropoff.', 'success', 'fas fa-car')
                end
            end

            -- Phase 4: Delivery with damage penalty
            if carStolen and theftCar and DoesEntityExist(theftCar) then
                local delivery = activeTask.delivery
                if #(playerCoords - delivery.center) < delivery.radius then
                    if IsPedInVehicle(playerPed, theftCar, false) then
                        exports.lation_ui:updateTimelineTask(timelineId, {
                            { id = 'drive',   status = 'completed' },
                            { id = 'fight',   status = 'completed' },
                            { id = 'steal',   status = 'completed' },
                            { id = 'deliver', status = 'completed' },
                        })

                        -- Calculate damage penalty
                        local bodyHealth = GetVehicleBodyHealth(theftCar)
                        local healthPercent = math.max(0, math.min(100, bodyHealth / 10))
                        local baseReward = activeTask.reward
                        local actualReward = math.floor(baseReward * (healthPercent / 100))

                        TaskLeaveVehicle(playerPed, theftCar, 0)
                        Wait(2000)

                        -- Remove car key
                        if theftCar and DoesEntityExist(theftCar) then
                            local plate = GetVehicleNumberPlateText(theftCar)
                            if plate then
                                exports.wasabi_carlock:RemoveKey(plate)
                            end
                        end

                        -- Notification with damage info
                        if healthPercent < 100 then
                            notify('Uppdrag klart!', ('Fordonsskick: %d%% — Du fick %d kr (av %d kr)'):format(math.floor(healthPercent), actualReward, baseReward), 'success', 'fas fa-trophy')
                        else
                            notify('Task Complete!', ('Perfect Condition! You got %d kr.'):format(actualReward), 'success', 'fas fa-trophy')
                        end

                        completeMission(actualReward)

                        SetTimeout(3000, function()
                            if theftCar and DoesEntityExist(theftCar) then
                                DeleteEntity(theftCar)
                                theftCar = nil
                            end
                            exports.lation_ui:hideTimeline(timelineId)
                            resetTask()
                        end)
                        break
                    else
                        notify('Task', 'You must be in the vehicle!', 'warning')
                        Wait(3000)
                    end
                end
            end

            Wait(500)
        end
    end)
end

-- ===================================================
-- START: Smuggle task
-- ===================================================
local function startSmuggleTask()
    local vehCfg = activeTask.vehicle
    local deliveryCfg = activeTask.delivery
    local timelineId = 'ndrp_task_' .. activeTask.id

    exports.lation_ui:showTimeline({
        id = timelineId,
        title = activeTask.name,
        description = activeTask.description,
        position = Config.Timeline.position,
        icon = 'fas fa-vault',
        iconColor = '#F59E0B',
        opacity = Config.Timeline.opacity,
        tasks = {
            { id = 'drive',   label = 'Get Smuggler Vehicle', description = 'Follow GPS', status = 'active', icon = 'fas fa-location-dot' },
            { id = 'steal',   label = 'Get In Vehicle',     description = 'Cargo already in truck', status = 'pending', icon = 'fas fa-truck' },
            { id = 'deliver', label = 'Deliver Cargo',       description = 'Drive to dropoff', status = 'pending', icon = 'fas fa-flag-checkered' },
            { id = 'unload',  label = 'Unload',              description = 'Hand over goods', status = 'pending', icon = 'fas fa-boxes-packing' },
        },
    })

    -- Spawn vehicle
    lib.requestModel(vehCfg.model)
    smuggleVehicle = CreateVehicle(vehCfg.model, vehCfg.coords.x, vehCfg.coords.y, vehCfg.coords.z, vehCfg.coords.w, true, false)
    SetEntityAsMissionEntity(smuggleVehicle, true, true)
    SetVehicleDoorsLocked(smuggleVehicle, 1) -- Unlocked
    SetVehicleOnGroundProperly(smuggleVehicle)
    
    -- Give player keys so wasabi_carlock recognizes it
    local plate = GetVehicleNumberPlateText(smuggleVehicle)
    if plate then
        exports.wasabi_carlock:GiveKey(plate)
    end

    smuggleVehicleBlip = createBlip(vehCfg.coords, vehCfg.blip)
    setWaypoint(vehCfg.coords)

    notify('Task Accepted!', activeTask.name .. ' - Get the vehicle.', 'warning', 'fas fa-vault')

    -- Main loop
    CreateThread(function()
        while activeTask and activeTask.type == 'smuggle' do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            -- Check death
            if IsEntityDead(playerPed) then
                failMission('Du dog under uppdraget.')
                break
            end

            -- Check vehicle destroyed
            if smuggleCarStolen and smuggleVehicle and DoesEntityExist(smuggleVehicle) and not IsVehicleDriveable(smuggleVehicle) then
                failMission('Smuggler vehicle was destroyed!')
                break
            end

            -- Phase 1: Player enters vehicle
            if not smuggleCarStolen and smuggleVehicle and DoesEntityExist(smuggleVehicle) then
                if IsPedInVehicle(playerPed, smuggleVehicle, false) then
                    smuggleCarStolen = true

                    if smuggleVehicleBlip then RemoveBlip(smuggleVehicleBlip); smuggleVehicleBlip = nil end

                    -- Spawn dropoff ped + blips
                    smuggleDropoffPed = spawnPed(deliveryCfg.pedModel, deliveryCfg.coords)
                    smuggleDropoffBlip = createBlip(deliveryCfg.coords, deliveryCfg.blip)
                    smuggleRadiusBlip = createRadiusBlip(deliveryCfg.coords, deliveryCfg.radius, deliveryCfg.blip.color)
                    setWaypoint(deliveryCfg.coords)

                    exports.lation_ui:updateTimelineTask(timelineId, {
                        { id = 'drive', status = 'completed' },
                        { id = 'steal', status = 'completed' },
                        { id = 'deliver', status = 'active' },
                    })

                    notify('Vehicle Acquired!', 'Drive to dropoff. Be careful.', 'success', 'fas fa-truck')
                end
            end

            -- Phase 2: Arrival at delivery radius
            if smuggleCarStolen and smuggleVehicle and DoesEntityExist(smuggleVehicle) then
                if #(playerCoords - vector3(deliveryCfg.coords.x, deliveryCfg.coords.y, deliveryCfg.coords.z)) < deliveryCfg.radius then
                    if IsPedInVehicle(playerPed, smuggleVehicle, false) then
                        exports.lation_ui:updateTimelineTask(timelineId, {
                            { id = 'drive',   status = 'completed' },
                            { id = 'steal',   status = 'completed' },
                            { id = 'deliver', status = 'completed' },
                            { id = 'unload',  status = 'active' },
                        })

                        TaskLeaveVehicle(playerPed, smuggleVehicle, 0)
                        Wait(2000)

                        -- Remove car key
                        if smuggleVehicle and DoesEntityExist(smuggleVehicle) then
                            local plate = GetVehicleNumberPlateText(smuggleVehicle)
                            if plate then
                                exports.wasabi_carlock:RemoveKey(plate)
                            end
                        end

                        -- Progress bar with NPC dialogue (unloading)
                        local progressCfg = activeTask.progress.dropoff
                        local success = exports.lation_ui:progressBar({
                            label = progressCfg.label,
                            description = 'Överlämnar godset till köparen...',
                            duration = progressCfg.duration,
                            icon = progressCfg.icon,
                            iconAnimation = 'spin',
                            canCancel = false,
                            steps = progressCfg.steps,
                            disable = { car = true, move = true, combat = true },
                            anim = { dict = progressCfg.anim.dict, clip = progressCfg.anim.clip },
                            prop = {
                                model = 'prop_box_ammo04a',
                                bone = 57005,
                                pos = { x = 0.14, y = 0.04, z = -0.04 },
                                rot = { x = -90.0, y = 0.0, z = 0.0 },
                            },
                        })

                        if success then
                            -- Damage penalty for smuggle too
                            local bodyHealth = GetVehicleBodyHealth(smuggleVehicle)
                            local healthPercent = math.max(0, math.min(100, bodyHealth / 10))
                            local actualReward = math.floor(activeTask.reward * (healthPercent / 100))

                            exports.lation_ui:updateTimelineTask(timelineId, {
                                { id = 'drive',   status = 'completed' },
                                { id = 'steal',   status = 'completed' },
                                { id = 'deliver', status = 'completed' },
                                { id = 'unload',  status = 'completed' },
                            })

                            if healthPercent < 100 then
                                notify('Uppdrag klart!', ('Fordonsskick: %d%% — Du fick %d kr (av %d kr)'):format(math.floor(healthPercent), actualReward, activeTask.reward), 'success', 'fas fa-trophy')
                            else
                                notify('Task Complete!', ('Perfect Delivery! You got %d kr.'):format(actualReward), 'success', 'fas fa-trophy')
                            end

                            completeMission(actualReward)

                            SetTimeout(3000, function()
                                if smuggleVehicle and DoesEntityExist(smuggleVehicle) then
                                    DeleteEntity(smuggleVehicle)
                                    smuggleVehicle = nil
                                end
                                exports.lation_ui:hideTimeline(timelineId)
                                resetTask()
                            end)
                        end
                        break
                    else
                        notify('Task', 'Park vehicle in dropoff area!', 'warning')
                        Wait(3000)
                    end
                end
            end

            Wait(500)
        end
    end)
end

-- ===================================================
-- NUI CALLBACK: Task selected (category clicked)
-- ===================================================
RegisterNUICallback('taskSelected', function(data, cb)
    closeTaskMenu()
    cb('ok')

    if taskInProgress then
        notify('Task', 'You already have an active mission.', 'error')
        return
    end

    -- Find the clicked category
    local category = nil
    for _, cat in ipairs(Config.Categories) do
        if cat.id == data.taskId then
            category = cat
            break
        end
    end

    if not category or not category.missions or #category.missions == 0 then return end

    -- Server-side check: cooldown, level, one-mission
    local canStart, reason, extra = lib.callback.await('ndrp_tasks:canStartMission', false, category.requiredLevel or 1)

    if not canStart then
        if reason == 'already_active' then
            notify('Task', 'You already have an active mission.', 'error')
        elseif reason == 'cooldown' then
            local mins = math.ceil((extra or 0) / 60)
            notify('Cooldown', ('Wait %d minutes before next task.'):format(mins), 'warning', 'fas fa-clock')
        elseif reason == 'level_required' then
            notify('Locked', ('Requires level %d.'):format(extra or 2), 'error', 'fas fa-lock')
        end
        return
    end

    -- Pick random mission from pool
    local mission = category.missions[math.random(#category.missions)]

    activeCategory = category
    activeTask = {
        id = category.id .. '_' .. math.random(99999),
        name = mission.name or category.name,
        description = category.description,
        type = mission.type,
        reward = mission.reward,
        item = mission.item,
        dropoff = mission.dropoff,
        progress = mission.progress,
        searchArea = mission.searchArea,
        props = mission.props,
        itemMin = mission.itemMin,
        itemMax = mission.itemMax,
        car = mission.car,
        guard = mission.guard,
        delivery = mission.delivery,
        vehicle = mission.vehicle,
    }
    taskInProgress = true
    hasPickedUp = false

    notify('Task', 'You have: ' .. activeTask.name, 'info', category.icon)

    if activeTask.type == 'delivery' then
        startDeliveryTask()
    elseif activeTask.type == 'scavenge' then
        startScavengeTask()
    elseif activeTask.type == 'cartheft' then
        startCarTheftTask()
    elseif activeTask.type == 'smuggle' then
        startSmuggleTask()
    end
end)

-- ===================================================
-- NUI CALLBACK: Close menu
-- ===================================================
RegisterNUICallback('closeMenu', function(_, cb)
    closeTaskMenu()
    cb('ok')
end)

-- ===================================================
-- DROPOFF: Delivery tasks
-- ===================================================
onDropoff = function()
    if not activeTask or not hasPickedUp then
        notify('Task', 'You have nothing to hand over.', 'error')
        return
    end

    -- Must have the box in hand (not in trunk)
    if boxInTrunk then
        notify('Task', 'Take the box from the trunk first!', 'warning', 'fas fa-box')
        return
    end

    -- Stop carry anim for delivery interaction
    stopCarryAnim()

    local progressCfg = activeTask.progress.dropoff
    local success = exports.lation_ui:progressBar({
        label = progressCfg.label,
        description = 'Överlämnar paketet...',
        duration = progressCfg.duration,
        icon = progressCfg.icon,
        iconAnimation = 'spin',
        canCancel = true,
        steps = progressCfg.steps,
        disable = { car = true, move = true, combat = true },
        anim = { dict = progressCfg.anim.dict, clip = progressCfg.anim.clip },
    })

    if success then
        local completed = lib.callback.await('ndrp_tasks:dropoffItem', false, activeTask.item)
        if completed then
            removeDeliveryProp()

            local timelineId = 'ndrp_task_' .. activeTask.id
            exports.lation_ui:updateTimelineTask(timelineId, {
                { id = 'pickup',  status = 'completed' },
                { id = 'trunk',   status = 'completed' },
                { id = 'drive',   status = 'completed' },
                { id = 'unload',  status = 'completed' },
                { id = 'deliver', status = 'completed' },
            })

            notify('Task Complete!', ('You got %s kr.'):format(activeTask.reward), 'success', 'fas fa-trophy')

            completeMission(activeTask.reward)

            local taskId = activeTask.id
            SetTimeout(3000, function()
                exports.lation_ui:hideTimeline('ndrp_task_' .. taskId)
                resetTask()
            end)
        else
            notify('Task', 'Do you have the package?', 'error')
        end
    else
        notify('Task', 'Cancelled.', 'error')
        -- Resume carry anim if cancelled
        if not boxInTrunk and deliveryPropObj then
            startCarryAnim()
        end
    end
end

-- ===================================================
-- DEATH HANDLER: Fail mission on death
-- ===================================================
CreateThread(function()
    while true do
        Wait(1000)
        if taskInProgress and activeTask then
            local playerPed = PlayerPedId()
            if IsEntityDead(playerPed) then
                -- Only fail for types without their own death check
                if activeTask.type == 'delivery' or activeTask.type == 'scavenge' then
                    failMission('Du dog under uppdraget.')
                end
            end
        end
    end
end)

-- ===================================================
-- CANCEL COMMAND: /avbryt
-- ===================================================
RegisterCommand('cancel', function()
    if not taskInProgress then
        notify('Task', 'You do not have an active mission.', 'error')
        return
    end

    failMission('You cancelled the mission.')
end, false)

-- ===================================================
-- SETUP: Station ped + blip + ox_target
-- ===================================================
CreateThread(function()
    local cfg = Config.Station

    stationPed = spawnPed(cfg.pedModel, cfg.coords)
    stationBlip = createBlip(cfg.coords, cfg.blip)

    if stationPed then
        exports.ox_target:addLocalEntity(stationPed, {
            {
                name = 'ndrp_tasks_station_menu',
                icon = cfg.interactIcon,
                label = cfg.interactLabel,
                onSelect = function()
                    if taskInProgress then
                        notify('Task', 'Complete your current mission first!', 'error')
                    else
                        openTaskMenu()
                    end
                end,
                distance = 2.5,
            },
        })
    end
end)

-- ===================================================
-- DEBUG COMMANDS (Disabled by default for production)
-- Uncomment to enable during development
-- ===================================================
-- RegisterCommand('testnui', function()
--     openTaskMenu()
-- end, false)
-- 
-- RegisterCommand('closenui', function()
--     SetNuiFocus(false, false)
--     SendNUIMessage({ action = 'hideTaskMenu' })
-- end, false)

-- ===================================================
-- CLEANUP: on resource stop
-- ===================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if stationPed and DoesEntityExist(stationPed) then DeleteEntity(stationPed) end
    if stationBlip then RemoveBlip(stationBlip) end

    cleanupDelivery()
    cleanupScavenge()
    cleanupCarTheft()
    cleanupSmuggle()

    if activeTask then
        pcall(function() exports.lation_ui:hideTimeline('ndrp_task_' .. activeTask.id) end)
    end

    closeTaskMenu()
end)
