--[[
    PROJET DAMOCLES - DamoclesMissionManager.lua
    Gestionnaire central des missions. Logique pure, sans UI ni hooks directs.

    Responsabilites :
        - Initialiser et hydrater les missions depuis la DB et le ModData serveur
        - Calculer quelles missions sont ACTIVE / LOCKED / COMPLETED
        - Gerer la progression et la completion
        - Gerer le terminal radio IRIS (emplacement, verrouillage sur table, liaison Central)
        - Gerer les conditions de terrain (zone sterile 0 cadavre, barricades, generateur)
        - Spawn dynamique des documents de quete
]]

require "DamoclesMissionDB"
require "DamoclesGameTime"
require "DamoclesMissionValidator"

DamoclesMissionManager = DamoclesMissionManager or {}

-- =========================================================================
-- Etat interne du Manager (runtime uniquement -- persistance via ModData)
-- =========================================================================

local _state = {
    initialized        = false,
    researchGainTotal  = 0,

    -- Deadline en heures de jeu.
    deadlineWorldHours = nil,
    countdownActive    = true,

    hqStatus = {
        label  = "SITREP : EN ATTENTE D'ETABLISSEMENT",
        level  = "normal",
    },

    hqLocation        = nil,
    hqBuilding        = nil,
    hqThreatLevel     = 0,

    -- Terminal radio d'etat-major (HamRadio2)
    terminalLocation  = nil,
    terminalLocked    = false,

    -- Suivi des quetes generees dynamiquement
    spawnedQuests     = {},
}

-- =========================================================================
-- Initialisation
-- =========================================================================

--- Charge l'etat persiste depuis le ModData serveur (ou repart de zero).
function DamoclesMissionManager.init()
    if _state.initialized then return end

    local saved = DamoclesMissionManager._loadFromModData()

    if saved then
        for id, savedMission in pairs(saved.missions or {}) do
            local m = DamoclesMissionDB.getById(id)
            if m then
                m.status       = savedMission.status       or m.status
                m.currentCount = savedMission.currentCount or m.currentCount
            end
        end

        _state.researchGainTotal  = saved.researchGainTotal  or 0
        _state.deadlineWorldHours = saved.deadlineWorldHours or nil
        _state.countdownActive    = (saved.countdownActive ~= nil) and saved.countdownActive or true
        _state.hqLocation         = saved.hqLocation         or nil
        _state.hqBuilding         = saved.hqBuilding         or nil
        _state.hqStatus           = saved.hqStatus           or _state.hqStatus
        _state.terminalLocation   = saved.terminalLocation   or nil
        _state.terminalLocked     = saved.terminalLocked     or false
        _state.spawnedQuests      = saved.spawnedQuests      or {}
    end

    if not _state.deadlineWorldHours then
        _state.deadlineWorldHours = DamoclesGameTime.computeDeadline(
            DamoclesGameTime.DEFAULT_COUNTDOWN_HOURS
        )
        print(string.format(
            "[DamoclesMissionManager] Nouvelle deadline Damocles : %.2f h (dans %d h de jeu)",
            _state.deadlineWorldHours,
            DamoclesGameTime.DEFAULT_COUNTDOWN_HOURS
        ))
    end

    _state.initialized = true
    DamoclesMissionManager._checkUnlocks()
    print("[DamoclesMissionManager] Initialise. Recherche globale : "
        .. DamoclesMissionManager.getGlobalResearch() .. "%")
end

-- =========================================================================
-- Accesseurs
-- =========================================================================

function DamoclesMissionManager.getActiveMissions()
    local active = {}
    for _, m in ipairs(DamoclesMissionDB.getAll()) do
        if m.status == "ACTIVE" then
            table.insert(active, m)
        end
    end
    return active
end

function DamoclesMissionManager.getGlobalResearch()
    return math.min(100, math.max(0, _state.researchGainTotal))
end

function DamoclesMissionManager.getHQStatus()
    return _state.hqStatus
end

function DamoclesMissionManager.getCountdown()
    return DamoclesGameTime.getRemainingGameSeconds(_state.deadlineWorldHours)
end

function DamoclesMissionManager.getDeadlineWorldHours()
    return _state.deadlineWorldHours
end

function DamoclesMissionManager.getHQLocation()
    if _state.hqLocation then return _state.hqLocation end
    if DamoclesClientState and DamoclesClientState.hqLocation then
        return DamoclesClientState.hqLocation
    end
    return nil
end

