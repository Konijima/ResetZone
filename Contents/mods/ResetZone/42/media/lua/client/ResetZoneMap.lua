require "ISUI/Maps/ISWorldMap"

-- Ensure ResetZone table exists
if not ResetZone then return end

local function parseChunkName(name)
    local x, y = string.match(name, "map/(%d+)/(%d+).bin")
    if x and y then
        return tonumber(x), tonumber(y)
    end
    return nil, nil
end

-- Hook into ISWorldMap.render to draw overlays
local original_render = ISWorldMap.render
function ISWorldMap:render()
    -- Call original render first
    if original_render then original_render(self) end
    
    -- Only render for admins/moderators
    local player = getPlayer()
    if not player then return end
    local access = player:getAccessLevel()
    if access ~= "Admin" and access ~= "admin" and access ~= "Moderator" and access ~= "moderator" then 
        return 
    end
    
    -- Check if mapAPI is available
    if not self.javaObject then return end
    local mapAPI = self.javaObject:getAPI()
    if not mapAPI then return end
    
    if not ResetZone.ResetCells then return end

    -- OPTIMIZATION: Viewport Culling
    -- 1. Get visible world bounds
    local minX = mapAPI:uiToWorldX(0, 0)
    local minY = mapAPI:uiToWorldY(0, 0)
    local maxX = mapAPI:uiToWorldX(self.width, self.height)
    local maxY = mapAPI:uiToWorldY(self.width, self.height)

    -- 2. Convert to chunk coordinates
    local startCX = math.floor(minX / 10)
    local startCY = math.floor(minY / 10)
    local endCX = math.floor(maxX / 10)
    local endCY = math.floor(maxY / 10)

    -- 3. Safety: Don't render if zoomed out too far (e.g. > 2500 chunks visible)
    -- This prevents lag when viewing the whole map
    if (endCX - startCX) * (endCY - startCY) > 2500 then
        return
    end

    -- 4. Iterate only the visible grid
    for cx = startCX, endCX do
        for cy = startCY, endCY do
            local chunkName = string.format("map/%d/%d.bin", cx, cy)
            
            if ResetZone.ResetCells[chunkName] then
                -- Convert world coords to UI coords
                local wx = cx * 10
                local wy = cy * 10
                
                local x1 = mapAPI:worldToUIX(wx, wy)
                local y1 = mapAPI:worldToUIY(wx, wy)
                local x2 = mapAPI:worldToUIX(wx + 10, wy + 10)
                local y2 = mapAPI:worldToUIY(wx + 10, wy + 10)
                
                -- Draw red overlay
                self:drawRect(x1, y1, x2 - x1, y2 - y1, 0.3, 1, 0, 0)
                self:drawRectBorder(x1, y1, x2 - x1, y2 - y1, 0.8, 1, 0, 0)
            end
        end
    end
end

-- Helper to apply change to a chunk
local function applyChunkState(player, cx, cy, shouldMark)
    local cell = string.format("map/%d/%d.bin", cx, cy)
    
    -- Only send command if state is different
    local isCurrentlyMarked = ResetZone.ResetCells[cell] == true
    
    if shouldMark and not isCurrentlyMarked then
        ResetZoneClient.queueChange(cell, true)
    elseif not shouldMark and isCurrentlyMarked then
        ResetZoneClient.queueChange(cell, false)
    end
end

-- Hook into ISWorldMap.onMouseDown for interaction
local original_onMouseDown = ISWorldMap.onMouseDown
function ISWorldMap:onMouseDown(x, y)
    local player = getPlayer()
    -- Check admin and Shift key
    if player then
        local access = player:getAccessLevel()
        if access == "Admin" or access == "admin" or access == "Moderator" or access == "moderator" then
            if isShiftKeyDown() then
                if not self.javaObject then return end
                local mapAPI = self.javaObject:getAPI()
                if not mapAPI then return end
                
                -- Convert UI click to World coords
                local wx = mapAPI:uiToWorldX(x, y)
                local wy = mapAPI:uiToWorldY(x, y)
                
                -- Convert World to Chunk coords
                local cx = math.floor(wx / 10)
                local cy = math.floor(wy / 10)
                local cell = string.format("map/%d/%d.bin", cx, cy)
                
                -- Determine target state (inverse of clicked chunk)
                self.urDragging = true
                self.urTargetState = not ResetZone.ResetCells[cell]
                self.urLastChunk = cell
                
                -- Apply to first chunk
                applyChunkState(player, cx, cy, self.urTargetState)
                
                -- Return true to stop event propagation (prevent map dragging/clicking)
                return true
            end
        end
    end
    
    -- Call original if not intercepted
    if original_onMouseDown then
        return original_onMouseDown(self, x, y)
    end
end

-- Hook into ISWorldMap.onMouseMove for dragging
local original_onMouseMove = ISWorldMap.onMouseMove
function ISWorldMap:onMouseMove(dx, dy)
    if self.urDragging then
        local player = getPlayer()
        if not player then return end
        
        if not self.javaObject then return end
        local mapAPI = self.javaObject:getAPI()
        if not mapAPI then return end
        
        local x = self:getMouseX()
        local y = self:getMouseY()
        
        -- Convert UI click to World coords
        local wx = mapAPI:uiToWorldX(x, y)
        local wy = mapAPI:uiToWorldY(x, y)
        
        -- Convert World to Chunk coords
        local cx = math.floor(wx / 10)
        local cy = math.floor(wy / 10)
        local cell = string.format("map/%d/%d.bin", cx, cy)
        
        -- If moved to a new chunk
        if cell ~= self.urLastChunk then
            self.urLastChunk = cell
            applyChunkState(player, cx, cy, self.urTargetState)
        end
        
        return true
    end

    if original_onMouseMove then
        return original_onMouseMove(self, dx, dy)
    end
end

-- Hook into ISWorldMap.onMouseUp to stop dragging
local original_onMouseUp = ISWorldMap.onMouseUp
function ISWorldMap:onMouseUp(x, y)
    if self.urDragging then
        self.urDragging = false
        self.urTargetState = nil
        self.urLastChunk = nil
        return true
    end

    if original_onMouseUp then
        return original_onMouseUp(self, x, y)
    end
end
