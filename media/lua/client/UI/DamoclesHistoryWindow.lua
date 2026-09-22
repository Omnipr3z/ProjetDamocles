--[[
    PROJET DAMOCL S - DamoclesHistoryWindow.lua
    Fen tre d'archives et d'historique des missions accomplies.

    Responsabilit s :
        - Lister chronologiquement toutes les missions termin es (status == "COMPLETED")
        - Afficher les d tails de chaque succ s : lore, objectifs remplis, gain de recherche
        - S'ouvrir depuis le bouton [HISTORIQUE] de DamoclesMainWindow
        - Permettre au joueur de consulter ses accomplissements pass s sans les perdre de vue
]]

require "ISUI/ISCollapsableWindow"
require "DamoclesMissionDB"

---@class DamoclesHistoryWindow : ISCollapsableWindow
DamoclesHistoryWindow = ISCollapsableWindow:derive("DamoclesHistoryWindow")
DamoclesHistoryWindow.instance = nil

function DamoclesHistoryWindow:new(x, y)
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()

    local targetW = math.min(540, math.floor(screenW * 0.70))
    local targetH = math.min(420, math.floor(screenH * 0.70))

    local defaultX = x or math.floor((screenW - targetW) / 2)
    local defaultY = y or math.floor((screenH - targetH) / 2)

    local o = ISCollapsableWindow:new(defaultX, defaultY, targetW, targetH)
    setmetatable(o, self)
    self.__index = self

    o.title = "ISCharacterInfoWindow"
    o.resizable = false
    o.pin = true
    o.isCollapsed = false
    o.collapseCounter = 0

    -- Palette Cyber-Ardoise
    o.cBg     = { r = 0.04, g = 0.07, b = 0.09, a = 0.95 }
    o.cBorder = { r = 0.00, g = 0.75, b = 0.90, a = 0.85 }
    o.cCyan   = { r = 0.20, g = 0.95, b = 1.00, a = 1.0 }
    o.cSub    = { r = 0.50, g = 0.80, b = 0.85, a = 0.9 }
    o.cOk     = { r = 0.20, g = 0.90, b = 0.40, a = 1.0 }
    o.cGold   = { r = 1.00, g = 0.85, b = 0.20, a = 1.0 }

    -- Textures
    o.texLogo = getTexture("media/textures/Damocles/logo_iris.png")

    -- Scroll offset pour faire d filer la liste si beaucoup de missions
    o.scrollOffset = 0
    o.maxScroll = 0

    DamoclesHistoryWindow.instance = o
    return o
end

function DamoclesHistoryWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function DamoclesHistoryWindow:update()
    ISCollapsableWindow.update(self)

    if not self.pin then
        if self:isMouseOver() then
            if self.isCollapsed then self:uncollapse() end
            self.collapseCounter = 0
        else
            self.collapseCounter = self.collapseCounter + 1
            if self.collapseCounter > 40 and not self.isCollapsed then
                self:collapse()
            end
        end
    end
end

--- R cup re toutes les missions ayant le statut COMPLETED
function DamoclesHistoryWindow:_getCompletedMissions()
    local completed = {}

    -- Priorit  aux missions r elles de la DB
    if DamoclesMissionDB and DamoclesMissionDB.getAll then
        for _, m in ipairs(DamoclesMissionDB.getAll()) do
            if m.status == "COMPLETED" then
                table.insert(completed, m)
            end
        end
    end

    -- Si aucune mission compl t e en DB (ex: pur client MP avant synchro), v rifier le state client
    if #completed == 0 and DamoclesClientState and DamoclesClientState.completedMissions then
        for _, m in ipairs(DamoclesClientState.completedMissions) do
            table.insert(completed, m)
        end
    end

    return completed
end

function DamoclesHistoryWindow:onMouseWheel(del)
    self.scrollOffset = math.max(0, math.min(self.maxScroll, self.scrollOffset + (del * 28)))
    return true
end