function DamoclesMissionManager.getHQBuilding()
    if _state.hqBuilding then return _state.hqBuilding end
    if DamoclesClientState and DamoclesClientState.hqBuilding then
        return DamoclesClientState.hqBuilding
    end
    return nil
end

--- Verifie si une mission donnee est marquee completee
function DamoclesMissionManager.isMissionCompleted(id)
    if not id then return false end

    -- Cas particulier hq_claim : verifier si le QG a ete enregistre
    if id == "hq_claim" then
        if _state.hqBuilding ~= nil or _state.hqLocation ~= nil then
            return true
        end
        if DamoclesClientState and (DamoclesClientState.hqBuilding ~= nil or DamoclesClientState.hqLocation ~= nil) then
            return true
        end
    end

    -- Si client MP synchronise
    if DamoclesClientState and DamoclesClientState.missions then
        for _, m in ipairs(DamoclesClientState.missions) do
            if m.id == id then
                return m.status == "COMPLETED"
            end
        end
    end

    -- Verification directe dans le catalogue des missions
    if DamoclesMissionDB and DamoclesMissionDB.getById then
        local m = DamoclesMissionDB.getById(id)
        return m ~= nil and m.status == "COMPLETED"
    end
    return false
end

function DamoclesMissionManager.getTerminalLocation()
    return _state.terminalLocation
end

function DamoclesMissionManager.isTerminalLocked()
    return _state.terminalLocked
end

function DamoclesMissionManager.setTerminalLocation(x, y, z)
    _state.terminalLocation = { x = x, y = y, z = z or 0 }
    _state.terminalLocked   = true
    print(string.format("[DamoclesMissionManager] Terminal radio enregistre et verrouille en (%d, %d, %d)", x, y, z or 0))
    DamoclesMissionManager._saveToModData()
end

function DamoclesMissionManager.setHQStatus(label, level)
    _state.hqStatus = { label = label, level = level or "normal" }
end

function DamoclesMissionManager.setHQBuilding(data)
    if not data then return end
    if _state.hqBuilding then
        print("[DamoclesMissionManager] QG deja definitivement etabli, modification strictement interdite !")
        return
    end
    local cx = data.x or data.centerX or math.floor(((data.minX or 0) + (data.maxX or 0)) / 2)
    local cy = data.y or data.centerY or math.floor(((data.minY or 0) + (data.maxY or 0)) / 2)
    local cz = data.z or 0

    _state.hqLocation = { x = cx, y = cy, z = cz }
    _state.hqBuilding = {
        minX     = data.minX or (cx - 15),
        minY     = data.minY or (cy - 15),
        maxX     = data.maxX or (cx + 15),
        maxY     = data.maxY or (cy + 15),
        roomName = data.roomName or "Batiment QG",
    }

    print(string.format("[DamoclesMissionManager] QG IRIS etabli : zone (%d,%d) -> (%d,%d), Centre: (%d,%d,%d) [%s]",
        _state.hqBuilding.minX, _state.hqBuilding.minY,
        _state.hqBuilding.maxX, _state.hqBuilding.maxY,
        cx, cy, cz, _state.hqBuilding.roomName))

    if DamoclesMapManager and DamoclesMapManager.updateHQMarker then
        DamoclesMapManager.updateHQMarker(cx, cy)
    end

    DamoclesMissionManager._saveToModData()
end

function DamoclesMissionManager.getTerminalCarrier()
    return _state.terminalCarrier
end

function DamoclesMissionManager.setTerminalCarrier(username)
    _state.terminalCarrier = username
    DamoclesMissionManager._saveToModData()
end

function DamoclesMissionManager.clearTerminalCarrier(username)
    if not username or _state.terminalCarrier == username then
        _state.terminalCarrier = nil
        DamoclesMissionManager._saveToModData()
    end
end

function DamoclesMissionManager.isInsideHQ(x, y, z)
    if not _state.hqBuilding then
        if not _state.hqLocation then return false end
        local dx = x - _state.hqLocation.x
        local dy = y - _state.hqLocation.y
        return (dx * dx + dy * dy) <= (20 * 20)
    end
    local b = _state.hqBuilding
    return x >= (b.minX - 1) and x <= (b.maxX + 1) and y >= (b.minY - 1) and y <= (b.maxY + 1)
end

