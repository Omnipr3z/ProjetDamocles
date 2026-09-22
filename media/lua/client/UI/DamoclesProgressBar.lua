require "ISUI/ISUIElement"

---@class DamoclesProgressBar : ISUIElement
DamoclesProgressBar = ISUIElement:derive("DamoclesProgressBar")

function DamoclesProgressBar:new(x, y, width, height, isSegmented, segmentCount)
    local o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.progress = 0.0 -- Entre 0.0 et 1.0
    o.isSegmented = (isSegmented ~= nil) and isSegmented or true
    o.segmentCount = segmentCount or 32
    o.milestones = { 0.25, 0.50, 0.75 } -- Positions relatives des jalons

    -- Palette de couleurs cyber-cyan
    o.colorBg = { r = 0.03, g = 0.08, b = 0.10, a = 0.90 }
    o.colorBorder = { r = 0.0, g = 0.60, b = 0.70, a = 0.80 }
    o.colorFilled = { r = 0.0, g = 0.85, b = 1.0, a = 0.95 }
    o.colorEmpty = { r = 0.02, g = 0.15, b = 0.20, a = 0.50 }
    o.colorGlow = { r = 0.20, g = 0.95, b = 1.0, a = 0.40 }

    return o
end

function DamoclesProgressBar:setProgress(value)
    self.progress = math.max(0.0, math.min(1.0, value))
end

function DamoclesProgressBar:prerender()
    if not self:isVisible() then return end

    local w = self:getWidth()
    local h = self:getHeight()

    if self.isSegmented then
        -- Rendu de la jauge segment e haute technologie (IRIS Style)
        local gap = 3
        local totalGaps = (self.segmentCount - 1) * gap
        local cellWidth = math.max(2, (w - totalGaps) / self.segmentCount)
        local activeSegments = math.floor(self.progress * self.segmentCount + 0.001)

        for i = 1, self.segmentCount do
            local cellX = (i - 1) * (cellWidth + gap)
            local isActive = (i <= activeSegments)

            if isActive then
                -- Cellule active avec  clat
                self:drawRect(cellX, 0, cellWidth, h, self.colorFilled.a, self.colorFilled.r, self.colorFilled.g, self.colorFilled.b)
                -- Lueur int rieure
                self:drawRect(cellX + 1, 1, math.max(1, cellWidth - 2), h - 2, 0.4, 1.0, 1.0, 1.0)
                -- Bordure n on
                self:drawRectBorder(cellX, 0, cellWidth, h, 0.9, 0.4, 0.95, 1.0)
            else
                -- Cellule inactive avec cadre sombre
                self:drawRect(cellX, 0, cellWidth, h, self.colorEmpty.a, self.colorEmpty.r, self.colorEmpty.g, self.colorEmpty.b)
                self:drawRectBorder(cellX, 0, cellWidth, h, 0.4, self.colorBorder.r, self.colorBorder.g, self.colorBorder.b)
            end
        end

        -- Rendu des jalons (milestones) sous la jauge
        if self.milestones then
            local markerH = 6
            for _, m in ipairs(self.milestones) do
                local mx = math.floor(m * w)
                self:drawRect(mx - 1, h + 2, 2, markerH, 0.8, self.colorFilled.r, self.colorFilled.g, self.colorFilled.b)
                -- Petit carr  sous le rep re
                self:drawRect(mx - 3, h + 2 + markerH, 6, 4, 0.9, 0.0, 0.7, 0.9)
            end
        end
    else
        -- Rendu classique lisse avec cadre m tallique
        self:drawRect(0, 0, w, h, self.colorBg.a, self.colorBg.r, self.colorBg.g, self.colorBg.b)
        local fillW = math.floor(w * self.progress)
        if fillW > 0 then
            self:drawRect(1, 1, fillW - 2, h - 2, self.colorFilled.a, self.colorFilled.r, self.colorFilled.g, self.colorFilled.b)
        end
        self:drawRectBorder(0, 0, w, h, self.colorBorder.a, self.colorBorder.r, self.colorBorder.g, self.colorBorder.b)
    end
end
