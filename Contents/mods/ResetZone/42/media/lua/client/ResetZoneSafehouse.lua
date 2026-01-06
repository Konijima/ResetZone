require "ISUI/ISWorldObjectContextMenu"

-- Hook into the context menu creation to disable safehouse claiming in Reset Zones
local old_createMenu = ISWorldObjectContextMenu.createMenu

ISWorldObjectContextMenu.createMenu = function(player, worldobjects, x, y, test)
    -- Call the original function first to generate the menu
    local context = old_createMenu(player, worldobjects, x, y, test)
    
    -- If the menu wasn't created, return
    if not context then return end

    -- Check if we are in a reset zone
    -- We rely on the ResetZoneClient state which is updated by the server
    local isResetZone = false
    if ResetZoneClient and ResetZoneClient.ui and ResetZoneClient.ui.isResetZone then
        isResetZone = true
    end

    if isResetZone then
        -- Find the "Claim Safehouse" option
        -- We identify it by checking if the callback function is onTakeSafeHouse
        local safehouseOption = nil
        for i, option in ipairs(context.options) do
            if option.onSelect == ISWorldObjectContextMenu.onTakeSafeHouse then
                safehouseOption = option
                break
            end
        end

        if safehouseOption then
            -- Disable the option
            safehouseOption.notAvailable = true
            
            -- Add a tooltip explaining why
            local toolTip = ISToolTip:new()
            toolTip:initialise()
            toolTip:setVisible(false)
            toolTip.description = " <RGB:1,0,0> DANGER: This is a Reset Zone.\nSafehouses are disabled here."
            safehouseOption.toolTip = toolTip
        end
    end

    return context
end
