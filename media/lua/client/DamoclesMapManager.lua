--[[
    PROJET DAMOCLES - DamoclesMapManager.lua
    Gestionnaire centralise des marqueurs tactiques sur la carte du monde (ISWorldMap).
    
    Fonctionnalites :
      - Placement dynamique de marqueurs et balises (symboles + texte)
      - Marquage automatique du QG des sa revendication
      - Support d'objectifs de mission futurs
      - Synchronisation automatique avec l'API des symboles de carte vanilla
--]]

DamoclesMapManager = DamoclesMapManager or {}
DamoclesMapManager.markers = {}
DamoclesMapManager.injectedSymbols = {}

-- Enregistrement du symbole personnalise Damocles dans l'API des symboles de carte du jeu
if MapSymbolDefinitions and MapSymbolDefinitions.getInstance then
    pcall(function()
        MapSymbolDefinitions.getInstance():addTexture("Damocles_HQ", "media/textures/Damocles/logo_iris.png")
    end)
end

--- Ajoute ou met a jour un marqueur tactique
--- @param id string Identifiant unique du marqueur (ex: "hq", "obj_vehicle")
--- @param x number Coordonnee X du monde
--- @param y number Coordonnee Y du monde
--- @param text string Libelle textuel associe
--- @param symbol string Nom du symbole (ex: "Damocles_HQ", "House", "Target", "Star")
--- @param r number Rouge [0-1]
--- @param g number Vert [0-1]
--- @param b number Bleu [0-1]
function DamoclesMapManager.addMarker(id, x, y, text, symbol, r, g, b)
    if not id or not x or not y then return end

    DamoclesMapManager.markers[id] = {
        id     = id,
        x      = math.floor(x),
        y      = math.floor(y),
        text   = text or "",
        symbol = symbol or "Target",
        r      = r or 0.2,
        g      = g or 0.85,
        b      = b or 1.0,
        a      = 1.0,
    }

    print(string.format("[DamoclesMapManager] Marqueur ajoute/mis a jour : '%s' en (%d, %d)", id, x, y))

    -- Si une carte est actuellement ouverte, mise a jour immediate
    if ISWorldMap_instance and ISWorldMap_instance.symbolsAPI then
        DamoclesMapManager.applyMarkersToAPI(ISWorldMap_instance.symbolsAPI)
    end
end

--- Supprime un marqueur tactique
function DamoclesMapManager.removeMarker(id)
    if not id then return end
    DamoclesMapManager.markers[id] = nil
end

--- Met a jour le marqueur du QG lors de son etablissement
function DamoclesMapManager.updateHQMarker(x, y)
    if not x or not y then return end
    local label = "[IRIS] POINT D'INSERTION // QG ALPHA"
    DamoclesMapManager.addMarker("hq", x, y, label, "Damocles_HQ", 0.0, 0.90, 1.0)
end

--- Met a jour la balise du terminal radio tant qu'il n'est pas installe au QG
function DamoclesMapManager.updateTerminalCarrierMarker(x, y, carrierName)
    if not x or not y then return end
    if DamoclesMissionManager and (DamoclesMissionManager.isMissionCompleted("hq_radio") or DamoclesMissionManager.getTerminalLocation()) then
        DamoclesMapManager.removeMarker("terminal_carrier")
        return
    end

    local label = string.format("[IRIS] TERMINAL ALPHA // EN TRANSIT (%s)", carrierName or "OPERATEUR")
    DamoclesMapManager.addMarker("terminal_carrier", x, y, label, "Target", 1.0, 0.75, 0.1)
end

