local RSGCore = exports['rsg-core']:GetCoreObject()

-- Hitching Post item setup
RSGCore.Functions.CreateUseableItem("hitchingpost", function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    TriggerClientEvent('rsg-hitchingpost:client:openHitchingPostMenu', source)
    -- RemoveItem should be triggered after successful hitching post placement
end)

-- Return hitching post to inventory
RegisterNetEvent('rsg-hitchingpost:server:returnHitchingPost', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.AddItem("hitchingpost", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items["hitchingpost"], "add")
end)

-- Remove hitching post from inventory on placement
RegisterNetEvent('rsg-hitchingpost:server:placeHitchingPost', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.RemoveItem("hitchingpost", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items["hitchingpost"], "remove")
end)