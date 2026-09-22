require "ISUI/ISUIElement"

---@class DamoclesHUDButton : ISUIElement
DamoclesHUDButton = ISUIElement:derive("DamoclesHUDButton")

function DamoclesHUDButton:new(x, y, width, height, onClick)
    local o = ISUIElement:new(x, y, width or 48, height or 48)
    setmetatable(o, self)
    self.__index = self

    o.onClickCallback = onClick
    o.isDragging = false
    o.dragStartX = 0
    o.dragStartY = 0
    o.origX = x
    o.origY = y
    o.hasMoved = false
    o.isHovered = false
    o.hasNotification = false

    -- Texture optionnelle
    o.logoTexture = getTexture("media/textures/Damocles/hud_iris_btn.png") or getTexture("media/textures/Damocles/logo_iris.png")

    return o
end

function DamoclesHUDButton:triggerNotification()
    self.hasNotification = true
end

function DamoclesHUDButton:clearNotification()
    self.hasNotification = false
end

function DamoclesHUDButton:onMouseDown(x, y)
    self.isDragging = true
    self.dragStartX = self:getMouseX()
    self.dragStartY = self:getMouseY()
    self.origX = self:getX()
    self.origY = self:getY()
    self.hasMoved = false
    return true
end

function DamoclesHUDButton:onMouseMove(dx, dy)
    self.isHovered = true
    if self.isDragging then
        local curMouseX = self:getMouseX()
        local curMouseY = self:getMouseY()
        local deltaX = curMouseX - self.dragStartX
        local deltaY = curMouseY - self.dragStartY

        if math.abs(deltaX) > 4 or math.abs(deltaY) > 4 then
            self.hasMoved = true
        end

        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local newX = math.max(0, math.min(screenW - self:getWidth(), self:getX() + dx))
        local newY = math.max(0, math.min(screenH - self:getHeight(), self:getY() + dy))

        self:setX(newX)
        self:setY(newY)
    end
    return true
end

function DamoclesHUDButton:onMouseMoveOutside(dx, dy)
    self.isHovered = false
    if self.isDragging then
        self:onMouseMove(dx, dy)
    end
    return true
end

function DamoclesHUDButton:onMouseUp(x, y)
    if self.isDragging then
        self.isDragging = false
        if not self.hasMoved and self.onClickCallback then
            self.hasNotification = false
            self.onClickCallback()
        end
    end
    return true
end

function DamoclesHUDButton:onMouseUpOutside(x, y)
    self.isDragging = false
    return true
end

function DamoclesHUDButton:prerender()
    if not self:isVisible() then return end

    local w = self:getWidth()
    local h = self:getHeight()

    -- Fond sombre
    self:drawRect(0, 0, w, h, 0.85, 0.03, 0.07, 0.10)

    -- Pulsation en cas de notification active
    if self.hasNotification then
        local pulse = 0.5 + (math.sin(getTimeInMillis() / 150) * 0.5)
        self:drawRect(0, 0, w, h, 0.25 * pulse, 0.2, 0.8, 1.0)
        self:drawRectBorder(0, 0, w, h, 0.8 + pulse * 0.2, 1.0, 0.80, 0.15)
        self:drawRectBorder(1, 1, w - 2, h - 2, 0.6 + pulse * 0.4, 0.2, 0.95, 1.0)
    elseif self.isHovered or self.isDragging then
        self:drawRectBorder(0, 0, w, h, 1.0, 0.20, 0.95, 1.0)
        self:drawRectBorder(1, 1, w - 2, h - 2, 0.5, 0.0, 0.70, 0.90)
    else
        self:drawRectBorder(0, 0, w, h, 0.7, 0.0, 0.60, 0.75)
    end

    -- Si texture disponible, on l'affiche, sinon fallback textuel/ic ne vectorielle
    if self.logoTexture then
        self:drawTextureScaled(self.logoTexture, 4, 4, w - 8, h - 8, 1.0, 1.0, 1.0, 1.0)
    else
        -- Fallback logo pixel art procedural (Oeil IRIS stylis )
        local cx = w / 2
        local cy = (h / 2) - 4
        self:drawRect(cx - 12, cy, 24, 2, 0.9, 0.0, 0.85, 1.0)
        self:drawRect(cx - 8, cy - 4, 16, 2, 0.8, 0.0, 0.85, 1.0)
        self:drawRect(cx - 8, cy + 4, 16, 2, 0.8, 0.0, 0.85, 1.0)
        self:drawRect(cx - 3, cy - 1, 6, 4, 1.0, 1.0, 0.9, 0.2) -- Pupille

        -- Texte "IRIS"
        self:drawTextCentre("IRIS", cx, h - 14, 0.0, 0.9, 1.0, 1.0, UIFont.Small)
    end

    -- Pastille de notification "!" si une alerte est active
    if self.hasNotification then
        local dotSize = 16
        local dotX = w - dotSize + 2
        local dotY = -2
        self:drawRect(dotX, dotY, dotSize, dotSize, 0.95, 0.95, 0.15, 0.15)
        self:drawRectBorder(dotX, dotY, dotSize, dotSize, 1.0, 1.0, 1.0, 1.0)
        self:drawTextCentre("!", dotX + dotSize / 2, dotY + 1, 1.0, 1.0, 1.0, 1.0, UIFont.Small)
    end
end