--- Injecte l'ensemble des marqueurs enregistres dans le moteur de symboles de la carte
function DamoclesMapManager.applyMarkersToAPI(symbolsAPI)
    if not symbolsAPI then return end

    for id, m in pairs(DamoclesMapManager.markers) do
        local key = string.format("%s_%d_%d", id, m.x, m.y)
        if not DamoclesMapManager.injectedSymbols[key] then
            pcall(function()
                -- 1. Ajout de l'icone
                if m.symbol and symbolsAPI.addTexture then
                    local sym = nil
                    local ok, res = pcall(function() return symbolsAPI:addTexture(m.symbol, m.x, m.y) end)
                    if ok and res then
                        sym = res
                    else
                        pcall(function() sym = symbolsAPI:addTexture("House", m.x, m.y) end)
                    end
                    if sym then
                        sym:setRGBA(m.r, m.g, m.b, m.a or 1.0)
                        sym:setAnchor(0.5, 0.5)
                        sym:setScale(1.2)
                    end
                end

                -- 2. Ajout du texte tactique
                if m.text and m.text ~= "" and symbolsAPI.addUntranslatedText then
                    local txt = symbolsAPI:addUntranslatedText(m.text, UIFont.Small, m.x + 12, m.y - 8)
                    if txt then
                        txt:setRGBA(m.r, m.g, m.b, m.a or 1.0)
                        txt:setAnchor(0.0, 0.5)
                        txt:setScale(1.0)
                    end
                end

                DamoclesMapManager.injectedSymbols[key] = true
            end)
        end
    end
end

------------------------------------------------------------------------
-- HOOKS CARTES DU MONDE (ISWorldMap & ISMap)
------------------------------------------------------------------------

local function checkAndInjectMapMarkers(mapUI)
    if not mapUI then return end

    -- Mettre a jour la balise du porteur de terminal si la radio n'est pas encore posee
    if DamoclesMissionManager then
        if DamoclesMissionManager.isMissionCompleted("hq_radio") or DamoclesMissionManager.getTerminalLocation() then
            DamoclesMapManager.removeMarker("terminal_carrier")
        else
            local p = getPlayer()
            if p then
                local hasTerm = false
                local inv = p:getInventory()
                if inv then
                    local function checkBag(c)
                        if not c then return false end
                        local items = c:getItems()
                        if items then
                            for i = 0, items:size() - 1 do
                                local it = items:get(i)
                                if it and ((it.getModData and it:getModData().isDamoclesTerminal) or (it.getType and it:getType() == "HamRadio2")) then
                                    return true
                                end
                                if it and it.getItemContainer and it:getItemContainer() then
                                    if checkBag(it:getItemContainer()) then return true end
                                end
                            end
                        end
                        return false
                    end
                    hasTerm = checkBag(inv)
                end
                if hasTerm then
                    DamoclesMapManager.updateTerminalCarrierMarker(p:getX(), p:getY(), p:getUsername())
                end
            end
        end
    end

    local symbolsAPI = mapUI.symbolsAPI or (mapUI.mapAPI and mapUI.mapAPI.getSymbolsAPI and mapUI.mapAPI:getSymbolsAPI())
    if symbolsAPI then
        DamoclesMapManager.applyMarkersToAPI(symbolsAPI)
    end
end

Events.OnGameStart.Add(function()
    -- Hook sur la carte globale
    if ISWorldMap then
        local old_initUI = ISWorldMap.initUI
        if old_initUI then
            ISWorldMap.initUI = function(self)
                old_initUI(self)
                checkAndInjectMapMarkers(self)
            end
        end

        local old_prerender = ISWorldMap.prerender
        if old_prerender then
            ISWorldMap.prerender = function(self)
                old_prerender(self)
                checkAndInjectMapMarkers(self)
            end
        end
    end

    -- Initialisation du QG si deja connu au demarrage
    if DamoclesMissionManager then
        local hq = DamoclesMissionManager.getHQLocation()
        if hq and hq.x and hq.y then
            DamoclesMapManager.updateHQMarker(hq.x, hq.y)
        end
    end
end)

-- Re-verification lors de l'evenement d'etablissement du QG
local function onDamoclesHQClaimed(eventData)
    if DamoclesMissionManager then
        local hq = DamoclesMissionManager.getHQLocation()
        if hq and hq.x and hq.y then
            DamoclesMapManager.updateHQMarker(hq.x, hq.y)
        end
    end
end

Events.OnCustomUIKey.Add(function(key)
    -- Maintien de l'actualisation si le joueur ouvre la carte
end)
