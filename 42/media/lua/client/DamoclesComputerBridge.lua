--[[
    PROJET DAMOCLES - DamoclesComputerBridge.lua
    Passerelle d'integration entre le Projet Damocles et ComputerMod (ou terminaux informatiques).
    
    Fonctionnalites :
    1. Integration ComputerMod :
       - Injection de l'application de bureau "[IRIS] SERVEUR IRIS" sur l'ecran de l'ordinateur.
       - Activation au double-clic ou selection pour ouvrir l'interface Damocles / Reseau IRIS.
    2. Menu contextuel universel :
       - Permet d'acceder au serveur IRIS directement en faisant un clic droit sur un ordinateur installe dans le QG.
--]]

require "ISUI/ISPanel"

local function initComputerModIntegration()
    if not ComputerScreenUI then
        print("[DamoclesComputerBridge] ComputerScreenUI non detecte (ComputerMod non actif ou absent). Mode autonome actif.")
        return
    end

    print("[DamoclesComputerBridge] ComputerScreenUI detecte ! Injection de la passerelle IRIS...")

    -- 1. Injection de l'icone applicative sur le Bureau virtuel PZ OS
    if ComputerScreenUI.getDesktopAppItems then
        local old_getDesktopAppItems = ComputerScreenUI.getDesktopAppItems
        ComputerScreenUI.getDesktopAppItems = function(self)
            local items = old_getDesktopAppItems(self) or {}
            local iconTex = getTexture("media/textures/Damocles/logo_iris.png") or getTexture("media/textures/Damocles/icon_gear.png")
            items[#items + 1] = {
                key     = "app_damocles_iris",
                kind    = "app",
                app     = "damocles_iris",
                label   = "[IRIS] SERVEUR IRIS",
                texture = iconTex,
            }
            return items
        end
    end

    -- 2. Gestion de l'ouverture lors du double-clic sur l'application
    if ComputerScreenUI.activateDesktopItem then
        local old_activateDesktopItem = ComputerScreenUI.activateDesktopItem
        ComputerScreenUI.activateDesktopItem = function(self, item)
            if item and item.app == "damocles_iris" then
                if DamoclesMainWindow then
                    if DamoclesMainWindow.openUI then
                        DamoclesMainWindow.openUI()
                    elseif DamoclesMainWindow.toggleUI then
                        DamoclesMainWindow.toggleUI()
                    end
                end
                return
            end
            return old_activateDesktopItem(self, item)
        end
    end

    print("[DamoclesComputerBridge] Application '[IRIS] SERVEUR IRIS' injectee avec succes dans ComputerMod.")
end

Events.OnGameStart.Add(initComputerModIntegration)

------------------------------------------------------------------------
-- Interaction universelle par clic-droit sur l'ordinateur du QG
------------------------------------------------------------------------

local function onFillComputerWorldContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local computerObj = nil
    for _, obj in ipairs(worldobjects) do
        if obj then
            local sq = obj:getSquare()
            if sq and DamoclesMissionManager.isSquareInHQ(sq) and DamoclesMissionManager.isTableSquare(sq) then
                if obj.getModData and obj:getModData().isDamoclesComputer then
                    computerObj = obj
                    break
                end
                local sName = obj.getSprite and obj:getSprite() and obj:getSprite():getName() or ""
                if sName:find("appliances_com_01_7") or sName:find("appliances_com_01_8") then
                    computerObj = obj
                    break
                end
                local ft = obj.getFullType and obj:getFullType() or ""
                if ft:find("DesktopComputer") or ft:find("Computer") then
                    computerObj = obj
                    break
                end
            end
        end
    end

    if computerObj then
        local isPrepDone = DamoclesMissionManager.isMissionCompleted("prep_computer")
        local icon = getTexture("media/textures/Damocles/logo_iris.png")

        if isPrepDone then
            local opt = context:addOption(
                "[IRIS] Acceder au Serveur de Donnees IRIS",
                worldobjects,
                function()
                    if DamoclesMainWindow then
                        if DamoclesMainWindow.openUI then
                            DamoclesMainWindow.openUI()
                        elseif DamoclesMainWindow.toggleUI then
                            DamoclesMainWindow.toggleUI()
                        end
                    end
                end
            )
            if icon then opt.iconTexture = icon end
        else
            local opt = context:addOption(
                "[IRIS] Poste Informatique (En attente de configuration)",
                worldobjects,
                nil
            )
            opt.notAvailable = true
            if icon then opt.iconTexture = icon end
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = "Ce poste doit etre configure et declare aupres du Central via le terminal radio."
            opt.toolTip = tooltip
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillComputerWorldContextMenu)