--- Verifie si une case du monde (IsoGridSquare) se trouve a l'interieur du batiment du QG
function DamoclesMissionManager.isSquareInHQ(square)
    if not square then return false end
    if not _state.hqBuilding and not _state.hqLocation then return false end

    -- Si la case possede un batiment, verifier la concordance exacte avec le QG
    local b = square:getBuilding()
    if _state.hqBuilding and b then
        local def = b:getDef()
        if def then
            local bMinX = def:getX()
            local bMinY = def:getY()
            local hqB = _state.hqBuilding
            if bMinX == hqB.minX and bMinY == hqB.minY then
                return true
            end
        end
    end

    return DamoclesMissionManager.isInsideHQ(square:getX(), square:getY(), square:getZ())
end

-- =========================================================================
-- Verifications de surface et de terrain
-- =========================================================================

--- Verifie si une case possede une surface elevee (table, bureau, comptoir)
function DamoclesMissionManager.isTableSquare(square)
    if not square then return false end
    local props = square:getProperties()
    if props and (props:Is("IsTable") or props:Is("Surface") or props:Is("IsTableTop")) then
        return true
    end
    if ISMoveableSpriteProps and ISMoveableSpriteProps.getTopTable and ISMoveableSpriteProps:getTopTable(square) then
        return true
    end
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            local oprops = obj and obj:getProperties()
            if oprops and (oprops:Is("IsTable") or oprops:Is("Surface") or oprops:Is("IsTableTop")) then
                return true
            end
            if obj and obj.isTable and obj:isTable() then
                return true
            end
            local cont = obj and obj:getContainer()
            if cont then
                local ct = cont:getType() or ""
                if ct:find("counter") or ct:find("desk") or ct:find("table") then
                    return true
                end
            end
            if obj and obj.getSprite and obj:getSprite() then
                local sName = string.lower(obj:getSprite():getName() or "")
                if sName:find("table") or sName:find("desk") or sName:find("counter") or sName:find("bureau") then
                    return true
                end
            end
        end
    end
    return false
end

--- Scanne le batiment du QG pour localiser le terminal d'etat-major ALPHA-01 installe sur une table
--- NOTE : Ne valide JAMAIS passivement la mission hq_radio. La validation se fait a la pose physique.
--- Exclut categoriquement les televiseurs (IsoTelevision) et les radios civiles de maison.
function DamoclesMissionManager.findRadioTerminalInHQ()
    local hqLoc = _state.hqLocation
    local b = _state.hqBuilding
    if not hqLoc and not b then return nil end

    local cell = getCell()
    if not cell then return nil end

    local minX = b and b.minX or (hqLoc.x - 20)
    local maxX = b and b.maxX or (hqLoc.x + 20)
    local minY = b and b.minY or (hqLoc.y - 20)
    local maxY = b and b.maxY or (hqLoc.y + 20)

    for x = minX, maxX do
        for y = minY, maxY do
            local sq = cell:getGridSquare(x, y, 0)
            if sq and DamoclesMissionManager.isTableSquare(sq) then
                -- 1. Objets du monde poses ou ancres sur la table
                local objs = sq:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj then
                            -- Exclusion formelle des televiseurs
                            local isTV = instanceof(obj, "IsoTelevision")
                            if not isTV and obj.getDeviceData and obj:getDeviceData() and obj:getDeviceData().getIsTelevision then
                                isTV = obj:getDeviceData():getIsTelevision()
                            end

                            if not isTV then
                                local isTerminal = false
                                if obj.getModData and obj:getModData().isDamoclesTerminal then
                                    isTerminal = true
                                elseif _state.terminalLocked and _state.terminalLocation then
                                    if math.floor(obj:getX()) == _state.terminalLocation.x and math.floor(obj:getY()) == _state.terminalLocation.y then
                                        isTerminal = true
                                    end
                                end

                                if isTerminal then
                                    return obj
                                end
                            end
                        end
                    end
                end

                -- 2. Items d'inventaire poses sur la surface de la table (IsoWorldInventoryObject)
                local wobjs = sq:getWorldObjects()
                if wobjs then
                    for i = 0, wobjs:size() - 1 do
                        local wobj = wobjs:get(i)
                        if wobj and wobj.getItem and wobj:getItem() then
                            local it = wobj:getItem()
                            local isTerm = false
                            if it.getModData and it:getModData().isDamoclesTerminal then
                                isTerm = true
                            elseif it.getName and it:getName():find("ALPHA%-01") then
                                isTerm = true
                            end

                            if isTerm then
                                return wobj
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- =========================================================================
-- Delegation de validation des missions (centralisee dans DamoclesMissionValidator)
-- =========================================================================