function DamoclesHistoryWindow:prerender()
    if not self:isVisible() then return end

    local w = self:getWidth()
    local th = self:titleBarHeight()
    local h = self.isCollapsed and th or self:getHeight()

    -- Fond & Bordures
    self:drawRect(0, 0, w, h, self.cBg.a, self.cBg.r, self.cBg.g, self.cBg.b)
    self:drawRectBorder(0, 0, w, h, self.cBorder.a, self.cBorder.r, self.cBorder.g, self.cBorder.b)
    self:drawRectBorder(1, 1, w - 2, h - 2, 0.35, 0.0, 0.40, 0.50)

    if self.isCollapsed then return end

    local completed = self:_getCompletedMissions()

    ------------------------------------------------------------------------
    -- 1. EN-T TE
    ------------------------------------------------------------------------
    local yc = 26
    if self.texLogo then
        self:drawTextureScaled(self.texLogo, 20, yc, 28, 28, 1.0, 1.0, 1.0, 1.0)
    end
    local histTitle = getTextOrNull("UI_Damocles_History_Title") or "ARCHIVES IRIS -- MISSIONS ACCOMPLIES"
    self:drawText(histTitle, 56, yc + 4, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Medium)

    -- Compteur global
    local summaryText = string.format("%d mission(s) archivee(s)", #completed)
    self:drawTextRight(summaryText, w - 20, yc + 6, self.cGold.r, self.cGold.g, self.cGold.b, 1.0, UIFont.Small)

    -- Separateur
    yc = yc + 34
    self:drawRect(20, yc, w - 40, 1, 0.6, 0.0, 0.6, 0.8)
    yc = yc + 10

    ------------------------------------------------------------------------
    -- 2. LISTE DES MISSIONS ACCOMPLIES
    ------------------------------------------------------------------------
    if #completed == 0 then
        -- Message si aucune mission terminee
        yc = yc + 40
        local emptyText = getTextOrNull("UI_Damocles_History_Empty") or "[ AUCUNE MISSION ARCHIVEE POUR LE MOMENT ]"
        self:drawTextCentre(emptyText, w / 2, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.8, UIFont.Medium)
        yc = yc + 24
        self:drawTextCentre("Accomplissez votre premier objectif sur le terrain", w / 2, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.6, UIFont.Small)
        yc = yc + 18
        self:drawTextCentre("(ex: Etablir la tete de pont QG) pour inscrire l'exploit dans ce registre.", w / 2, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 0.7, UIFont.Small)
        return
    end

    local itemH = 62
    local viewableH = h - yc - 20
    local totalContentH = #completed * (itemH + 8)
    self.maxScroll = math.max(0, totalContentH - viewableH)

    -- Zone avec clipping / scroll
    self:setStencilRect(20, yc, w - 40, viewableH)

    local startY = yc - self.scrollOffset

    for idx, m in ipairs(completed) do
        local boxY = startY + (idx - 1) * (itemH + 8)

        -- Dessiner seulement si visible dans la zone
        if boxY + itemH >= yc and boxY <= yc + viewableH then
            -- Fond de carte de mission archivee
            self:drawRect(20, boxY, w - 40, itemH, 0.45, 0.02, 0.12, 0.16)
            self:drawRectBorder(20, boxY, w - 40, itemH, 0.7, 0.10, 0.70, 0.85)

            -- Badge [[OK] ACCOMPLIE]
            self:drawRect(28, boxY + 8, 100, 18, 0.35, 0.05, 0.35, 0.15)
            self:drawRectBorder(28, boxY + 8, 100, 18, 0.9, self.cOk.r, self.cOk.g, self.cOk.b)
            self:drawTextCentre("[OK] ACCOMPLIE", 78, boxY + 10, self.cOk.r, self.cOk.g, self.cOk.b, 1.0, UIFont.Small)

            -- Titre de la mission
            self:drawText(m.title, 136, boxY + 9, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Small)

            -- Recompense de recherche a droite
            local gainText = string.format("+%d%% RECHERCHE", m.researchGain or 0)
            self:drawTextRight(gainText, w - 32, boxY + 9, self.cGold.r, self.cGold.g, self.cGold.b, 1.0, UIFont.Small)

            -- Description de briefing
            local desc = m.description or "Mission menee a terme avec succes."
            if #desc > 72 then
                desc = string.sub(desc, 1, 69) .. "..."
            end
            self:drawText(desc, 28, boxY + 34, self.cSub.r, self.cSub.g, self.cSub.b, 0.75, UIFont.Small)
        end
    end

    self:clearStencilRect()
end

function DamoclesHistoryWindow:toggle()
    if self:isVisible() then
        self:setVisible(false)
        self:removeFromUIManager()
    else
        self:setVisible(true)
        self:addToUIManager()
    end
end

function DamoclesHistoryWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end
