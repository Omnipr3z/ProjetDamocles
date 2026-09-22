--[[
    PROJET DAMOCL S - DamoclesHQWindow.lua
    Fen tre de gestion du QG IRIS.

    Responsabilit s :
        - Afficher le statut d' tablissement du QG (revendiqu  / non revendiqu )
        - Afficher la progression des am liorations (Radio, G n rateur)
        - Afficher le niveau de menace de horde (barre de danger)
        - Indiquer les coordonn es et le b timent du QG
        - S'ouvrir depuis le bloc "ETAT QG IRIS" de DamoclesMainWindow

    S'ouvre via DamoclesHQWindow.toggle() ou DamoclesHQWindow.instance:toggle()
]]

require "ISUI/ISCollapsableWindow"
require "DamoclesGameTime"

---@class DamoclesHQWindow : ISCollapsableWindow
DamoclesHQWindow = ISCollapsableWindow:derive("DamoclesHQWindow")
DamoclesHQWindow.instance = nil

------------------------------------------------------------------------
-- Am liorations du QG, ordonn es et libell es
-- Li es aux missions de la DB par leur id
------------------------------------------------------------------------
local HQ_UPGRADES = {
    { missionId = "hq_radio",          label = "TERMINAL RADIO",            icon = "icon_mic"  },
    { missionId = "task_3_lab_station", label = "LABORATOIRE & GENERATEUR", icon = "icon_gear" },
    -- Extensible : ajouter ici les futures ameliorations Phase 3-4
}

------------------------------------------------------------------------
-- Constructeur
------------------------------------------------------------------------

function DamoclesHQWindow:new(x, y)
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()

    -- Fen tre plus compacte que la principale
    local w = math.min(480, math.floor(screenW * 0.60))
    local h = math.min(380, math.floor(screenH * 0.65))

    local px = x or math.floor(screenW * 0.5 - w / 2)
    local py = y or math.floor(screenH * 0.5 - h / 2)

    local o = ISCollapsableWindow:new(px, py, w, h)
    setmetatable(o, self)
    self.__index = self

    o.title = "ISCharacterInfoWindow"  -- Style barre PZ
    o.resizable = false
    o.pin = true
    o.isCollapsed = false
    o.collapseCounter = 0
    o.animTimer = 0.0

    -- Palette
    o.cBg      = { r = 0.04, g = 0.07, b = 0.09, a = 0.95 }
    o.cBorder  = { r = 0.00, g = 0.75, b = 0.90, a = 0.85 }
    o.cCyan    = { r = 0.20, g = 0.95, b = 1.00, a = 1.0  }
    o.cSub     = { r = 0.50, g = 0.80, b = 0.85, a = 0.9  }
    o.cOk      = { r = 0.20, g = 0.90, b = 0.40, a = 1.0  }
    o.cWarn    = { r = 1.00, g = 0.55, b = 0.15, a = 1.0  }
    o.cDanger  = { r = 1.00, g = 0.20, b = 0.20, a = 1.0  }
    o.cLocked  = { r = 0.35, g = 0.35, b = 0.40, a = 0.8  }

    -- Textures (fallbacks proc si absentes)
    o.texWarning   = getTexture("media/textures/Damocles/icon_warning.png")
    o.texGear      = getTexture("media/textures/Damocles/icon_gear.png")
    o.texMic       = getTexture("media/textures/Damocles/icon_mic.png")

    DamoclesHQWindow.instance = o
    return o
end

------------------------------------------------------------------------
-- Initialisation
------------------------------------------------------------------------

function DamoclesHQWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

------------------------------------------------------------------------
-- Donn es d'affichage (m me pattern que MainWindow : client state ou mock)
------------------------------------------------------------------------

function DamoclesHQWindow:_buildHQData()
    -- Lecture depuis DamoclesClientState si disponible, sinon fallback Solo ou mock
    local missions = {}
    local hqStatus = { label = "NON ETABLI", level = "normal" }
    local hqLocation = nil
    local hqBuilding = nil
    local threatLevel = 0

    if DamoclesClientState and DamoclesClientState.initialized then
        hqStatus    = DamoclesClientState.hqStatus or hqStatus
        hqLocation  = DamoclesClientState.hqLocation
        hqBuilding  = DamoclesClientState.hqBuilding
        threatLevel = DamoclesClientState.threatLevel or 0
        for _, m in ipairs(DamoclesClientState.missions or {}) do
            missions[m.id] = m
        end
    elseif DamoclesMissionManager and not isClient() then
        -- En Solo / Host local : lecture directe depuis le Manager
        hqStatus    = DamoclesMissionManager.getHQStatus() or hqStatus
        hqLocation  = DamoclesMissionManager.getHQLocation()
        hqBuilding  = DamoclesMissionManager.getHQBuilding()
        threatLevel = 0
        for _, m in ipairs(DamoclesMissionDB.getAll()) do
            missions[m.id] = m
        end
    else
        -- Mock : simuler quelques etats pour le developpement UI
        missions["hq_claim"]     = { status = "COMPLETED" }
        missions["hq_radio"]     = { status = "ACTIVE",    currentCount = 0, targetCount = 1 }
        missions["hq_generator"] = { status = "LOCKED",    currentCount = 0, targetCount = 1 }
        hqStatus  = { label = "QG ETABLI - EN ATTENTE", level = "normal" }
        hqLocation = { x = 7418, y = 6985 }
        threatLevel = 25  -- 25% de menace pour le mock
    end

    return {
        missions    = missions,
        hqStatus    = hqStatus,
        hqLocation  = hqLocation,
        hqBuilding  = hqBuilding,
        threatLevel = threatLevel,
    }
