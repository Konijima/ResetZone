require "ResetZoneUI"
require "ResetZoneData"
require "ISUI/ISUIElement"
require "ISUI/ISPanel"
require "ISUI/ISChat"
require "ISUI/HaloTextHelper"

ResetZoneClient = {}
ResetZoneClient.ui = nil
ResetZoneClient.lastCell = nil
ResetZoneClient.synced = false
ResetZoneClient.minutesLeft = 0
ResetZoneClient.lastSyncTime = 0

-- Batching System
ResetZoneClient.pendingChanges = {}
ResetZoneClient.lastChangeTime = 0
ResetZoneClient.BATCH_DELAY = 3000 -- 3 seconds

function ResetZoneClient.queueChange(cell, isMark)
    -- Update local state immediately for visual feedback
    if isMark then
        ResetZone.ResetCells[cell] = true
    else
        ResetZone.ResetCells[cell] = nil
    end
    
    -- Add to pending queue
    ResetZoneClient.pendingChanges[cell] = isMark
    ResetZoneClient.lastChangeTime = getTimestamp()
end

local function processBatchQueue()
    local currentTime = getTimestamp()
    
    -- Check if we have pending changes and enough time has passed
    if ResetZoneClient.lastChangeTime > 0 and (currentTime - ResetZoneClient.lastChangeTime) > (ResetZoneClient.BATCH_DELAY / 1000) then
        local count = 0
        for _ in pairs(ResetZoneClient.pendingChanges) do count = count + 1 end
        
        if count > 0 then
            local player = getPlayer()
            if player then
                sendClientCommand(player, "ResetZone", "batchUpdate", { changes = ResetZoneClient.pendingChanges })
                print("ResetZone: Sent batch update of " .. count .. " chunks.")
            end
            
            -- Clear queue
            ResetZoneClient.pendingChanges = {}
            ResetZoneClient.lastChangeTime = 0
        end
    end
end

-- Function to update highlights for all loaded chunks
local function updateHighlights()
    -- Process queue first
    processBatchQueue()

    local player = getPlayer()
    if not player then return end
    
    -- Check admin
    local access = player:getAccessLevel()
    if access ~= "Admin" and access ~= "admin" and access ~= "Moderator" and access ~= "moderator" then return end

    local cellObj = getCell()
    if not cellObj then return end
    
    local pX = player:getX()
    local pY = player:getY()
    
    -- Dynamic radius based on zoom
    local zoom = Core.getInstance():getZoom(0)
    local chunkRadius = math.ceil(2 * zoom)
    if chunkRadius < 2 then chunkRadius = 2 end
    if chunkRadius > 5 then chunkRadius = 5 end -- Cap at 5 to prevent lag
    
    local pChunkX = math.floor(pX / 10)
    local pChunkY = math.floor(pY / 10)

    local highlightCount = 0
    local MAX_HIGHLIGHTS = 1500 -- Limit to ~15 chunks of tiles to prevent lag

    -- 1. Collect chunks within radius
    local chunksToCheck = {}
    for cx = pChunkX - chunkRadius, pChunkX + chunkRadius do
        for cy = pChunkY - chunkRadius, pChunkY + chunkRadius do
            local dist = (cx - pChunkX)^2 + (cy - pChunkY)^2
            table.insert(chunksToCheck, {cx = cx, cy = cy, dist = dist})
        end
    end

    -- 2. Sort by distance (closest to player first)
    table.sort(chunksToCheck, function(a, b) return a.dist < b.dist end)

    -- 3. Iterate sorted chunks
    for _, data in ipairs(chunksToCheck) do
        if highlightCount >= MAX_HIGHLIGHTS then break end
        
        local cx = data.cx
        local cy = data.cy
            
        -- Check if this chunk is a reset zone
        local chunkName = "map/" .. cx .. "/" .. cy .. ".bin"
        if ResetZone.ResetCells[chunkName] then
            -- Iterate squares in this chunk
            for x = 0, 9 do
                for y = 0, 9 do
                    if highlightCount >= MAX_HIGHLIGHTS then break end
                    
                    local absX = (cx * 10) + x
                    local absY = (cy * 10) + y
                    
                    -- Only highlight ground floor (Z=0)
                    local z = 0
                    local sq = cellObj:getGridSquare(absX, absY, z)
                    if sq then
                        -- Highlight Floor
                        local floor = sq:getFloor()
                        if floor then
                            floor:setHighlighted(true)
                            floor:setHighlightColor(1.0, 0.0, 0.0, 1.0)
                            highlightCount = highlightCount + 1
                        end
                    end
                end
            end
        end
    end
