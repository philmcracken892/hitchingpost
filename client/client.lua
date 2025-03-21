local RSGCore = exports['rsg-core']:GetCoreObject()

local CHECK_RADIUS = 2.0
local HITCHING_POST_PROPS = {
    {
        label = "Hitching Post",
        model = `p_hitchingpost01x`, -- Replace with the correct model for the hitching post
        offset = vector3(0.0, 0.0, 0.0),
        description = "A sturdy hitching post for your horses"
    }
}

-- Variables
local deployedHitchingPost = nil
local deployedOwner = nil
local currentHitchingPostData = nil
local isHitching = false
local hitchedHorses = {} -- Track hitched horses

local function ShowHitchingPostMenu()
    local hitchingPostOptions = {}
    
    for i, hitchingPost in ipairs(HITCHING_POST_PROPS) do
        table.insert(hitchingPostOptions, {
            title = hitchingPost.label,
            description = hitchingPost.description,
            icon = 'fas fa-horse',
            onSelect = function()
                TriggerEvent('rsg-hitchingpost:client:placeHitchingPost', i)
            end
        })
    end

    lib.registerContext({
        id = 'hitchingpost_selection_menu',
        title = 'Select Hitching Post',
        options = hitchingPostOptions
    })
    
    lib.showContext('hitchingpost_selection_menu')
end


RegisterNetEvent('rsg-hitchingpost:client:openHitchingPostMenu', function()
    
    ExecuteCommand('closeInv')
    
    
    CreateThread(function()
        Wait(500) 
        ShowHitchingPostMenu()
    end)
end)

local function RegisterHitchingPostTargeting()
    local models = {}
    for _, hitchingPost in ipairs(HITCHING_POST_PROPS) do
        table.insert(models, hitchingPost.model)
    end

    exports['ox_target']:addModel(models, {
        {
            name = 'pickup_hitchingpost',
            event = 'rsg-hitchingpost:client:pickupHitchingPost',
            icon = "fas fa-hand",
            label = "Pick Up Hitching Post",
            distance = 2.0,
            canInteract = function(entity)
                return not isHitching
            end
        },
        {
            name = 'hitch_horse',
            event = 'rsg-hitchingpost:client:hitchHorse',
            icon = "fas fa-horse",
            label = "Hitch Horse",
            distance = 2.0,
            canInteract = function(entity)
                return not isHitching
            end
        },
        {
            name = 'unhitch_horse',
            event = 'rsg-hitchingpost:client:unhitchHorse',
            icon = "fas fa-external-link-alt",
            label = "Unhitch Horse",
            distance = 2.0,
            canInteract = function(entity)
                return not isHitching and #hitchedHorses > 0
            end
        },
    })
end

