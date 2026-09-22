require "ISUI/ISCollapsableWindow"
require "UI/DamoclesProgressBar"
require "UI/DamoclesHQWindow"
require "UI/DamoclesHistoryWindow"
require "DamoclesMissionManager"
require "DamoclesMockData"
require "DamoclesGameTime"

---@class DamoclesMainWindow : ISCollapsableWindow
DamoclesMainWindow = ISCollapsableWindow:derive("DamoclesMainWindow")
DamoclesMainWindow.instance = nil

function DamoclesMainWindow:new(x, y, width, height)
    -- Calcul de la taille responsive selon l' cran
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()

    --  chelle adaptative pour petits  crans (ex: 1366x768 ou 720p)
    local targetW = math.min(width or 720, math.floor(screenW * 0.90))
    local targetH = math.min(height or 580, math.floor(screenH * 0.90))
    
    local defaultX = x or math.floor((screenW - targetW) / 2)
    local defaultY = y or math.floor((screenH - targetH) / 2)

    local o = ISCollapsableWindow:new(defaultX, defaultY, targetW, targetH)
    setmetatable(o, self)
    self.__index = self

    o.title = "ISCharacterInfoWindow" -- Style de la barre de titre
    o.resizable = false
    o.pin = true -- Par d faut  pingl , peut  tre d pingl  pour auto-hide
    o.isCollapsed = false
    o.collapseCounter = 0

    -- Palette graphique Cyber-IRIS
    o.cBg = { r = 0.04, g = 0.07, b = 0.09, a = 0.93 }
    o.cBorder = { r = 0.00, g = 0.75, b = 0.90, a = 0.85 }
    o.cCyanText = { r = 0.20, g = 0.95, b = 1.00, a = 1.0 }
    o.cSubText = { r = 0.50, g = 0.80, b = 0.85, a = 0.9 }
    o.cWarning = { r = 1.00, g = 0.55, b = 0.15, a = 1.0 }
    o.cRedAlert = { r = 1.00, g = 0.20, b = 0.20, a = 1.0 }

    -- Animation de clignotement / pulsation
    o.animTimer = 0.0

    -- Chargement des textures optionnelles (avec fallbacks proc duraux int gr s)
    o.texLogo = getTexture("media/textures/Damocles/logo_iris.png")
    o.texGear = getTexture("media/textures/Damocles/icon_gear.png")
    o.texFuel = getTexture("media/textures/Damocles/icon_fuel.png")
    o.texMic = getTexture("media/textures/Damocles/icon_mic.png")
    o.texVial = getTexture("media/textures/Damocles/icon_vial.png")
    o.texWarning = getTexture("media/textures/Damocles/icon_warning.png")
    o.texRadiation = getTexture("media/textures/Damocles/icon_radiation.png")

    DamoclesMainWindow.instance = o
    return o
end

function DamoclesMainWindow:initialise()
    ISCollapsableWindow.initialise(self)

    -- Ajout de la barre de recherche globale segment e
    local contentW = self:getWidth() - 40
    self.researchBar = DamoclesProgressBar:new(20, 112, contentW, 20, true, 34)
    self.researchBar:initialise()
    self:addChild(self.researchBar)

    self:refreshDisplay()
end

function DamoclesMainWindow:collapse()
    ISCollapsableWindow.collapse(self)
    if self.researchBar then
        self.researchBar:setVisible(false)
    end
end

function DamoclesMainWindow:uncollapse()
    ISCollapsableWindow.uncollapse(self)
    if self.researchBar then
        self.researchBar:setVisible(true)
    end
end