end

-- Remove Renderer class and use OnRenderTick
-- ResetZoneRenderer = ISUIElement:derive("ResetZoneRenderer") ... (Removed)

function ResetZoneClient.getCurrentCell()
    local player = getPlayer()
    if not player then return nil end
    return ResetZone.getChunkName(player:getX(), player:getY())
end

local function createUI()
    if ResetZoneClient.ui then return end
    -- Position Top Center
    local width = 230 -- Width defined in ResetZoneUI
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = 20 -- Small margin from top
    
    ResetZoneClient.ui = ResetZoneUI:new(x, y)
    ResetZoneClient.ui:initialise()
    ResetZoneClient.ui:addToUIManager()
    ResetZoneClient.ui:setVisible(true)
end

local function onGameStart()
    -- Load local cache first
    if ResetZone.LoadResetList then
        ResetZone.LoadResetList()
    end
end

local function onTick()
    local player = getPlayer()
    if not player then return end

    -- Request sync once
    if not ResetZoneClient.synced then
        if isClient() then
            sendClientCommand(player, "ResetZone", "requestSync", {})
            ResetZoneClient.synced = true
        end
    end
    
    createUI()
    -- createRenderer() -- Removed
    
    -- Always check admin status (in case it syncs late)
    if ResetZoneClient.ui then
        ResetZoneClient.ui:checkAdmin()
    end

    -- Check for cell change
    local currentCell = ResetZoneClient.getCurrentCell()
    if currentCell ~= ResetZoneClient.lastCell then
        ResetZoneClient.lastCell = currentCell
        
        -- Check local list first for immediate feedback
        local isReset = ResetZone.ResetCells[currentCell] == true
        if ResetZoneClient.ui then
            ResetZoneClient.ui:updateStatus(isReset)
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= "ResetZone" then return end
    
    if command == "syncList" then
        ResetZone.ResetCells = args.list
        ResetZone.SaveResetList()
        print("ResetZone: Synced reset list from server.")
        
        -- Refresh UI
        local currentCell = ResetZoneClient.getCurrentCell()
        if currentCell and ResetZoneClient.ui then
            local isReset = ResetZone.ResetCells[currentCell] == true
            ResetZoneClient.ui:updateStatus(isReset)
        end

    elseif command == "statusUpdate" then
        -- Update local list
        if args.isReset then
            ResetZone.ResetCells[args.cell] = true
        else
            ResetZone.ResetCells[args.cell] = nil
        end
        ResetZone.SaveResetList()

        -- Update UI if we are in that cell
        if args.cell == ResetZoneClient.lastCell then
            if ResetZoneClient.ui then
                ResetZoneClient.ui:updateStatus(args.isReset)
            end
        end
    elseif command == "message" then
        local msg = args.text
        if msg then
            print("ResetZone Client: Received message: " .. msg)
            -- Show as halo text for visibility
            if HaloTextHelper then
                HaloTextHelper.addText(getPlayer(), msg, {r=1, g=0.2, b=0.2})
            end
        end

    elseif command == "syncTime" then
        ResetZoneClient.minutesLeft = args.minutesLeft
        ResetZoneClient.lastSyncTime = getTimestamp()
    end
end

Events.OnGameStart.Add(onGameStart)
Events.OnTick.Add(onTick)
Events.OnRenderTick.Add(updateHighlights) -- Added
Events.OnServerCommand.Add(onServerCommand)