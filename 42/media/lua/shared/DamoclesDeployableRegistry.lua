--[[
    PROJET DAMOCLES - DamoclesDeployableRegistry.lua
    Registre centralise et unifie des equipements deployables au QG (DRY).
    
    Permet de declarer facilement tout equipement present ou futur (terminal radio,
    poste informatique, generateur, centrifugeuse, etablis de laboratoire, etc.)
    avec des regles communes :
      - Detection par type d'item ou sprite
      - Conditions de pose (QG etabli, case dans le QG, surface/table requise)
      - Verrouillage anti-vol / anti-demontage apres installation
      - Validation de mission correspondante a la pose reelle
--]]

DamoclesDeployableRegistry = DamoclesDeployableRegistry or {}
DamoclesDeployableRegistry.items = {}

--- Enregistre une definition d'equipement deployable
function DamoclesDeployableRegistry.register(def)
    if not def or not def.id then return end
    DamoclesDeployableRegistry.items[def.id] = def
end

--- Identifie si un item d'inventaire correspond a un equipement enregistre
function DamoclesDeployableRegistry.matchItem(item)
    if not item then return nil end
    local ft = (item.getFullType and item:getFullType()) or (type(item) == "string" and item) or ""
    local name = (item.getName and item:getName()) or ""
    local modData = (item.getModData and item:getModData()) or nil

    for _, def in pairs(DamoclesDeployableRegistry.items) do
        -- 1. Marqueur modData explicite
        if modData and def.modDataTag and modData[def.modDataTag] then
            return def
        end

        -- 2. Types complets exacts
        if def.fullTypes and def.fullTypes[ft] then
            return def
        end

        -- 3. Mots-cles dans le fullType
        if def.fullTypeKeywords then
            for _, kw in ipairs(def.fullTypeKeywords) do
                if ft:find(kw) then return def end
            end
        end

        -- 4. Mots-cles dans le nom d'affichage
        if def.nameKeywords then
            for _, kw in ipairs(def.nameKeywords) do
                if name:find(kw) then return def end
            end
        end
    end
    return nil
end

--- Identifie si un nom de sprite correspond a un equipement enregistre
function DamoclesDeployableRegistry.matchSprite(spriteName)
    if not spriteName or type(spriteName) ~= "string" or spriteName == "" then return nil end

    for _, def in pairs(DamoclesDeployableRegistry.items) do
        if def.spritePatterns then
            for _, pattern in ipairs(def.spritePatterns) do
                if spriteName:find(pattern) then
                    return def
                end
            end
        end
    end
    return nil
end

--- Identifie un equipement par son item ou son sprite
function DamoclesDeployableRegistry.match(item, spriteName)
    local def = DamoclesDeployableRegistry.matchItem(item)
    if def then return def end
    return DamoclesDeployableRegistry.matchSprite(spriteName)
end

--- Verifie si une case remplit les conditions de surface (table, bureau, comptoir)
local function isTableOrSurface(square)
    if not square then return false end
    if square.Is and (square:Is("IsTable") or square:Is("Surface") or square:Is("IsTableTop")) then
        return true
    end
    if DamoclesMissionManager and DamoclesMissionManager.isTableSquare and DamoclesMissionManager.isTableSquare(square) then
        return true
    end
    if ISMoveableSpriteProps and ISMoveableSpriteProps.getTopTable and ISMoveableSpriteProps:getTopTable(square) then
        return true
    end
    return false
end

DamoclesDeployableRegistry.isTableOrSurface = isTableOrSurface

--- Verifie si la pose de l'equipement est autorisee sur la case cible
--- @return boolean canPlace, string|nil reason
function DamoclesDeployableRegistry.canPlace(def, square, character)
    if not def then return true end

    -- A. Condition : Le QG doit etre prealablement etabli
    if def.requiresHQClaim ~= false then
        if not DamoclesMissionManager or not DamoclesMissionManager.isMissionCompleted("hq_claim") then
            return false, string.format("[IRIS] Impossible d'installer %s : Etablissez d'abord le QG !", string.lower(def.label or "l'equipement"))
        end
    end

    -- B. Condition : Doit se trouver obligatoirement dans le batiment du QG
    if def.requiresInHQ ~= false then
        if not square or not DamoclesMissionManager or not DamoclesMissionManager.isSquareInHQ(square) then
            return false, string.format("[IRIS] %s doit obligatoirement etre installe a l'interieur du batiment du QG !", def.label or "Cet equipement")
        end
    end

    -- C. Condition : Doit etre pose sur une table, meuble ou comptoir
    if def.requiresSurface ~= false then
        if not isTableOrSurface(square) then
            return false, string.format("[IRIS] %s doit obligatoirement etre pose sur une table ou un bureau dans le QG !", def.label or "Cet equipement")
        end
    end

    return true, nil
end

