require "ISUI/ISPanel"

ResetZoneUI = ISPanel:derive("ResetZoneUI")

function ResetZoneUI:initialise()
    ISPanel.initialise(self)
    self:create()
end

function ResetZoneUI:create()
    -- Status text state
    self.statusText = "Checking Zone..."
    self.statusColor = {r=1, g=1, b=1}
    self.moveWithMouse = true -- Allow moving

    -- Admin Toggle Button (Hidden by default)
    self.toggleBtn = ISButton:new(65, 55, 100, 25, "Toggle Zone", self, ResetZoneUI.onToggle)
    self.toggleBtn:setVisible(false)
    self:addChild(self.toggleBtn)
end

function ResetZoneUI:updateStatus(isReset)
    self.isResetZone = isReset
    if isReset == true then
        self.statusText = "RESET ZONE"
        self.statusColor = {r=1, g=0, b=0} -- Red
        
        if self.toggleBtn then
            self.toggleBtn:setTitle("Unmark Zone")
            self.toggleBtn.backgroundColor = {r=0, g=0.5, b=0, a=1} -- Green button to unmark
        end
    elseif isReset == false then
        if self.isAdmin then
            self.statusText = "Safe Zone"
            self.statusColor = {r=0, g=1, b=0} -- Green
        else
            self.statusText = "" -- Hide for players
        end
        
        if self.toggleBtn then
            self.toggleBtn:setTitle("Mark Reset")
            self.toggleBtn.backgroundColor = {r=0.5, g=0, b=0, a=1} -- Red button to mark
        end
    else
        if self.isAdmin then
            self.statusText = "Checking Zone..."
            self.statusColor = {r=1, g=1, b=1} -- White
        else
            self.statusText = ""
        end
    end
end

function ResetZoneUI:checkAdmin()
    local player = getPlayer()
    if player then
        local access = player:getAccessLevel()
        -- Check for various admin levels, case-insensitive just in case
        if access == "Admin" or access == "admin" or access == "Moderator" or access == "moderator" then
            self.isAdmin = true
            self.toggleBtn:setVisible(true)
            self:setHeight(90)
        else
            self.isAdmin = false
            self.toggleBtn:setVisible(false)
            self:setHeight(50)
        end
        -- Re-update status to apply visibility rules if admin status changed
        self:updateStatus(self.isResetZone)
    end
end

function ResetZoneUI:onToggle()
    local cell = ResetZoneClient.getCurrentCell()
    if self.isResetZone then
        ResetZoneClient.queueChange(cell, false)
    else
        ResetZoneClient.queueChange(cell, true)
    end
end

function ResetZoneUI:render()
    -- No background drawing (Invisible window)
    
    -- Draw Text Centered
    if self.statusText then
        self:drawTextCentre(self.statusText, self.width / 2, 5, self.statusColor.r, self.statusColor.g, self.statusColor.b, 1, UIFont.Medium)
    end

    -- Draw Current Cell ID (Debug/Info)
    local currentCell = ResetZoneClient.getCurrentCell()
    if currentCell and self.isAdmin then
        self:drawTextCentre("(" .. currentCell .. ")", self.width / 2, 30, 0.8, 0.8, 0.8, 1, UIFont.Small)
    end

    -- Draw Timer
    if ResetZoneClient.minutesLeft and ResetZoneClient.lastSyncTime > 0 then
        local now = getTimestamp()
        local timeSinceSync = now - ResetZoneClient.lastSyncTime
        local secondsLeft = (ResetZoneClient.minutesLeft * 60) - timeSinceSync
        
        if secondsLeft < 0 then secondsLeft = 0 end
        
        local h = math.floor(secondsLeft / 3600)
        local m = math.floor((secondsLeft % 3600) / 60)
        local s = math.floor(secondsLeft % 60)
        
        local timerText = string.format("Next Reset: %02d:%02d:%02d", h, m, s)
        
        -- Draw at bottom
        local yPos = self.height - 15
        if self.isAdmin then yPos = 80 end -- Adjust if admin button is visible
        
        self:drawTextCentre(timerText, self.width / 2, yPos, 0.9, 0.9, 0.9, 1, UIFont.Small)
    end
end

function ResetZoneUI:new(x, y)
    local o = {}
    o = ISPanel:new(x, y, 230, 50)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    return o
end