function DamoclesMissionManager.checkComputerInstalled(player)
    return DamoclesMissionValidator.checkComputerInstalled(player)
end

function DamoclesMissionManager.areCorpsesCleanedInHQ()
    return DamoclesMissionValidator.areCorpsesCleanedInHQ()
end

function DamoclesMissionManager.isHQBarricaded()
    return DamoclesMissionValidator.isHQBarricaded()
end

function DamoclesMissionManager.checkSterileZone()
    return DamoclesMissionValidator.checkSterileZone()
end

function DamoclesMissionManager.isHQPoweredByGenerator()
    return DamoclesMissionValidator.isHQPoweredByGenerator()
end

function DamoclesMissionManager.checkHoldItems(player, mission)
    return DamoclesMissionValidator.checkHoldItems(player, mission)
end

function DamoclesMissionManager.checkFoodSupplies(player, reqFood, reqWater)
    return DamoclesMissionValidator.checkFoodSupplies(player, reqFood, reqWater)
end

function DamoclesMissionManager.checkVehicleSecured(player)
    return DamoclesMissionValidator.checkVehicleSecured(player)
end

function DamoclesMissionManager.checkGeneratorAcquired(player)
    return DamoclesMissionValidator.checkGeneratorAcquired(player)
end

-- =========================================================================

-- Generation dynamique des dossiers et objectifs
-- =========================================================================

function DamoclesMissionManager.spawnQuestTarget(spawnData)
    if not spawnData or not spawnData.item then return end
    if _state.spawnedQuests[spawnData.item] then return end
    _state.spawnedQuests[spawnData.item] = true

    local cell = getCell()
    if not cell then return end
    local hq = _state.hqLocation or { x = 0, y = 0, z = 0 }

    local placed = false
    -- Scanner les batiments voisins hors QG pour trouver un conteneur
    for radius = 25, 90, 15 do
        if placed then break end
        for dx = -radius, radius, 12 do
            if placed then break end
            for dy = -radius, radius, 12 do
                local sx = hq.x + dx
                local sy = hq.y + dy
                local sq = cell:getGridSquare(sx, sy, 0)
                if sq and sq:getBuilding() and not DamoclesMissionManager.isInsideHQ(sx, sy, 0) then
                    local objs = sq:getObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            local cont = obj and obj:getContainer()
                            if cont then
                                cont:AddItem(spawnData.item)
                                print(string.format("[DamoclesMissionManager] Quete : %s genere dans conteneur en (%d, %d)", spawnData.item, sx, sy))
                                placed = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fallback : spawn d'un zombie courier porteur de l'item
    if not placed and addZombiesInOutfit then
        local zx = hq.x + 35
        local zy = hq.y + 35
        local outfit = spawnData.outfit or "Doctor"
        local zList = addZombiesInOutfit(zx, zy, 0, 1, outfit, 50, false, false, false, false, 1.5)
        if zList and zList:size() > 0 then
            local z = zList:get(0)
            if z and z:getInventory() then
                z:getInventory():AddItem(spawnData.item)
                print(string.format("[DamoclesMissionManager] Quete : Zombie porteur %s genere en (%d, %d)", spawnData.item, zx, zy))
                placed = true
            end
        end
    end
end

-- =========================================================================
-- Actions & Progression
-- =========================================================================

function DamoclesMissionManager.onProgress(id, amount)
    local m = DamoclesMissionDB.getById(id)
    if not m or m.status ~= "ACTIVE" then return end

    amount = amount or 1
    m.currentCount = math.min(m.targetCount, m.currentCount + amount)
    print(string.format("[DamoclesMissionManager] Progression %s : %d/%d", id, m.currentCount, m.targetCount))

    if m.currentCount >= m.targetCount then
        DamoclesMissionManager.onComplete(id)
    else
        DamoclesMissionManager._saveToModData()
    end
end