--- Verifie si un objet pose dans le monde est verrouille contre le deplacement / demontage
--- @return boolean isLocked, string|nil reason
function DamoclesDeployableRegistry.isLocked(object, square, mode)
    if not object and not square then return false end

    -- Exclusion des televiseurs
    if object then
        if instanceof(object, "IsoTelevision") then return false end
        if object.getDeviceData and object:getDeviceData() and object:getDeviceData().getIsTelevision and object:getDeviceData():getIsTelevision() then
            return false
        end
    end

    local termLoc = DamoclesMissionManager and DamoclesMissionManager.getTerminalLocation()

    for _, def in pairs(DamoclesDeployableRegistry.items) do
        local isMatch = false
        if object then
            if def.modDataTag and object.getModData and object:getModData()[def.modDataTag] then
                isMatch = true
            elseif object.getItem and object:getItem() and DamoclesDeployableRegistry.matchItem(object:getItem()) == def then
                isMatch = true
            elseif object.getSprite and object:getSprite() and DamoclesDeployableRegistry.matchSprite(object:getSprite():getName()) == def then
                isMatch = true
            end
        end

        -- Cas specifique des coordonnees ancrees du terminal
        if def.id == "terminal" and termLoc and square then
            if square:getX() == termLoc.x and square:getY() == termLoc.y then
                isMatch = true
            end
        end

        if isMatch and def.lockOnMission then
            if DamoclesMissionManager and DamoclesMissionManager.isMissionCompleted(def.lockOnMission) then
                return true, string.format("[IRIS] %s est synchronise au reseau du QG et ne peut pas etre deplace !", def.label or "Cet equipement")
            end
        end
    end

    return false
end

--- Execute la sequence de validation post-pose (tag modData, enregistrement coords, mission completee)
function DamoclesDeployableRegistry.onPerformPlace(def, square, character, placedObject)
    if not def or not square then return end

    local tx, ty, tz = square:getX(), square:getY(), square:getZ()

    -- 1. Marquage modData de l'objet et des objets de la case
    if def.modDataTag then
        if placedObject and placedObject.getModData then
            placedObject:getModData()[def.modDataTag] = true
        end
        local objs = square:getObjects()
        if objs then
            for i = 0, objs:size() - 1 do
                local o = objs:get(i)
                if o and not instanceof(o, "IsoTelevision") and o.getModData then
                    if def.matchWorldObject then
                        if def.matchWorldObject(o) then o:getModData()[def.modDataTag] = true end
                    else
                        o:getModData()[def.modDataTag] = true
                    end
                end
            end
        end
        local wobjs = square:getWorldObjects()
        if wobjs then
            for i = 0, wobjs:size() - 1 do
                local wo = wobjs:get(i)
                if wo and wo.getModData then
                    wo:getModData()[def.modDataTag] = true
                end
            end
        end
    end

    -- 2. Callback personnalise (ex: coordonnees de la radio)
    if def.onPlaced then
        def.onPlaced(square, character, placedObject)
    end

    -- 3. Validation de la mission
    if def.completeMission and DamoclesMissionManager and DamoclesMissionDB then
        local m = DamoclesMissionDB.getById(def.completeMission)
        if m and m.status == "ACTIVE" then
            DamoclesMissionManager.onComplete(def.completeMission)
            if character and character.Say and def.onCompleteSay then
                character:Say(def.onCompleteSay)
            end
        end
    end
end

------------------------------------------------------------------------
-- ENREGISTREMENT DES EQUIPEMENTS DU QG
------------------------------------------------------------------------

-- 1. Terminal Radio d'Etat-Major IRIS (ALPHA-01)
DamoclesDeployableRegistry.register({
    id              = "terminal",
    label           = "Le terminal d'etat-major",
    fullTypes       = { ["Radio.HamRadio2"] = true },
    fullTypeKeywords= { "HamRadio2" },
    nameKeywords    = { "ALPHA%-01", "Terminal d'Etat%-Major" },
    spritePatterns  = {
        "appliances_com_01_8", "appliances_com_01_9", "appliances_com_01_10",
        "appliances_com_01_11", "appliances_com_01_12", "appliances_com_01_13",
        "appliances_com_01_14", "appliances_com_01_15",
    },
    modDataTag      = "isDamoclesTerminal",
    requiresHQClaim = true,
    requiresInHQ    = true,
    requiresSurface = true,
    completeMission = "hq_radio",
    lockOnMission   = "hq_radio",
    onCompleteSay   = "[IRIS] Terminal ALPHA-01 installe sur table et connecte au Central.",
    onPlaced        = function(square, character, placedObject)
        if DamoclesMissionManager then
            DamoclesMissionManager.setTerminalLocation(square:getX(), square:getY(), square:getZ())
        end
    end,
})

-- 2. Poste Informatique / Serveur IRIS
DamoclesDeployableRegistry.register({
    id              = "computer",
    label           = "Le poste informatique",
    fullTypes       = { ["Base.Mov_DesktopComputer"] = true },
    fullTypeKeywords= { "DesktopComputer", "Computer" },
    nameKeywords    = { "DesktopComputer", "Computer", "Ordinateur" },
    spritePatterns  = { "appliances_com_01_7" },
    modDataTag      = "isDamoclesComputer",
    requiresHQClaim = true,
    requiresInHQ    = true,
    requiresSurface = true,
    completeMission = "prep_computer",
    lockOnMission   = "prep_computer",
    onCompleteSay   = "[IRIS] Poste informatique configure et synchronise au reseau.",
    matchWorldObject= function(obj)
        local s = (obj.getSprite and obj:getSprite() and obj:getSprite():getName()) or ""
        return s:find("appliances_com_01_7") or (obj.getFullType and obj:getFullType():find("Computer"))
    end,
})
