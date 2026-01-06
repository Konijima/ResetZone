if not isServer() then return end

require "ResetZoneData"

ResetZone = ResetZone or {}

-- Load the reset list when server starts
if ResetZone.LoadResetList then
    ResetZone.LoadResetList()
end

-- Export function for the external Python tool
function ResetZone.ExportResetList()
    -- Create reset_zones.txt in the Lua/Server save folder or verify root
    local writer = getFileWriter("reset_zones.txt", true, false) -- true=create, false=append (so overwrite)
    if not writer then
        print("[ResetZone] Error: Could not create reset_zones.txt")
        return
    end

    local count = 0
    -- ResetCells keys are "X_Y" (chunk coords)
    for cell, _ in pairs(ResetZone.ResetCells) do
        local x, y = cell:match("(%d+)_(%d+)")
        if x and y then
            -- We export the raw chunk coord X_Y. 
            -- The Python tool will handle expanding this to map_X_Y.bin, chunkdata_X_Y.bin, etc.
            writer:writeln(string.format("%s_%s", x, y))
            count = count + 1
        end
    end
    writer:close()
    print("[ResetZone] Exported " .. count .. " reset zones to reset_zones.txt")
end

-- Hook into SaveResetList to update the export whenever it changes
local originalSave = ResetZone.SaveResetList
ResetZone.SaveResetList = function()
    if originalSave then originalSave() end
    ResetZone.ExportResetList()
end

local function onClientCommand(module, command, player, args)
    -- Intercept Safehouse Claims
    if module == "safehouse" and command == "add" then
        local cell = ResetZone.getChunkName(player:getX(), player:getY())
        if ResetZone.ResetCells[cell] then
            print("ResetZone WARNING: Player " .. player:getUsername() .. " attempted to claim safehouse in Reset Zone: " .. cell)
            sendServerCommand(player, "server", "say", { "WARNING: You are claiming a safehouse in a RESET ZONE. It will be deleted on restart!" })
        end
    end

    if module ~= "ResetZone" then return end

    if command == "checkStatus" then
        local cell = args.cell
        local isReset = ResetZone.ResetCells[cell] == true
        sendServerCommand(player, "ResetZone", "statusUpdate", { cell = cell, isReset = isReset })
    
    elseif command == "requestSync" then
        sendServerCommand(player, "ResetZone", "syncList", { list = ResetZone.ResetCells })

    elseif command == "markArea" then
        local access = player:getAccessLevel()
        if access == "Admin" or access == "admin" or access == "Moderator" or access == "moderator" then
            local cell = args.cell
            ResetZone.ResetCells[cell] = true
            ResetZone.SaveResetList()
            sendServerCommand("ResetZone", "statusUpdate", { cell = cell, isReset = true })
            print("ResetZone: Marked " .. cell)
        end

    elseif command == "unmarkArea" then
        local access = player:getAccessLevel()
        if access == "Admin" or access == "admin" or access == "Moderator" or access == "moderator" then
            local cell = args.cell
            ResetZone.ResetCells[cell] = nil
            ResetZone.SaveResetList()
            sendServerCommand("ResetZone", "statusUpdate", { cell = cell, isReset = false })
            print("ResetZone: Unmarked " .. cell)
        end

    elseif command == "batchUpdate" then
        local access = player:getAccessLevel()
        if access == "Admin" or access == "admin" or access == "Moderator" or access == "moderator" then
            local changes = args.changes
            local count = 0
            for cell, isReset in pairs(changes) do
                if isReset then
                    ResetZone.ResetCells[cell] = true
                else
                    ResetZone.ResetCells[cell] = nil
                end
                count = count + 1
            end
            if count > 0 then
                ResetZone.SaveResetList()
                sendServerCommand("ResetZone", "syncList", { list = ResetZone.ResetCells })
                print("ResetZone: Processed batch update of " .. count .. " chunks.")
            end
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnGameStart.Add(ResetZone.ExportResetList)

print("[ResetZone] Server Logic Loaded. Reset Management delegated to System.")
