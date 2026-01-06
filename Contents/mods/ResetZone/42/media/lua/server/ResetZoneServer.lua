if not isServer() then return end

require "ResetZoneData"

-- Ensure ResetZone table exists (defined in ResetZoneData)
ResetZone = ResetZone or {}
ResetZone.RestartInterval = 6 * 60 -- Minutes (6 hours)
ResetZone.TimePassed = 0

-- Load the reset list when server starts
if ResetZone.LoadResetList then
    ResetZone.LoadResetList()
end

-- Function to broadcast messages to all players
local function broadcast(message)
    -- Send custom command for Halo text
    sendServerCommand("ResetZone", "message", { text = message })
    -- Send standard server message for Chat (reliable backup)
    sendServerCommand("server", "say", { message })
    print("ResetZone: " .. message)
end

-- Function to check coordinates (Debug helper)
-- Admins can check server logs to see which cell they are in
local function logPlayerCoordinates()
    local players = getOnlinePlayers()
    if players then
        for i=0, players:size()-1 do
            local player = players:get(i)
            local cell = ResetZone.getChunkName(player:getX(), player:getY())
            print(string.format("ResetZone Debug: Player %s is in Chunk: %s", player:getUsername(), cell))
        end
    end
end

-- Main Timer Loop
local lastCheckTime = 0
local lastMinuteChecked = -1

local function onTick()
    local currentTime = getTimestamp()
    
    -- Initialize lastCheckTime
    if lastCheckTime == 0 then lastCheckTime = currentTime end

    -- Check every 1 second (1000ms) to be precise
    if currentTime - lastCheckTime >= 1000 then
        lastCheckTime = currentTime

        -- Calculate minutes left based on fixed schedule (00:00, 06:00, 12:00, 18:00)
        local now = os.date("*t")
        local currentMinutes = (now.hour * 60) + now.min
        
        -- Only run logic once per minute to prevent spam
        if currentMinutes ~= lastMinuteChecked then
            lastMinuteChecked = currentMinutes
            
            local interval = ResetZone.RestartInterval
            
            -- Find next reset time
            local nextReset = math.ceil(currentMinutes / interval) * interval
            
            -- Handle case where next reset is tomorrow (e.g. 24:00)
            if nextReset == currentMinutes then
                nextReset = currentMinutes + interval
            end
            
            local minutesLeft = nextReset - currentMinutes

            -- Sync time to all clients every minute
            sendServerCommand("ResetZone", "syncTime", { minutesLeft = minutesLeft })

            -- Warnings
            if minutesLeft > 0 and (minutesLeft % 60 == 0) then
                local hours = math.floor(minutesLeft / 60)
                local unit = (hours == 1) and "hour" or "hours"
                broadcast("WARNING: Server will restart and reset business areas in " .. hours .. " " .. unit .. "!")
            elseif minutesLeft == 30 then
                broadcast("WARNING: Server restart in 30 minutes!")
            elseif minutesLeft == 15 then
                broadcast("WARNING: Server restart in 15 minutes!")
            elseif minutesLeft == 5 then
                broadcast("WARNING: Server restart in 5 minutes! Finish your looting!")
            elseif minutesLeft == 1 then
                broadcast("URGENT: Server restarting in 1 minute! Find shelter!")
            elseif minutesLeft <= 0 then
                broadcast("Restarting server now...")
                
                -- ResetZone Agent Integration
                local agentFound = false
                pcall(function()
                    local agent = luajava.bindClass("com.resetzone.injector.ResetZoneAgent")
                    if agent then
                        print("ResetZone: Java Agent detected via LuaJava.")
                        local fileList = luajava.newInstance("java.util.ArrayList")
                        
                        local count = 0
                        for path, _ in pairs(ResetZone.ResetCells) do
                            fileList:add(path)
                            count = count + 1
                        end
                        print("ResetZone: Submitting " .. count .. " files for cleanup.")
                        agent:scheduleReset(fileList)
                        agentFound = true
                    end
                end)

                if not agentFound then
                     print("ResetZone: Java Agent NOT detected. Performing standard restart (No Map Reset).")
                     saveGame()
                     getCore():quit() 
                end
            end
        end
    end
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
        -- Send the full list to the client
        sendServerCommand(player, "ResetZone", "syncList", { list = ResetZone.ResetCells })

    elseif command == "markArea" then
        -- Check admin
        local access = player:getAccessLevel()
        if access == "Admin" or access == "admin" or access == "Moderator" or access == "moderator" then
            local cell = args.cell
            ResetZone.ResetCells[cell] = true
            ResetZone.SaveResetList()
            -- Broadcast to all players
            sendServerCommand("ResetZone", "statusUpdate", { cell = cell, isReset = true })
            print("ResetZone: Marked " .. cell)
        end

    elseif command == "unmarkArea" then
        -- Check admin
        local access = player:getAccessLevel()
        if access == "Admin" or access == "admin" or access == "Moderator" or access == "moderator" then
            local cell = args.cell
            ResetZone.ResetCells[cell] = nil
            ResetZone.SaveResetList()
            -- Broadcast to all players
            sendServerCommand("ResetZone", "statusUpdate", { cell = cell, isReset = false })
            print("ResetZone: Unmarked " .. cell)
        end

    elseif command == "batchUpdate" then
        -- Check admin
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
                -- Broadcast full sync to ensure all clients are up to date
                -- Or we could broadcast the batch, but syncList is safer for consistency
                sendServerCommand("ResetZone", "syncList", { list = ResetZone.ResetCells })
                print("ResetZone: Processed batch update of " .. count .. " chunks.")
            end
        end
    end
end

Events.OnTick.Add(onTick)
Events.OnClientCommand.Add(onClientCommand)

-- Force print to console immediately on load
print("ResetZone: Server timer loaded. Restart set for every " .. (ResetZone.RestartInterval/60) .. " hours (Fixed Schedule).")
triggerEvent("OnResetZoneLoaded")