-- Modified to provide instant healing and stamina to horses when hitched
local function ApplyInstantHealing(horse)
    if not DoesEntityExist(horse) or IsEntityDead(horse) then return end
    
    -- Set horse to max health instantly
    local maxHealth = GetEntityMaxHealth(horse)
    SetEntityHealth(horse, maxHealth)
    
    -- Apply visual healing effect
    TriggerEvent("rsg-appearance:client:ApplyHorseHealthVisual", horse)
    
    -- Bond with the horse 
    Citizen.InvokeNative(0xD2CB0FB0FDCB473D, PlayerId(), horse)
    
    -- Fully restore stamina through server event 
    TriggerServerEvent('rsg-horses:server:RestoreHorseStamina', NetworkGetNetworkIdFromEntity(horse), 100) -- 100% restoration
    
    -- Apply gold core effect (visual indication)
    TriggerEvent("rsg-horses:client:HorseGoldCores", horse)
    
    -- Play a happy horse animation (optional)
    local animations = {
        "WORLD_ANIMAL_HORSE_DRINKING",
        "WORLD_ANIMAL_HORSE_GRAZING",
        "WORLD_ANIMAL_HORSE_RESTING"
    }
    local randomAnim = animations[math.random(#animations)]
    TaskStartScenarioInPlace(horse, GetHashKey(randomAnim), 3000, true, false, false, false)
    
    lib.notify({
        title = 'Horse Restored',
        description = 'Your horse has been instantly restored to full health and stamina',
        type = 'success'
    })
end

RegisterNetEvent('rsg-hitchingpost:client:placeHitchingPost', function(hitchingPostIndex)
    if deployedHitchingPost then
        lib.notify({
            title = "Hitching Post Already Placed",
            description = "You already have a hitching post placed.",
            type = 'error'
        })
        return
    end

    local hitchingPostData = HITCHING_POST_PROPS[hitchingPostIndex]
    if not hitchingPostData then return end

    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local forward = GetEntityForwardVector(PlayerPedId())
    
    local offsetDistance = 2.0
    local x = coords.x + forward.x * offsetDistance
    local y = coords.y + forward.y * offsetDistance
    local z = coords.z

    RequestModel(hitchingPostData.model)
    while not HasModelLoaded(hitchingPostData.model) do
        Wait(100)
    end

    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    Wait(2000)
    
    local hitchingPostObject = CreateObject(hitchingPostData.model, x, y, z, true, false, false)
    PlaceObjectOnGroundProperly(hitchingPostObject)
    SetEntityHeading(hitchingPostObject, heading)
    FreezeEntityPosition(hitchingPostObject, true)
    
    deployedHitchingPost = hitchingPostObject
    currentHitchingPostData = hitchingPostData
    deployedOwner = GetPlayerServerId(PlayerId())
    
    TriggerServerEvent('rsg-hitchingpost:server:placeHitchingPost')
    
    Wait(500)
    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('rsg-hitchingpost:client:pickupHitchingPost', function()
    if not deployedHitchingPost then
        lib.notify({
            title = "No Hitching Post!",
            description = "There's no hitching post to pick up.",
            type = 'error'
        })
        return
    end

    if isHitching then
        lib.notify({
            title = "Cannot Pick Up",
            description = "You can't pick up the hitching post while it's in use.",
            type = 'error'
        })
        return
    end
    
    if #hitchedHorses > 0 then
        lib.notify({
            title = "Horses Still Hitched",
            description = "You need to unhitch all horses before picking up the post.",
            type = 'error'
        })
        return
    end

    local ped = PlayerPedId()
    
    
    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    Wait(2000)

    if deployedHitchingPost then
        DeleteObject(deployedHitchingPost)
        deployedHitchingPost = nil
        currentHitchingPostData = nil
        TriggerServerEvent('rsg-hitchingpost:server:returnHitchingPost')
        deployedOwner = nil
    end

    ClearPedTasks(ped)
    

    lib.notify({
        title = 'Hitching Post Picked Up',
        description = 'You have picked up your hitching post.',
        type = 'success'
    })
end)

RegisterNetEvent('rsg-hitchingpost:client:hitchHorse', function()
    if isHitching then return end
    
    -- Check for deployed hitching post
    if not deployedHitchingPost then
        lib.notify({
            title = "No Hitching Post Placed",
            description = "You need to place a hitching post first.",
            type = 'error'
        })
        return
    end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local horsesFound = {}
    local isMounted = false
    local mountedHorse = nil
    
    -- Check if player is mounted on a horse
    if IsPedOnMount(ped) then
        mountedHorse = GetMount(ped)
        table.insert(horsesFound, mountedHorse)
        isMounted = true
    end
    
    -- Find all nearby horses within a certain radius
    local radius = 8.0
    local entities = GetGamePool('CPed')
    
    for _, entity in ipairs(entities) do
        if DoesEntityExist(entity) and not IsEntityDead(entity) then
            local isHorse = Citizen.InvokeNative(0x772A1969F649E902, entity) == GetHashKey("A_C_Horse")
            
            if not isHorse then
                local pedType = GetPedType(entity)
                if pedType == 28 then -- PED_TYPE_HORSE in RedM
                    isHorse = true
                end
            end
            
            if isHorse then
                local horseCoords = GetEntityCoords(entity)
                local distance = #(coords - horseCoords)
                
                if distance <= radius and entity ~= mountedHorse then
                    table.insert(horsesFound, entity)
                end
            end
        end
    end
    
    if #horsesFound == 0 then
        lib.notify({
            title = "No Horses Available",
            description = "There are no horses nearby to hitch.",
            type = 'error'
        })
        return
    end
    
    isHitching = true
    LocalPlayer.state:set('inv_busy', true, true)
    
    -- Get hitching post position
    local hitchingPostCoords = GetEntityCoords(deployedHitchingPost)
    local hitchingPostHeading = GetEntityHeading(deployedHitchingPost)
    
    -- Process each horse one by one
    for i, horse in ipairs(horsesFound) do
        local angle = (hitchingPostHeading + (i * 45)) % 360
        local offsetX = math.sin(math.rad(angle)) * 0.8
        local offsetY = math.cos(math.rad(angle)) * 0.8
        local targetX = hitchingPostCoords.x - offsetX
        local targetY = hitchingPostCoords.y - offsetY
        
        local isCurrentHorseMounted = (horse == mountedHorse and isMounted)
        
        if isCurrentHorseMounted then
            -- Handle mounted horse
            local playerAndHorseCoords = GetEntityCoords(horse)
            local distance = #(vector3(targetX, targetY, hitchingPostCoords.z) - playerAndHorseCoords)
            
            if distance > 3.0 then
                lib.notify({
                    title = "Moving to Hitching Post",
                    description = "Guiding your horse to the hitching post.",
                    type = 'info'
                })
                
                TaskGoToCoordAnyMeans(horse, targetX, targetY, hitchingPostCoords.z, 1.5, 0, false, 786603, 0)
                
                local timeout = 10 -- seconds
                local startTime = GetGameTimer()
                local arrived = false
                
                while not arrived and GetGameTimer() - startTime < timeout * 100 do
                    Wait(500)
                    local horseCoords = GetEntityCoords(horse)
                    local dist = #(vector3(targetX, targetY, hitchingPostCoords.z) - horseCoords)
                    
                    if dist < 2.0 then
                        arrived = true
                    end
                end
                
                if not arrived then
                    lib.notify({
                        title = 'Too Far',
                        description = 'Move closer to the hitching post with your horse',
                        type = 'error'
                    })
                    goto continue
                end
            end
            
            -- Face the horse toward the hitching post
            local faceHeading = angle - 180.0
            if faceHeading < 0 then faceHeading = faceHeading + 360.0 end
            TaskTurnPedToFaceCoord(horse, hitchingPostCoords.x, hitchingPostCoords.y, hitchingPostCoords.z, 1000)
            Wait(1000)
            
            -- Apply animation to horse while staying mounted
            lib.notify({
                title = 'Hitching Horse',
                description = 'Your horse is being hitched while you remain mounted',
                type = 'success'
            })
            
            Citizen.InvokeNative(0x524B54361229154F, horse, joaat('PROP_ANIMAL_HORSE_HITCHED'), 5000, false, false, 32, false)
            Wait(5000)
            
            -- Apply instant health and stamina
            ApplyInstantHealing(horse)
            
            -- Add horse to hitched horses list
            table.insert(hitchedHorses, { 
                entity = horse, 
                position = vector3(targetX, targetY, hitchingPostCoords.z)
            })
        else
            -- Handle unmounted horse
            ClearPedTasks(horse)
            TaskGoToCoordAnyMeans(horse, targetX, targetY, hitchingPostCoords.z, 1.5, 0, false, 786603, 0)
            
            local timeout = 10 -- seconds
            local startTime = GetGameTimer()
            local arrived = false
            
            while not arrived and GetGameTimer() - startTime < timeout * 1000 do
                Wait(500)
                local horseCoords = GetEntityCoords(horse)
                local dist = #(vector3(targetX, targetY, hitchingPostCoords.z) - horseCoords)
                
                if dist < 1.5 then
                    arrived = true
                end
            end
            
            local faceHeading = angle - 180.0
            if faceHeading < 0 then faceHeading = faceHeading + 360.0 end
            TaskTurnPedToFaceCoord(horse, hitchingPostCoords.x, hitchingPostCoords.y, hitchingPostCoords.z, 2000)
            Wait(2000)
            
            Citizen.InvokeNative(0x524B54361229154F, horse, joaat('PROP_ANIMAL_HORSE_HITCHED'), 7000, true, false, 0, false)
            Wait(7000)
            
            -- Apply instant health and stamina
            ApplyInstantHealing(horse)
			-- Get and update horse health and stamina cores
			local horseHealth = Citizen.InvokeNative(0x36731AC041289BB1, horse, 0)  -- GetAttributeCoreValue (Health)
			local horseStamina = Citizen.InvokeNative(0x36731AC041289BB1, horse, 1) -- GetAttributeCoreValue (Stamina)
        
			-- If values are not numbers, default to 0
			if not tonumber(horseHealth) then horseHealth = 0 end
			if not tonumber(horseStamina) then horseStamina = 0 end
        
			-- Add health and stamina bonuses (20 points to each)
			Citizen.InvokeNative(0xC6258F41D86676E0, horse, 0, math.min(100, horseHealth + 20))  -- SetAttributeCoreValue (Health)
			Citizen.InvokeNative(0xC6258F41D86676E0, horse, 1, math.min(100, horseStamina + 20)) -- SetAttributeCoreValue (Stamina)
        
			-- Apply core fortification
			Citizen.InvokeNative(0xF6A7C08DF2E28B28, horse, 0, 1000.0) -- Fortify health core
			Citizen.InvokeNative(0xF6A7C08DF2E28B28, horse, 1, 1000.0) -- Fortify stamina core
        
			-- Play core fill up sound
			Citizen.InvokeNative(0x50C803A4CD5932C5, true) -- core
			Citizen.InvokeNative(0xD4EE21B7CC7FD350, true) -- core
            
            -- Add horse to hitched horses list
            table.insert(hitchedHorses, { 
                entity = horse, 
                position = vector3(targetX, targetY, hitchingPostCoords.z)
            })
        end
        
        ::continue::
    end
    
    isHitching = false
    LocalPlayer.state:set('inv_busy', false, true)
    
    local horseText = #horsesFound > 1 and "horses have" or "horse has"
    lib.notify({
        title = 'Horse Hitched',
        description = 'Your '..horseText..' been hitched and fully restored',
        type = 'success'
    })
end)

-- New event to unhitch horses
RegisterNetEvent('rsg-hitchingpost:client:unhitchHorse', function()
    if #hitchedHorses == 0 then
        lib.notify({
            title = "No Hitched Horses",
            description = "There are no horses hitched to unhitch.",
            type = 'error'
        })
        return
    end
    
    if isHitching then return end
    isHitching = true
    
    -- Create list of hitched horses for menu
    local unhitchOptions = {}
    local unhitchAllOption = {
        title = "Unhitch All Horses",
        description = "Release all horses from the hitching post",
        icon = 'fas fa-external-link-alt',
        onSelect = function()
            for _, horseData in ipairs(hitchedHorses) do
                local horse = horseData.entity
                if DoesEntityExist(horse) and not IsEntityDead(horse) then
                    ClearPedTasks(horse)
                end
            end
            
            hitchedHorses = {}
            
            lib.notify({
                title = 'Horses Released',
                description = 'All horses have been unhitched',
                type = 'success'
            })
        end
    }
    
    table.insert(unhitchOptions, unhitchAllOption)
    
    for i, horseData in ipairs(hitchedHorses) do
        local horse = horseData.entity
        if DoesEntityExist(horse) and not IsEntityDead(horse) then
            local horseName = "Horse " .. i -- Replace with real horse name if available
            
            table.insert(unhitchOptions, {
                title = "Unhitch " .. horseName,
                description = "Release this horse from the hitching post",
                icon = 'fas fa-horse',
                onSelect = function()
                    ClearPedTasks(horse)
                    table.remove(hitchedHorses, i)
                    
                    lib.notify({
                        title = 'Horse Released',
                        description = horseName .. ' has been unhitched',
                        type = 'success'
                    })
                end
            })
        end
    end
    
    lib.registerContext({
        id = 'unhitch_horse_menu',
        title = 'Unhitch Horses',
        options = unhitchOptions
    })
    
    lib.showContext('unhitch_horse_menu')
    isHitching = false
end)

-- Event to handle horse health visual effects
RegisterNetEvent('rsg-appearance:client:ApplyHorseHealthVisual', function(horse)
    if not DoesEntityExist(horse) then return end
    
    -- Use a generic dust/particle effect that works in RedM
    local horseCoords = GetEntityCoords(horse)
end)

-- Event to handle gold cores visual effect
RegisterNetEvent('rsg-horses:client:HorseGoldCores', function(horse)
    if not DoesEntityExist(horse) then return end
    
    -- Play a happy horse sound
    Citizen.InvokeNative(0xE8EAFF7B41EDD291, horse, GetHashKey("HORSE_SNORT"), -1)  -- PlayAnimalVocalization
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if deployedHitchingPost then
        DeleteObject(deployedHitchingPost)
    end
    
    -- Unhitch all horses when resource stops
    for _, horseData in ipairs(hitchedHorses) do
        local horse = horseData.entity
        if DoesEntityExist(horse) and not IsEntityDead(horse) then
            ClearPedTasks(horse)
        end
    end
end)

-- Removed the healing interval thread since we're doing instant healing

CreateThread(function()
    RegisterHitchingPostTargeting()
end)