--- Construit les donn es d'affichage en prioritisant le state client (MP),
--- puis MissionManager directement (Solo), avec fallback mock en tout dernier recours.
--- @return table displayData pr t pour le prerender
function DamoclesMainWindow:_buildDisplayData()
    -- 1. Si le state client a  t  hydrat  par le serveur
    if DamoclesClientState and DamoclesClientState.initialized then
        local state = DamoclesClientState
        local countdown = DamoclesGameTime.getRemainingGameSeconds(state.deadlineWorldHours)
        return {
            globalResearchPercent = state.globalResearch or 0,
            countdownGameSeconds  = countdown,
            operatorRole          = state.operatorRole or "AGENT IRIS",
            hqStatus              = state.hqStatus or { label = "EN ATTENTE", level = "normal" },
            missions              = state.missions or {},
        }
    end

    -- 2. En Solo / Host local : lecture directe depuis DamoclesMissionManager
    if DamoclesMissionManager and not isClient() then
        DamoclesMissionManager.init()
        local activeMissions = {}
        for _, m in ipairs(DamoclesMissionManager.getActiveMissions()) do
            local mCur = m.currentCount or 0
            local p = getPlayer()

            local extraData = nil
            pcall(function()
                if m.type == "GATHER_FOOD" then
                    local isDone, foodCount, waterCount = DamoclesMissionManager.checkFoodSupplies(p, 20, 4)
                    mCur = (foodCount or 0) + (waterCount or 0)
                    extraData = {
                        isFoodAndWater = true,
                        foodCount = foodCount or 0,
                        foodTarget = 20,
                        waterCount = waterCount or 0,
                        waterTarget = 4,
                    }
                elseif m.type == "SECURE_VEHICLE" then
                    local isDone, steps = DamoclesMissionManager.checkVehicleSecured(p)
                    mCur = steps or (isDone and 3 or 0)
                elseif m.type == "FIND_GENERATOR_FUEL" then
                    mCur = DamoclesMissionManager.checkGeneratorAcquired(p) and 1 or 0
                elseif m.type == "CLEAN_CORPSES" then
                    mCur = DamoclesMissionManager.areCorpsesCleanedInHQ() and 1 or 0
                elseif m.type == "BARRICADE_ACCESS" then
                    mCur = DamoclesMissionManager.isHQBarricaded() and 1 or 0
                elseif m.type == "CONNECT_POWER" then
                    mCur = DamoclesMissionManager.isHQPoweredByGenerator() and 1 or 0
                elseif m.type == "SAFEHOUSE_CLAIM" then
                    mCur = DamoclesMissionManager.getHQBuilding() and 1 or 0
                elseif m.type == "PLACE_OBJECT_SURFACE" then
                    mCur = DamoclesMissionManager.isMissionCompleted("hq_radio") and 1 or 0
                elseif m.type == "HOLD_ITEMS" and m.requiredItems and #m.requiredItems > 0 and p then
                    local inv = p:getInventory()
                    if inv then
                        mCur = inv:getItemCount(m.requiredItems[1])
                    end
                end
            end)

            table.insert(activeMissions, {
                id           = m.id,
                title        = m.title,
                category     = m.category,
                type         = m.type,
                current      = mCur,
                currentCount = mCur,
                target       = m.targetCount or 1,
                targetCount  = m.targetCount or 1,
                unit         = m.unit or "",
                status       = m.status,
                extraData    = extraData,
            })
        end

        return {
            globalResearchPercent = DamoclesMissionManager.getGlobalResearch(),
            countdownGameSeconds  = DamoclesMissionManager.getCountdown(),
            operatorRole          = "AGENT IRIS",
            hqStatus              = DamoclesMissionManager.getHQStatus(),
            missions              = activeMissions,
        }
    end

    -- 3. Fallback mock ultime
    local mock = DamoclesMockData.getData()
    return {
        globalResearchPercent = mock.globalResearchPercent,
        countdownGameSeconds  = mock.countdownSeconds or 0,
        operatorRole          = mock.operatorRole,
        hqStatus              = mock.hqStatus,
        missions              = mock.missions,
    }
end

--- Met   jour la barre de recherche avec les donn es courantes.
function DamoclesMainWindow:refreshDisplay()
    local data = self:_buildDisplayData()
    if self.researchBar then
        self.researchBar:setProgress(data.globalResearchPercent / 100)
    end
end

