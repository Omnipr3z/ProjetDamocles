--[[
    PROJET DAMOCL S - Point d'entr e Client
    Initialise le bouton HUD flottant et la fen tre principale au d marrage de l'UI.
    G re la r ception des mises   jour de state envoy es par le serveur.
]]

require "UI/DamoclesMainWindow"
require "UI/DamoclesHQWindow"
require "UI/DamoclesHistoryWindow"
require "UI/DamoclesIntroWindow"
require "UI/DamoclesHUDButton"
require "DamoclesContextMenu"
require "DamoclesMockData"
require "DamoclesGameTime"
require "DamoclesDeployableRegistry"
require "DamoclesMapManager"

-- Table d' tat c t  client, hydrat e par les commandes serveur
-- C'est ce que DamoclesMainWindow:_buildDisplayData() lit en priorit 
DamoclesClientState = {
    initialized        = false,
    globalResearch     = 0,
    -- Deadline re ue du serveur, en heures de jeu
    -- Le countdown est calcul  localement   chaque frame   partir de cette valeur.
    deadlineWorldHours = nil,
    operatorRole       = "AGENT IRIS",
    hqStatus           = { label = "EN ATTENTE D'ETABLISSEMENT", level = "normal" },
    hqLocation         = nil,
    hqBuilding         = nil,
    threatLevel        = 0,
    terminalLocation   = nil,
    terminalLocked     = false,
    missions           = {},
    completedMissionMap = {},
}

DamoclesClient = DamoclesClient or {}
DamoclesClient.hudButton = nil

--- D clenche un retour multisensoriel complet lors de l'accomplissement d'une mission :
--- - Son gratifiant (effet sonore LevelUp officiel PZ)
--- - Halo Text flottant au-dessus de la t te du personnage
--- - Clignotement du bouton HUD IRIS
--- @param missionTitle string
--- @param researchGain number|nil
function DamoclesNotifyMissionComplete(missionTitle, researchGain)
    local title = tostring(missionTitle or "OBJECTIF REMPLI")
    local gain = researchGain or 0

    -- 1. Son officiel de r ussite PZ
    if getSoundManager() then
        getSoundManager():playUISound("LevelUp")
    end

    -- 2. Halo Text flottant vert au-dessus du joueur
    local player = getPlayer() or getSpecificPlayer(0)
    if player then
        local msg = "MISSION ACCOMPLIE : " .. title
        if gain > 0 then
            msg = msg .. string.format(" (+%d%%)", gain)
        end

        if HaloTextHelper and HaloTextHelper.addTextWithArrow then
            HaloTextHelper.addTextWithArrow(player, msg, true, 50, 255, 120)
        elseif player.setHaloNote then
            player:setHaloNote(msg, 50, 255, 120, 300)
        elseif player.Say then
            player:Say(msg)
        end
    end

    -- 3. Clignotement / pastille de notification sur le bouton HUD flottant
    if DamoclesClient.hudButton and DamoclesClient.hudButton.triggerNotification then
        DamoclesClient.hudButton:triggerNotification()
    end

    -- 4. Rafra chissement de l'interface principale si ouverte
    if DamoclesMainWindow.instance and DamoclesMainWindow.instance:isVisible() then
        DamoclesMainWindow.instance:refreshDisplay()
    end
end

local function onInitUI()
    if DamoclesMainWindow.instance then return end

    -- 1. Instanciation de la fen tre principale
    local mainWindow = DamoclesMainWindow:new()
    mainWindow:initialise()
    mainWindow:setVisible(false) -- Ferm e par d faut

    -- 2. Position par d faut du bouton flottant (ancr    droite sous la mini-carte)
    local screenW = getCore():getScreenWidth()
    local initialBtnX = math.max(10, screenW - 65)
    local initialBtnY = 220

    -- 3. Instanciation du bouton flottant draggable
    DamoclesClient.hudButton = DamoclesHUDButton:new(initialBtnX, initialBtnY, 48, 48, function()
        if DamoclesMainWindow.instance then
            DamoclesMainWindow.instance:toggle()
        end
    end)

    DamoclesClient.hudButton:initialise()
    DamoclesClient.hudButton:addToUIManager()
    DamoclesClient.hudButton:setVisible(true)

    -- 4. Affichage du briefing d'introduction au d ploiement
    DamoclesIntroWindow.showIntroIfNeeded()

    print("[PROJET DAMOCLES] Interface IRIS initialisee avec succes.")
end

-- Raccourci clavier de secours (Touche K) pour ouvrir/fermer le terminal
local function onKeyPressed(key)
    if key == Keyboard.KEY_K then
        if DamoclesMainWindow.instance then
            DamoclesMainWindow.instance:toggle()
        end
    end
end

-- R ception des commandes serveur   mise   jour du DamoclesClientState
local function onServerCommand(module, command, args)
    if module ~= "DamoclesServer" then return end

    if command == "StateUpdate" then
        DamoclesClientState.initialized        = true
        DamoclesClientState.globalResearch     = args.globalResearch     or DamoclesClientState.globalResearch
        DamoclesClientState.deadlineWorldHours = args.deadlineWorldHours or DamoclesClientState.deadlineWorldHours
        DamoclesClientState.hqStatus           = args.hqStatus           or DamoclesClientState.hqStatus
        DamoclesClientState.hqLocation         = args.hqLocation         or DamoclesClientState.hqLocation
        DamoclesClientState.hqBuilding         = args.hqBuilding         or DamoclesClientState.hqBuilding
        DamoclesClientState.threatLevel        = args.threatLevel        or DamoclesClientState.threatLevel
        DamoclesClientState.terminalLocation   = args.terminalLocation   or DamoclesClientState.terminalLocation
        DamoclesClientState.terminalLocked     = (args.terminalLocked ~= nil) and args.terminalLocked or DamoclesClientState.terminalLocked
        DamoclesClientState.missions           = args.missions           or DamoclesClientState.missions

        if DamoclesMainWindow.instance and DamoclesMainWindow.instance:isVisible() then
            DamoclesMainWindow.instance:refreshDisplay()
        end

        print("[DamoclesClient] Etat recu. Recherche : "
            .. tostring(DamoclesClientState.globalResearch) .. "%%")

    elseif command == "MissionCompletedNotify" then
        if DamoclesNotifyMissionComplete then
            DamoclesNotifyMissionComplete(args.title, args.researchGain)
        end

    elseif command == "DamoclesMissionComplete" then
        DamoclesClientState.deadlineWorldHours = nil
        DamoclesClientState.hqStatus = { label = "OPERATION DAMOCLES ANNULEE", level = "normal" }
        if DamoclesMainWindow.instance then
            DamoclesMainWindow.instance:refreshDisplay()
        end
        if DamoclesNotifyMissionComplete then
            DamoclesNotifyMissionComplete("OPERATION DAMOCLES NEUTRALISEE", 100)
        end
    end
end

Events.OnCreateUI.Add(onInitUI)
Events.OnKeyPressed.Add(onKeyPressed)
Events.OnServerCommand.Add(onServerCommand)