function DamoclesMissionManager.onComplete(id)
    local m = DamoclesMissionDB.getById(id)
    if not m or m.status == "COMPLETED" then return end

    m.status       = "COMPLETED"
    m.currentCount = m.targetCount

    _state.researchGainTotal = _state.researchGainTotal + (m.researchGain or 0)
    print(string.format("[DamoclesMissionManager] Mission completee : %s (+%d%% recherche | Total: %d%%)",
        id, m.researchGain or 0, DamoclesMissionManager.getGlobalResearch()))

    if id == "hq_claim" then
        _state.hqStatus = { label = "QG ETABLI - EN ATTENTE RADIO", level = "normal" }
    elseif id == "hq_radio" then
        _state.hqStatus = { label = "TERMINAL POSE - CONTACT REQUIS", level = "normal" }
    elseif id == "contact_central_12" then
        _state.countdownActive    = false
        _state.deadlineWorldHours = nil
        _state.hqStatus = { label = "OPERATION DAMOCLES ANNULEE - EXTRACTION", level = "normal" }
    end

    DamoclesMissionManager._checkUnlocks()
    DamoclesMissionManager._saveToModData()

    if isServer() then
        sendServerCommand("DamoclesServer", "MissionCompletedNotify", {
            missionId    = id,
            title        = m.title,
            researchGain = m.researchGain or 0,
        })
        if m.eventOnComplete then
            sendServerCommand("DamoclesServer", m.eventOnComplete, { missionId = id })
        end
    elseif DamoclesNotifyMissionComplete then
        DamoclesNotifyMissionComplete(m.title, m.researchGain or 0)
    end
end

--- Traite l'action "Contacter le Central" sur le terminal radio
function DamoclesMissionManager.onRadioContact(player)
    local activeMissions = DamoclesMissionManager.getActiveMissions()
    for _, m in ipairs(activeMissions) do
        if m.type == "RADIO_CONTACT" then
            DamoclesMissionManager.onComplete(m.id)
            return true, m
        elseif m.type == "RADIO_CRYPTO_FINAL" then
            local inv = player and player:getInventory()
            if inv and inv:contains("Damocles.Damocles_Vaccine_Vial") then
                DamoclesMissionManager.onComplete(m.id)
                return true, m
            end
        end
    end
    return false, nil
end

function DamoclesMissionManager.checkCountdownExpiry()
    if not _state.countdownActive or not _state.deadlineWorldHours then return end

    if DamoclesGameTime.isExpired(_state.deadlineWorldHours) then
        _state.countdownActive    = false
        _state.deadlineWorldHours = nil
        _state.hqStatus = { label = "FRAPPE DAMOCLES IMMINENTE", level = "critical" }

        if isServer() then
            sendServerCommand("DamoclesServer", "DamoclesImpact", {})
        end
        print("[DamoclesMissionManager] DEADLINE EXPIREE - Impact Damocles.")
        DamoclesMissionManager._saveToModData()
    end
end

function DamoclesMissionManager.tickCountdown(deltaSeconds)
    DamoclesMissionManager.checkCountdownExpiry()
end

function DamoclesMissionManager._checkUnlocks()
    local research = DamoclesMissionManager.getGlobalResearch()

    for _, m in ipairs(DamoclesMissionDB.getAll()) do
        if m.status == "LOCKED" then
            if research >= m.minResearch then
                local prereqOk = true
                for _, prereqId in ipairs(m.prereqMissions or {}) do
                    local prereq = DamoclesMissionDB.getById(prereqId)
                    if not prereq or prereq.status ~= "COMPLETED" then
                        prereqOk = false
                        break
                    end
                end

                if prereqOk then
                    m.status = "ACTIVE"
                    print("[DamoclesMissionManager] Mission debloquee : " .. m.id)
                    if m.spawnTarget then
                        DamoclesMissionManager.spawnQuestTarget(m.spawnTarget)
                    end
                end
            end
        end
    end
end

function DamoclesMissionManager._saveToModData()
    if isClient() then return end

    local worldData = ModData.getOrCreate("DamoclesWorld")

    local savedMissions = {}
    for id, m in pairs(DamoclesMissionDB.catalog) do
        savedMissions[id] = {
            status       = m.status,
            currentCount = m.currentCount,
        }
    end

    worldData["missions"]           = savedMissions
    worldData["researchGainTotal"]  = _state.researchGainTotal
    worldData["deadlineWorldHours"] = _state.deadlineWorldHours
    worldData["countdownActive"]    = _state.countdownActive
    worldData["hqLocation"]         = _state.hqLocation
    worldData["hqBuilding"]         = _state.hqBuilding
    worldData["hqStatus"]           = _state.hqStatus
    worldData["terminalLocation"]   = _state.terminalLocation
    worldData["terminalLocked"]     = _state.terminalLocked
    worldData["spawnedQuests"]      = _state.spawnedQuests

    if isServer() then
        ModData.transmit("DamoclesWorld")
    end
end

function DamoclesMissionManager._loadFromModData()
    if isClient() then return nil end
    local worldData = ModData.getOrCreate("DamoclesWorld")
    if not worldData["missions"] then return nil end
    return worldData
end