function DamoclesMainWindow:update()
    ISCollapsableWindow.update(self)

    -- D cr mentation du compte   rebours mock en temps r el
    self.animTimer = self.animTimer + (UIManager.getMillisSinceLastRender() / 1000)
    if self.animTimer >= 1.0 then
        self.animTimer = self.animTimer - 1.0
        local data = DamoclesMockData.getData()
        if data and data.countdownActive and data.countdownSeconds > 0 then
            data.countdownSeconds = data.countdownSeconds - 1
        end
    end

    -- Gestion du comportement Auto-Hide quand la fen tre n'est pas  pingl e (pin = false)
    if not self.pin then
        if self:isMouseOver() then
            if self.isCollapsed then
                self:uncollapse()
            end
            self.collapseCounter = 0
        else
            self.collapseCounter = self.collapseCounter + 1
            -- D lai avant repli
            if self.collapseCounter > 40 and not self.isCollapsed then
                self:collapse()
            end
        end
    end
end

function DamoclesMainWindow:prerender()
    if not self:isVisible() then return end

    local w = self:getWidth()
    local th = self:titleBarHeight()
    -- Si la fen tre est repli e, la hauteur r elle affich e est strictement celle de la barre de titre
    local h = self.isCollapsed and th or self:getHeight()

    -- Fond principal cyber-ardoise (limit    la hauteur active)
    self:drawRect(0, 0, w, h, self.cBg.a, self.cBg.r, self.cBg.g, self.cBg.b)

    -- Bordure n on avec reflets (limit e   la hauteur active)
    self:drawRectBorder(0, 0, w, h, self.cBorder.a, self.cBorder.r, self.cBorder.g, self.cBorder.b)
    self:drawRectBorder(1, 1, w - 2, h - 2, 0.35, 0.0, 0.40, 0.50)

    -- Si repli , on s'arr te ici : aucun r sidu ni carr  vide en dessous !
    if self.isCollapsed then return end

    local data = self:_buildDisplayData()
    local pulse = 0.75 + (math.sin(getTimeInMillis() / 250) * 0.25)

    ------------------------------------------------------------------------
    -- 1. HEADER : IDENTIT  IRIS & FONCTION
    ------------------------------------------------------------------------
    local headerY = 28

    -- Logo IRIS
    if self.texLogo then
        self:drawTextureScaled(self.texLogo, 20, headerY, 46, 46, 1.0, 1.0, 1.0, 1.0)
    else
        -- Fallback logo pixel art
        self:drawRect(20, headerY, 46, 46, 0.8, 0.02, 0.12, 0.18)
        self:drawRectBorder(20, headerY, 46, 46, 0.9, 0.0, 0.8, 1.0)
        self:drawTextCentre("IRIS", 43, headerY + 14, self.cCyanText.r, self.cCyanText.g, self.cCyanText.b, 1.0, UIFont.Medium)
    end

    -- Titre principal
    local titleText = getTextOrNull("UI_Damocles_Title") or "IRIS - PROJET DAMOCLES"
    self:drawText(titleText, 80, headerY + 2, self.cCyanText.r, self.cCyanText.g, self.cCyanText.b, 1.0, UIFont.Large)

    -- Badge Fonction / Role
    local badgeX = 80
    local badgeY = headerY + 30
    local badgeW = 340
    local badgeH = 26
    self:drawRect(badgeX, badgeY, badgeW, badgeH, 0.4, 0.0, 0.2, 0.25)
    self:drawRectBorder(badgeX, badgeY, badgeW, badgeH, 0.6, 0.0, 0.7, 0.8)

    -- Icone engrenage
    if self.texGear then
        self:drawTextureScaled(self.texGear, badgeX + 6, badgeY + 3, 20, 20, 1.0, 1.0, 1.0, 1.0)
    else
        self:drawRect(badgeX + 6, badgeY + 5, 16, 16, 0.8, 0.3, 0.9, 0.6)
    end
    self:drawText("FONCTION : " .. (data.operatorRole or "SURVIVANT"), badgeX + 32, badgeY + 4, 0.4, 1.0, 0.6, 1.0, UIFont.Small)

    ------------------------------------------------------------------------
    -- 2. RECHERCHE GLOBALE
    ------------------------------------------------------------------------
    local resY = 90
    local resPrefix = getTextOrNull("UI_Damocles_Research") or "RECHERCHE GLOBALE :"
    local resText = string.format("%s [====-----]  %d%%", resPrefix, data.globalResearchPercent or 0)
    self:drawText(resText, 20, resY, self.cCyanText.r, self.cCyanText.g, self.cCyanText.b, 1.0, UIFont.Medium)

    ------------------------------------------------------------------------
    -- 3. MISSIONS EN COURS & BOUTON ARCHIVES
    ------------------------------------------------------------------------
    local misHeaderY = 160
    self:drawText("MISSIONS EN COURS :", 20, misHeaderY, self.cCyanText.r, self.cCyanText.g, self.cCyanText.b, 1.0, UIFont.Medium)

    -- Bouton [ ARCHIVES ] (ouvre l'historique des missions compl t es)
    local histBtnW = 120
    local histBtnH = 22
    local histBtnX = w - histBtnW - 20
    local histBtnY = misHeaderY - 2
    local mx = self:getMouseX()
    local my = self:getMouseY()
    local isHoverHist = mx >= histBtnX and mx <= (histBtnX + histBtnW) and my >= histBtnY and my <= (histBtnY + histBtnH)

    self:drawRect(histBtnX, histBtnY, histBtnW, histBtnH, isHoverHist and 0.60 or 0.30, 0.0, 0.20, 0.25)
    local archivesBtnText = getTextOrNull("UI_Damocles_Archives") or "ARCHIVES [OK]"
    self:drawTextCentre(archivesBtnText, histBtnX + histBtnW / 2, histBtnY + 3, self.cCyanText.r, self.cCyanText.g, self.cCyanText.b, isHoverHist and 1.0 or 0.85, UIFont.Small)

    local misBaseY = 192
    local misStepY = 46
    local barW = math.floor(w * 0.44)
    local barH = 11

    if data.missions then
        for i, m in ipairs(data.missions) do
            local curY = misBaseY + (i - 1) * misStepY

            -- Icone mission adaptee selon la categorie
            local iconTex = nil
            if m.type == "RADIO_CONTACT" or m.type == "RADIO_CRYPTO_FINAL" or m.category == "RADIO" then
                iconTex = self.texMic
            elseif m.category == "HQ" then
                iconTex = self.texLogo or self.texGear
            elseif m.category == "VACCINE" then
                iconTex = self.texVial
            elseif m.category == "LOGISTICS" then
                iconTex = self.texFuel
            elseif m.category == "INTEL" then
                iconTex = self.texMic
            else
                iconTex = (i == 1 and self.texFuel) or (i == 2 and self.texMic) or (i == 3 and self.texVial)
            end

            if iconTex then
                self:drawTextureScaled(iconTex, 24, curY, 28, 28, 1.0, 1.0, 1.0, 1.0)
            else
                self:drawRect(24, curY, 28, 28, 0.6, 0.0, 0.3, 0.4)
                self:drawRectBorder(24, curY, 28, 28, 0.8, 0.0, 0.8, 1.0)
            end

            -- Titre mission
            local isRadioContact = (m.type == "RADIO_CONTACT" or m.type == "RADIO_CRYPTO_FINAL")
            local titleCol = isRadioContact and self.cWarning or { r = 0.85, g = 0.95, b = 1.0 }
            self:drawText(m.title, 62, curY, titleCol.r, titleCol.g, titleCol.b, isRadioContact and pulse or 1.0, UIFont.Small)

            if m.extraData and m.extraData.isFoodAndWater then
                -- LIGNE 1 : Conserves alimentaires
                local fPct = math.min(1.0, (m.extraData.foodCount or 0) / (m.extraData.foodTarget or 20))
                local barX = 62
                local barY1 = curY + 14
                self:drawRect(barX, barY1, barW, 8, 0.85, 0.02, 0.08, 0.12)
                if fPct > 0 then
                    self:drawRect(barX + 1, barY1 + 1, math.floor((barW - 2) * fPct), 6, 0.9, 0.0, 0.80, 0.95)
                end
                self:drawRectBorder(barX, barY1, barW, 8, 0.6, 0.0, 0.50, 0.65)
                local foodText = string.format("Conserves : [%d/%d]", m.extraData.foodCount, m.extraData.foodTarget)
                self:drawText(foodText, barX + barW + 12, barY1 - 2, self.cSubText.r, self.cSubText.g, self.cSubText.b, 0.95, UIFont.Small)

                -- LIGNE 2 : Reserves d'eau et boissons
                local wPct = math.min(1.0, (m.extraData.waterCount or 0) / (m.extraData.waterTarget or 4))
                local barY2 = curY + 26
                self:drawRect(barX, barY2, barW, 8, 0.85, 0.02, 0.08, 0.12)
                if wPct > 0 then
                    self:drawRect(barX + 1, barY2 + 1, math.floor((barW - 2) * wPct), 6, 0.9, 0.2, 0.95, 0.70)
                end
                self:drawRectBorder(barX, barY2, barW, 8, 0.6, 0.1, 0.60, 0.50)
                local waterText = string.format("Reserves Eau : [%d/%d]", m.extraData.waterCount, m.extraData.waterTarget)
                self:drawText(waterText, barX + barW + 12, barY2 - 2, self.cCyanText.r, self.cCyanText.g, self.cCyanText.b, 0.95, UIFont.Small)
            else
                -- Compteur de progression securise standard
                local mCur = m.current or m.currentCount or 0
                local mTgt = m.target or m.targetCount or 1
                local mUnit = m.unit or ""

                local countText
                if isRadioContact then
                    countText = "[!] LIAISON TERMINAL REQUISE"
                else
                    countText = string.format("[%d/%d] %s", mCur, mTgt, mUnit)
                end
                self:drawText(countText, 64 + barW + 16, curY + 14, isRadioContact and self.cWarning.r or self.cSubText.r, isRadioContact and self.cWarning.g or self.cSubText.g, isRadioContact and self.cWarning.b or self.cSubText.b, 0.95, UIFont.Small)

                -- Mini barre de progression standard
                local barX = 62
                local barY = curY + 16
                local pct = (mTgt > 0) and math.min(1.0, mCur / mTgt) or 0

                self:drawRect(barX, barY, barW, barH, 0.85, 0.02, 0.08, 0.12)
                if pct > 0 then
                    self:drawRect(barX + 1, barY + 1, math.floor((barW - 2) * pct), barH - 2, 0.9, 0.0, 0.80, 0.95)
                end
                self:drawRectBorder(barX, barY, barW, barH, 0.6, 0.0, 0.50, 0.65)
            end
        end
    end

    ------------------------------------------------------------------------
    ------------------------------------------------------------------------
    -- 4. FOOTER : ETAT QG IRIS & ALERTE DAMOCLES
    ------------------------------------------------------------------------
    local footerY = h - 110
    local boxW = math.floor((w - 55) / 2)
    local boxH = 88

    -- BLOC GAUCHE : ETAT QG IRIS
    local qgX = 20
    local hqTitleText = getTextOrNull("UI_Damocles_HQStatus") or "ETAT QG IRIS :"
    self:drawText(hqTitleText, qgX, footerY - 18, self.cCyanText.r, self.cCyanText.g, self.cCyanText.b, 1.0, UIFont.Small)

    self:drawRect(qgX, footerY, boxW, boxH, 0.5, 0.15, 0.05, 0.02)
    self:drawRectBorder(qgX, footerY, boxW, boxH, pulse * 0.9, self.cWarning.r, self.cWarning.g, self.cWarning.b)

    -- Icone Warning
    if self.texWarning then
        self:drawTextureScaled(self.texWarning, qgX + 12, footerY + 12, 30, 30, 1.0, 1.0, 1.0, 1.0)
    else
        self:drawRect(qgX + 14, footerY + 14, 26, 26, 0.9, 1.0, 0.5, 0.0)
    end
    self:drawText(data.hqStatus.label, qgX + 50, footerY + 18, self.cWarning.r, self.cWarning.g, self.cWarning.b, pulse, UIFont.Small)

    -- Bouton tactique explicite : CENTRE DE COMMANDE DU QG
    local mx = self:getMouseX()
    local my = self:getMouseY()
    local hqBtnX = qgX + 10
    local hqBtnY = footerY + boxH - 28
    local hqBtnW = boxW - 20
    local hqBtnH = 22
    local isHoverHQBtn = mx >= hqBtnX and mx <= (hqBtnX + hqBtnW) and my >= hqBtnY and my <= (hqBtnY + hqBtnH)

    self:drawRect(hqBtnX, hqBtnY, hqBtnW, hqBtnH, isHoverHQBtn and 0.85 or 0.45, 0.0, 0.25, 0.35)
    self:drawRectBorder(hqBtnX, hqBtnY, hqBtnW, hqBtnH, isHoverHQBtn and 1.0 or 0.75, self.cCyanText.r, self.cCyanText.g, self.cCyanText.b)
    local cmdBtnText = getTextOrNull("UI_Damocles_HQ_CommandCenterBtn") or "CENTRE DE COMMANDE QG"
    self:drawTextCentre(cmdBtnText, hqBtnX + hqBtnW / 2, hqBtnY + 3, isHoverHQBtn and 1.0 or 0.85, isHoverHQBtn and 1.0 or 0.95, 1.0, 1.0, UIFont.Small)

    -- BLOC DROIT : ALERTE DAMOCLES (COMPTE A REBOURS)
    local damoX = qgX + boxW + 15
    local alertTitleText = getTextOrNull("UI_Damocles_Alert") or "ALERTE DAMOCLES :"
    self:drawText(alertTitleText, damoX, footerY - 18, self.cRedAlert.r, 0.6, 0.6, 1.0, UIFont.Small)

    self:drawRect(damoX, footerY, boxW, boxH, 0.6, 0.20, 0.02, 0.02)
    self:drawRectBorder(damoX, footerY, boxW, boxH, 0.95, self.cRedAlert.r, self.cRedAlert.g, self.cRedAlert.b)

    -- Ic ne Nucl aire
    if self.texRadiation then
        self:drawTextureScaled(self.texRadiation, damoX + 12, footerY + 12, 30, 30, 1.0, 1.0, 1.0, 1.0)
    else
        self:drawRect(damoX + 14, footerY + 14, 26, 26, 0.9, 0.9, 0.1, 0.1)
    end

    -- Affichage digital compte   rebours (format  par DamoclesGameTime)
    local cdText = DamoclesGameTime.formatGameSeconds(data.countdownGameSeconds or 0)
    self:drawText(cdText, damoX + 50, footerY + 14, self.cRedAlert.r, 0.3, 0.3, 1.0, UIFont.Large)

    -- Bandeau informatif d'urgence sous le compte   rebours
    self:drawText("PROTOCOLE DE SURVIE EN COURS", damoX + 50, footerY + boxH - 24, self.cSubText.r, self.cSubText.g, self.cSubText.b, 0.8, UIFont.Small)
end

function DamoclesMainWindow:onMouseDown(x, y)
    if self.isCollapsed then
        return ISCollapsableWindow.onMouseDown(self, x, y)
    end

    local w = self:getWidth()
    local h = self:getHeight()
    local footerY = h - 110
    local boxW = math.floor((w - 55) / 2)
    local boxH = 88
    local qgX = 20

    -- D tection du clic sur le bouton ARCHIVES [ ]
    local histBtnW = 120
    local histBtnH = 22
    local histBtnX = w - histBtnW - 20
    local histBtnY = 160 - 2
    if x >= histBtnX and x <= (histBtnX + histBtnW) and y >= histBtnY and y <= (histBtnY + histBtnH) then
        if not DamoclesHistoryWindow.instance then
            local hw = DamoclesHistoryWindow:new()
            hw:initialise()
            hw:addToUIManager()
            hw:setVisible(true)
        else
            DamoclesHistoryWindow.instance:toggle()
        end
        return true
    end

    -- D tection du clic sur le bloc  TAT QG IRIS ou son bouton   ouvre / bascule DamoclesHQWindow
    if x >= qgX and x <= (qgX + boxW) and y >= footerY and y <= (footerY + boxH) then
        if not DamoclesHQWindow.instance then
            local hqWin = DamoclesHQWindow:new()
            hqWin:initialise()
            hqWin:addToUIManager()
            hqWin:setVisible(true)
        else
            DamoclesHQWindow.instance:toggle()
        end
        return true
    end

    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function DamoclesMainWindow:toggle()
    if self:isVisible() then
        self:setVisible(false)
        self:removeFromUIManager()
    else
        self:setVisible(true)
        self:addToUIManager()
        self:refreshDisplay()
        -- Demande de synchronisation de l' tat au serveur
        sendClientCommand("DamoclesClient", "RequestState", {})
    end
end

function DamoclesMainWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end
