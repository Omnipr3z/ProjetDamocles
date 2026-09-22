--[[
    PROJET DAMOCL S - DamoclesIntroWindow.lua
    Fen tre de briefing op rationnel affich e au chargement d'une nouvelle partie.

    Responsabilit s :
        - Exposer le contexte narratif et l'urgence (compte   rebours Damocl s)
        - Expliquer les m caniques fondamentales :
            1.  tablissement du QG par clic droit dans un b timent (Op rateur IRIS)
            2. Pose de la radio et du g n rateur
            3. Progression des 5 phases de recherche du vaccin
            4. Surveillance du radar de menace zombie
            5. Raccourcis : bouton HUD draggable, touche K, archives
        - Fournir un bouton d'acceptation de la mission
]]

require "ISUI/ISCollapsableWindow"

---@class DamoclesIntroWindow : ISCollapsableWindow
DamoclesIntroWindow = ISCollapsableWindow:derive("DamoclesIntroWindow")
DamoclesIntroWindow.instance = nil

function DamoclesIntroWindow:new(x, y)
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()

    local w = math.min(700, math.floor(screenW * 0.92))
    local h = math.min(620, math.floor(screenH * 0.94))

    local px = x or math.floor((screenW - w) / 2)
    local py = y or math.floor((screenH - h) / 2)

    local o = ISCollapsableWindow:new(px, py, w, h)
    setmetatable(o, self)
    self.__index = self

    o.title = "ISCharacterInfoWindow"
    o.resizable = false
    o.pin = true
    o.isCollapsed = false

    -- Palette Cyber-Ardoise sans reflets excessifs
    o.cBg     = { r = 0.03, g = 0.06, b = 0.08, a = 0.97 }
    o.cBorder = { r = 0.00, g = 0.75, b = 0.90, a = 0.90 }
    o.cCyan   = { r = 0.20, g = 0.95, b = 1.00, a = 1.0 }
    o.cSub    = { r = 0.55, g = 0.80, b = 0.85, a = 0.9 }
    o.cOk     = { r = 0.20, g = 0.90, b = 0.40, a = 1.0 }
    o.cWarn   = { r = 1.00, g = 0.60, b = 0.20, a = 1.0 }
    o.cRed    = { r = 1.00, g = 0.25, b = 0.25, a = 1.0 }

    -- Textures
    o.texLogo = getTexture("media/textures/Damocles/logo_iris.png")

    DamoclesIntroWindow.instance = o
    return o
end

function DamoclesIntroWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function DamoclesIntroWindow:prerender()
    if not self:isVisible() then return end

    local w = self:getWidth()
    local h = self:getHeight()

    -- Fond sombre
    self:drawRect(0, 0, w, h, self.cBg.a, self.cBg.r, self.cBg.g, self.cBg.b)
    self:drawRectBorder(0, 0, w, h, self.cBorder.a, self.cBorder.r, self.cBorder.g, self.cBorder.b)
    self:drawRectBorder(1, 1, w - 2, h - 2, 0.35, 0.0, 0.40, 0.50)

    local yc = 24

    ------------------------------------------------------------------------
    -- 1. EN-TETE NARRATIF
    ------------------------------------------------------------------------
    if self.texLogo then
        self:drawTextureScaled(self.texLogo, 22, yc, 36, 36, 1.0, 1.0, 1.0, 1.0)
    end
    local introTitle = getTextOrNull("UI_Damocles_Intro_Title") or "OPERATION DAMOCLES -- BRIEFING TACTIQUE"
    self:drawText(introTitle, 68, yc + 2, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Medium)
    local introDest = getTextOrNull("UI_Damocles_Intro_Dest") or "DESTINATAIRE : UNITE ALPHA (OPERATION IRIS)"
    self:drawText(introDest, 68, yc + 20, self.cSub.r, self.cSub.g, self.cSub.b, 0.85, UIFont.Small)

    yc = yc + 44
    self:drawRect(20, yc, w - 40, 1, 0.6, 0.0, 0.6, 0.8)
    yc = yc + 8

    ------------------------------------------------------------------------
    -- 2. LE CONTEXTE & L'URGENCE
    ------------------------------------------------------------------------
    self:drawText("ALERTE MAXIMALE : COMPTE A REBOURS ORBITAL ENCLENCHE", 22, yc, self.cRed.r, self.cRed.g, self.cRed.b, 1.0, UIFont.Small)
    yc = yc + 15
    local protoText = getTextOrNull("UI_Damocles_Intro_Protocol") or "Un protocole mondial d'eradication a ete initie. A l'echeance, le secteur d'operation sera totalement sterilise."
    self:drawText(protoText, 22, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
    yc = yc + 14
    self:drawText("Votre mission : developper le vaccin pour obtenir l'annulation de la frappe et votre extraction tactique.", 22, yc, self.cOk.r, self.cOk.g, self.cOk.b, 1.0, UIFont.Small)

    yc = yc + 20
    self:drawRect(20, yc, w - 40, 1, 0.4, 0.0, 0.4, 0.6)
    yc = yc + 8

    ------------------------------------------------------------------------
    -- 3. INFILTRATION SOUS COUVERTURE CIVILE OU RALLIEMENT QG
    ------------------------------------------------------------------------
    local isHQClaimed = DamoclesMissionManager and (DamoclesMissionManager.getHQBuilding() ~= nil)

    if isHQClaimed then
        self:drawText("TETE DE PONT ACTIVE // RALLIEMENT QG ALPHA :", 22, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Small)
        yc = yc + 15
        self:drawText("La tete de pont operationnelle a deja ete securisee par l'Unite ALPHA.", 22, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)
        yc = yc + 14

        local comrades = {}
        if isClient() and getOnlinePlayers then
            local players = getOnlinePlayers()
            if players then
                for pIdx = 0, players:size() - 1 do
                    local op = players:get(pIdx)
                    if op and op ~= getPlayer() then
                        table.insert(comrades, op:getUsername())
                    end
                end
            end
        end
        local comText = (#comrades > 0) and ("Operateurs actifs sur zone : " .. table.concat(comrades, ", ")) or "Operateurs de l'Unite ALPHA deja deployes sur le terrain."
        self:drawText(comText, 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 0.95, UIFont.Small)
        yc = yc + 14
        self:drawText("Rejoignez immediatement le QG et portez assistance a vos coequipiers.", 22, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)
        yc = yc + 14
        self:drawText("Le repere tactique [IRIS] QG ALPHA est synchronise sur votre carte du monde (Touche M).", 22, yc, self.cOk.r, self.cOk.g, self.cOk.b, 0.95, UIFont.Small)
    else
        local coverTitle = getTextOrNull("UI_Damocles_Intro_Cover_Title") or "INFILTRATION SOUS COUVERTURE CIVILE :"
        self:drawText(coverTitle, 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        yc = yc + 15
        local cover1 = getTextOrNull("UI_Damocles_Intro_Cover_1") or "L'Unite ALPHA opere en tenue civile pour ne pas eveiller la curiosite ni semer la panique."
        self:drawText(cover1, 22, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)
        yc = yc + 14
        local cover2 = getTextOrNull("UI_Damocles_Intro_Cover_2") or "Cette necessite de discretion explique l'absence initiale d'un contingent militaire lourd."
        self:drawText(cover2, 22, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)
        yc = yc + 14
        local cover3 = getTextOrNull("UI_Damocles_Intro_Cover_3") or "Votre tenue de combat, protections et le terminal HamRadio2 sont places dans votre inventaire."
        self:drawText(cover3, 22, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 0.95, UIFont.Small)
        yc = yc + 14
        local cover4 = getTextOrNull("UI_Damocles_Intro_Cover_4") or "Vous pourrez vous equiper et etablir votre station des la securisation de la tete de pont."
        self:drawText(cover4, 22, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)
    end

    yc = yc + 20
    self:drawRect(20, yc, w - 40, 1, 0.4, 0.0, 0.4, 0.6)
    yc = yc + 8

    ------------------------------------------------------------------------
    -- 4. DIRECTIVES DE MISSION
    ------------------------------------------------------------------------
    self:drawText("DIRECTIVES PRIORITAIRES :", 22, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Small)
    yc = yc + 16

    if isHQClaimed then
        self:drawText("1. RALLIEMENT QG :", 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        self:drawText("Rejoignez les coordonnees de la tete de pont indiquees sur votre carte du monde.", 180, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
        yc = yc + 15

        self:drawText("2. LIAISON RESEAU :", 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        self:drawText("Utilisez le terminal radio installe pour recevoir et executer les directives du Central.", 180, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
        yc = yc + 15

        self:drawText("3. LOGISTIQUE QG :", 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        self:drawText("Aidez au stockage des 20 conserves, 4 reserves d'eau, du vehicule et du generateur.", 180, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
        yc = yc + 15

        self:drawText("4. RECHERCHE VACCIN :", 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        self:drawText("Participez aux prelevements biologiques et a la synthese pour debrayer la frappe.", 180, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
    else
        self:drawText("1. TETE DE PONT (QG) :", 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        self:drawText("Trouvez un batiment sur et faites Clic Droit -> Etablir le QG (Operateur IRIS).", 180, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
        yc = yc + 15

        self:drawText("2. TERMINAL RADIO :", 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        self:drawText("Posez le poste lourd HamRadio2 sur une TABLE dans le QG, puis contactez le Central.", 180, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
        yc = yc + 15

        self:drawText("3. PREPARATION QG :", 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        self:drawText("Rassemblez 20 conserves, 4 reserves d'eau, securisez un vehicule et un generateur.", 180, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
        yc = yc + 15

        self:drawText("4. RECHERCHE VACCIN :", 22, yc, self.cWarn.r, self.cWarn.g, self.cWarn.b, 1.0, UIFont.Small)
        self:drawText("Accomplissez les 12 taches virologiques successives et debrayez le protocole Damocles.", 180, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.9, UIFont.Small)
    end

    yc = yc + 20
    self:drawRect(20, yc, w - 40, 1, 0.4, 0.0, 0.4, 0.6)
    yc = yc + 8

    ------------------------------------------------------------------------
    -- 5. CRITERES TACTIQUES D'IMPLANTATION DU QG (LEVEL DESIGN CONSEILS)
    ------------------------------------------------------------------------
    local critTitle = getTextOrNull("UI_Damocles_Intro_HQCriteria_Title") or "CRITERES TACTIQUES D'IMPLANTATION DU QG :"
    self:drawText(critTitle, 22, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Small)
    yc = yc + 15
    local crit1 = getTextOrNull("UI_Damocles_Intro_HQCriteria_1") or "- Mobilier : Tables ou bureaux requis pour le terminal radio et l'ordinateur."
    self:drawText(crit1, 26, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)
    yc = yc + 13
    local crit2 = getTextOrNull("UI_Damocles_Intro_HQCriteria_2") or "- Ravitaillement : Espace cuisine equipe pour le stockage durable des conserves."
    self:drawText(crit2, 26, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)
    yc = yc + 13
    local crit3 = getTextOrNull("UI_Damocles_Intro_HQCriteria_3") or "- Positionnement : Acces rapide aux infrastructures medicales, sanitaires et commerces."
    self:drawText(crit3, 26, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)
    yc = yc + 13
    local crit4 = getTextOrNull("UI_Damocles_Intro_HQCriteria_4") or "- Logistique : Garage ou abri ferme recommande pour securiser le vehicule et le generateur."
    self:drawText(crit4, 26, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.88, UIFont.Small)

    yc = yc + 18
    self:drawRect(20, yc, w - 40, 1, 0.4, 0.0, 0.4, 0.6)
    yc = yc + 8

    ------------------------------------------------------------------------
    -- 6. RACCOURCIS & INTERFACE
    ------------------------------------------------------------------------
    self:drawText("COMMANDES :", 22, yc, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Small)
    self:drawText("Touche [K] : console tactique  |  Bouton flottant HUD draggable  |  Bouton [ARCHIVES] pour l'historique", 110, yc, self.cSub.r, self.cSub.g, self.cSub.b, 0.85, UIFont.Small)

    ------------------------------------------------------------------------
    -- 7. BOUTON DE DEPLOIEMENT
    ------------------------------------------------------------------------
    local btnW = 300
    local btnH = 34
    local btnX = math.floor((w - btnW) / 2)
    local btnY = h - 46

    local mx = self:getMouseX()
    local my = self:getMouseY()
    local isHoverBtn = mx >= btnX and mx <= (btnX + btnW) and my >= btnY and my <= (btnY + btnH)

    self:drawRect(btnX, btnY, btnW, btnH, isHoverBtn and 0.85 or 0.60, 0.05, 0.25, 0.30)
    local btnText = isHQClaimed and "REJOINDRE L'UNITE ALPHA SUR LE TERRAIN" or "ACCEPTER LA MISSION & DEPLOYER L'UNITE"
    self:drawTextCentre(btnText, btnX + btnW / 2, btnY + 8, self.cCyan.r, self.cCyan.g, self.cCyan.b, 1.0, UIFont.Small)
end

function DamoclesIntroWindow:onMouseDown(x, y)
    local w = self:getWidth()
    local h = self:getHeight()
    local btnW = 300
    local btnH = 34
    local btnX = math.floor((w - btnW) / 2)
    local btnY = h - 46

    -- Clic sur le bouton de d ploiement
    if x >= btnX and x <= (btnX + btnW) and y >= btnY and y <= (btnY + btnH) then
        self:close()
        -- Son de confirmation
        if getSoundManager() then
            getSoundManager():playUISound("UIActivate")
        end
        return true
    end

    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function DamoclesIntroWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

--- Affiche la fen tre d'introduction si le joueur ne l'a pas encore vue dans cette session
function DamoclesIntroWindow.showIntroIfNeeded()
    if DamoclesIntroWindow.instance then return end

    local win = DamoclesIntroWindow:new()
    win:initialise()
    win:addToUIManager()
    win:setVisible(true)
end