end

------------------------------------------------------------------------
-- Update : Auto-hide & animation
------------------------------------------------------------------------

function DamoclesHQWindow:update()
    ISCollapsableWindow.update(self)
    self.animTimer = self.animTimer + (UIManager.getMillisSinceLastRender() / 1000)

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

------------------------------------------------------------------------
-- Prerender
------------------------------------------------------------------------

function DamoclesHQWindow:prerender()
    if not self:isVisible() then return end

    local w = self:getWidth()
    local th = self:titleBarHeight()
    local h = self.isCollapsed and th or self:getHeight()

    -- Fond & bordure
    self:drawRect(0, 0, w, h, self.cBg.a, self.cBg.r, self.cBg.g, self.cBg.b)
    self:drawRectBorder(0, 0, w, h, self.cBorder.a, self.cBorder.r, self.cBorder.g, self.cBorder.b)
    self:drawRectBorder(1, 1, w - 2, h - 2, 0.30, 0.0, 0.40, 0.50)

    if self.isCollapsed then return end

    local data = self:_buildHQData()
    local pulse = 0.75 + (math.sin(getTimeInMillis() / 300) * 0.25)

    --------------------------------------------------------------------
    -- 1. TITRE DE SECTION
    --------------------------------------------------------------------
    local yc = 28
    local hqTitle = getTextOrNull("UI_Damocles_HQ_Title") or "QG IRIS -- STATUT & AMELIORATIONS"
    self:drawText(hqTitle, 20, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Medium)

    -- Separateur
    yc = yc + 22
    self:drawRect(20, yc, w - 40, 1, 0.6, 0.0, 0.6, 0.8)

    --------------------------------------------------------------------
    -- 2. STATUT D'ETABLISSEMENT
    --------------------------------------------------------------------
    yc = yc + 10
    local claimMission = data.missions["hq_claim"]
    local isEstablished = claimMission and claimMission.status == "COMPLETED"

    -- Bloc de statut global
    local statusColor = self.cLocked
    local statusLabel = getTextOrNull("UI_Damocles_HQ_NotEstablished") or "[!] QG NON ETABLI - MISSION ACTIVE REQUISE"
    if isEstablished then
        local lvl = data.hqStatus.level or "normal"
        if lvl == "critical" then
            statusColor = self.cDanger
        elseif lvl == "warning" then
            statusColor = self.cWarn
        else
            statusColor = self.cOk
        end
        statusLabel = data.hqStatus.label or (getTextOrNull("UI_Damocles_HQ_Operational") or "OPERATIONNEL")
    end

    local blockH = 36
    self:drawRect(20, yc, w - 40, blockH, 0.5, statusColor.r * 0.15, statusColor.g * 0.15, statusColor.b * 0.15)
    self:drawRectBorder(20, yc, w - 40, blockH, pulse * 0.85, statusColor.r, statusColor.g, statusColor.b)
    self:drawText(statusLabel, 32, yc + 10, statusColor.r, statusColor.g, statusColor.b, pulse, UIFont.Small)

    -- Coordonn es du QG si  tabli
    yc = yc + blockH + 8
    if isEstablished and data.hqLocation then
        local locText = string.format("POSITION : %d, %d", data.hqLocation.x, data.hqLocation.y)
        if data.hqBuilding and data.hqBuilding.roomName then
            locText = locText .. " [" .. tostring(data.hqBuilding.roomName) .. "]"
        end
        self:drawText(locText, 24, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.8, UIFont.Small)
        yc = yc + 18
    end

    -- S parateur
    self:drawRect(20, yc, w - 40, 1, 0.5, 0.0, 0.5, 0.7)
    yc = yc + 10

    --------------------------------------------------------------------
    -- 3. AMELIORATIONS DU QG
    --------------------------------------------------------------------
    local upgradesTitle = getTextOrNull("UI_Damocles_HQ_Upgrades") or "AMELIORATIONS :"
    self:drawText(upgradesTitle, 20, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Small)
    yc = yc + 20

    for idx, upgrade in ipairs(HQ_UPGRADES) do
        local m = data.missions[upgrade.missionId]
        local status = m and m.status or "LOCKED"

        -- Couleur et label selon statut
        local col, statusTag
        if status == "COMPLETED" then
            col = self.cOk
            statusTag = "[ OK ]"
        elseif status == "ACTIVE" then
            col = self.cWarn
            statusTag = "[ EN COURS ]"
        else
            col = self.cLocked
            statusTag = "[ VERROUILLE ]"
        end

        -- Fond de la ligne
        local lineH = 34
        local lineAlpha = (status == "LOCKED") and 0.2 or 0.45
        self:drawRect(20, yc, w - 40, lineH, lineAlpha, col.r * 0.1, col.g * 0.1, col.b * 0.1)
        self:drawRectBorder(20, yc, w - 40, lineH, (status == "LOCKED") and 0.3 or 0.7, col.r, col.g, col.b)

        -- Ic ne (proc)
        local iconSize = 20
        local iconX = 30
        local iconY = yc + 7
        self:drawRect(iconX, iconY, iconSize, iconSize, 0.8, col.r * 0.3, col.g * 0.3, col.b * 0.3)
        self:drawRectBorder(iconX, iconY, iconSize, iconSize, 0.9, col.r, col.g, col.b)
        self:drawTextCentre(tostring(idx), iconX + iconSize / 2, iconY + 4, col.r, col.g, col.b, 1.0, UIFont.Small)

        -- Label
        local labelAlpha = (status == "LOCKED") and 0.5 or 1.0
        self:drawText(upgrade.label, iconX + iconSize + 10, yc + 9, col.r, col.g, col.b, labelAlpha, UIFont.Small)

        -- Tag de statut (  droite)
        self:drawText(statusTag, w - 130, yc + 9, col.r, col.g, col.b, (status == "ACTIVE") and pulse or labelAlpha, UIFont.Small)

        -- Mini barre de progression si ACTIVE
        if status == "ACTIVE" and m and m.targetCount and m.targetCount > 0 then
            local pct = math.min(1.0, (m.currentCount or 0) / m.targetCount)
            local barX = iconX + iconSize + 10
            local barY = yc + lineH - 8
            local barW = w - barX - 50
            self:drawRect(barX, barY, barW, 4, 0.7, 0.05, 0.05, 0.08)
            self:drawRect(barX, barY, math.floor(barW * pct), 4, 0.9, col.r, col.g, col.b)
        end

        yc = yc + lineH + 6
    end

    -- S parateur
    self:drawRect(20, yc, w - 40, 1, 0.5, 0.0, 0.5, 0.7)
    yc = yc + 10

    --------------------------------------------------------------------
    -- 4. INDICATEUR DE MENACE (Barre de Danger)
    --------------------------------------------------------------------
    local threatTitle = getTextOrNull("UI_Damocles_HQ_Threat") or "NIVEAU DE MENACE PERIMETRE :"
    self:drawText(threatTitle, 20, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Small)
    yc = yc + 18

    local threatPct = math.min(1.0, (data.threatLevel or 0) / 100.0)
    local barW = w - 90
    local barH = 18

    -- Couleur de la barre selon le niveau
    local tCol
    if threatPct >= 0.7 then
        tCol = self.cDanger
    elseif threatPct >= 0.35 then
        tCol = self.cWarn
    else
        tCol = self.cOk
    end

    -- Fond
    self:drawRect(20, yc, barW, barH, 0.8, 0.05, 0.02, 0.02)
    -- Remplissage
    if threatPct > 0 then
        self:drawRect(21, yc + 1, math.floor((barW - 2) * threatPct), barH - 2, pulse * 0.9, tCol.r, tCol.g, tCol.b)
    end
    -- Bordure
    self:drawRectBorder(20, yc, barW, barH, 0.7, tCol.r, tCol.g, tCol.b)

    -- Pourcentage
    local threatLabel = string.format("%d%%", math.floor(threatPct * 100))
    self:drawText(threatLabel, barW + 26, yc + 1, tCol.r, tCol.g, tCol.b, 1.0, UIFont.Small)

    -- Legende
    yc = yc + barH + 8
    if threatPct >= 0.7 then
        local siegeText = getTextOrNull("UI_Damocles_HQ_Siege") or "[!] SIEGE IMMINENT -- SECURISEZ LE PERIMETRE"
        self:drawText(siegeText, 20, yc, self.cDanger.r, self.cDanger.g, self.cDanger.b, pulse, UIFont.Small)
    elseif threatPct >= 0.35 then
        local warnText = getTextOrNull("UI_Damocles_HQ_ZombiesNearby") or "ZOMBIES DETECTES A PROXIMITE DU QG"
        self:drawText(warnText, 20, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 0.9, UIFont.Small)
    elseif isEstablished then
        local safeText = getTextOrNull("UI_Damocles_HQ_Safe") or "ZONE SECURISEE -- AUCUNE MENACE DETECTEE"
        self:drawText(safeText, 20, yc, self.cOk.r, self.cOk.g, self.cOk.b, 0.7, UIFont.Small)
    end
end

------------------------------------------------------------------------
-- Toggle & Close
------------------------------------------------------------------------

function DamoclesHQWindow:toggle()
    if self:isVisible() then
        self:setVisible(false)
        self:removeFromUIManager()
    else
        self:setVisible(true)
        self:addToUIManager()
    end
end

function DamoclesHQWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end
