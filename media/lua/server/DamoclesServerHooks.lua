--[[
    PROJET DAMOCLES - DamoclesServerHooks.lua
    Hooks serveur et solo pour Project Zomboid (B41 et B42).

    Responsabilites :
        - Initialiser DamoclesMissionManager au demarrage
        - Surveiller la pose du terminal radio sur meuble / table (HamRadio2)
        - Valider les missions de terrain (zone sterile, barricades, generateur, possession d'items)
        - Gerer le compte a rebours mondial et le radar de menace zombies
        - Traiter les commandes client (ClaimHQ, RadioContact, SubmitItems)
]]

require "DamoclesMissionManager"
require "DamoclesMissionDB"
require "DamoclesGameTime"
require "DamoclesWorldSpawner"

local THREAT_SCAN_RADIUS     = 80
local THREAT_WARN_THRESHOLD  = 15
local THREAT_CRIT_THRESHOLD  = 40
local HQ_OBJECT_SCAN_RADIUS  = 25

local function dist2D(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local function countZombiesNear(cx, cy, cz, radius)
    local cell = getCell()
    if not cell then return 0 end
    local zombieList = cell:getZombieList()
    if not zombieList then return 0 end

    local count = 0
    local rSq = radius * radius
    for i = 0, zombieList:size() - 1 do
        local z = zombieList:get(i)
        if z and z:isAlive() then
            local dx = z:getX() - cx
            local dy = z:getY() - cy
            if (dx * dx + dy * dy) <= rSq then
                count = count + 1
            end
        end
    end
    return count
end

------------------------------------------------------------------------
-- Hook : Demarrage du jeu / serveur
------------------------------------------------------------------------

local function onServerStarted()
    DamoclesMissionManager.init()
    print("[DamoclesServerHooks] Serveur demarre, MissionManager initialise.")
end

Events.OnServerStarted.Add(onServerStarted)

------------------------------------------------------------------------
-- Hook : Safehouse revendique -> Mission "hq_claim" (compatibilite MP)
------------------------------------------------------------------------

local function onSafehouseAdded(safehouse)
    local m = DamoclesMissionDB.getById("hq_claim")
    if not m or m.status ~= "ACTIVE" then return end

    local sq = safehouse:getX()
    local sy = safehouse:getY()
    local sw = safehouse:getW() or 20
    local sh = safehouse:getH() or 20

    DamoclesMissionManager.setHQBuilding({
        x = math.floor(sq + sw / 2),
        y = math.floor(sy + sh / 2),
        z = 0,
        minX = sq,
        minY = sy,
        maxX = sq + sw,
        maxY = sy + sh,
        roomName = safehouse:getTitle() or "Refuge Securise",
    })
    DamoclesMissionManager.onComplete("hq_claim")

    print(string.format("[DamoclesServerHooks] Tete de pont IRIS etablie via Safehouse en (%d, %d).", sq, sy))
    DamoclesServerHooks_broadcastState()
end

if Events.OnSafehouseAdded then
    Events.OnSafehouseAdded.Add(onSafehouseAdded)
end

------------------------------------------------------------------------
-- Hook : Objet pose dans le monde (Generateur)
-- NOTE : La pose du Terminal Radio et de l'Ordinateur est strictement
-- validee par l'action de placement du joueur dans DamoclesContextMenu.lua
------------------------------------------------------------------------

local function onObjectAdded(obj)
    if not obj then return end
    pcall(function()
        local hqLoc = DamoclesMissionManager.getHQLocation()
        if not hqLoc then return end

        local objType = (obj.getFullType and obj:getFullType()) or ""
        local spriteName = (obj.getSprite and obj:getSprite() and obj:getSprite():getName()) or ""

        local ox = math.floor(obj:getX())
        local oy = math.floor(obj:getY())
        local oz = math.floor(obj:getZ())
        local inBuilding = DamoclesMissionManager.isInsideHQ(ox, oy, oz)

        -- Detection du Generateur
        local it = obj.getItem and obj:getItem()
        local itemType = (it and it.getFullType and it:getFullType()) or ""
        local isGen = (instanceof(obj, "IsoGenerator"))
            or (objType == "Base.Generator")
            or (itemType == "Base.Generator")
            or (spriteName ~= "" and spriteName:find("appliances_misc_01_0") ~= nil)


        if isGen then
            local mGen = DamoclesMissionDB.getById("task_3_lab_station")
            if mGen and mGen.status == "ACTIVE" then
                local d = dist2D(ox, oy, hqLoc.x, hqLoc.y)
                if inBuilding or d <= HQ_OBJECT_SCAN_RADIUS then
                    print(string.format("[DamoclesServerHooks] Generateur detecte a proximite du QG (dist: %.1f).", d))
                end
            end
        end
    end)
end

Events.OnObjectAdded.Add(onObjectAdded)

------------------------------------------------------------------------
-- Hook : Surveillance periodique (EveryOneMinute)
------------------------------------------------------------------------

local function onEveryOneMinute()
    if not DamoclesMissionDB or not DamoclesMissionDB.getById then return end
    DamoclesMissionManager.checkCountdownExpiry()

    -- Verification Tache 1 : Zone sterile (0 cadavre + barricades)
    local mTask1 = DamoclesMissionDB.getById("task_1_sterile")
    if mTask1 and mTask1.status == "ACTIVE" then
        local noCorpses = DamoclesMissionManager.areCorpsesCleanedInHQ()
        local barricaded = DamoclesMissionManager.isHQBarricaded()
        if noCorpses and barricaded then
            print("[DamoclesServerHooks] Tache 1 validee : Zone sterile et barricadee.")
            DamoclesMissionManager.onComplete("task_1_sterile")
            DamoclesServerHooks_broadcastState()
        end
    end

    -- Verification Tache 3 : Generateur connecte et alimente
    local mTask3 = DamoclesMissionDB.getById("task_3_lab_station")
    if mTask3 and mTask3.status == "ACTIVE" then
        if DamoclesMissionManager.isHQPoweredByGenerator() then
            print("[DamoclesServerHooks] Tache 3 validee : Generateur en ligne avec carburant.")
            DamoclesMissionManager.onComplete("task_3_lab_station")
            DamoclesServerHooks_broadcastState()
        end
    end

    -- Verification des missions actives
    local activeMissions = DamoclesMissionManager.getActiveMissions()
    local p = getPlayer()
    for _, m in ipairs(activeMissions) do
        if m.type == "HOLD_ITEMS" then
            if p and DamoclesMissionManager.checkHoldItems(p, m) then
                print("[DamoclesServerHooks] Mission HOLD_ITEMS completee : " .. m.id)
                DamoclesMissionManager.onComplete(m.id)
                DamoclesServerHooks_broadcastState()
            end
        elseif m.type == "GATHER_FOOD" then
            if p and DamoclesMissionManager.checkFoodSupplies(p, m.targetFood or 20, m.targetWater or 4) then
                print("[DamoclesServerHooks] Mission GATHER_FOOD completee (vivres & eau) : " .. m.id)
                DamoclesMissionManager.onComplete(m.id)
                DamoclesServerHooks_broadcastState()
            end
        elseif m.type == "SECURE_VEHICLE" then
            if p and DamoclesMissionManager.checkVehicleSecured(p) then
                print("[DamoclesServerHooks] Mission SECURE_VEHICLE completee : " .. m.id)
                DamoclesMissionManager.onComplete(m.id)
                DamoclesServerHooks_broadcastState()
            end
        elseif m.type == "INSTALL_COMPUTER" then
            if p and DamoclesMissionManager.checkComputerInstalled(p) then
                print("[DamoclesServerHooks] Mission INSTALL_COMPUTER completee : " .. m.id)
                DamoclesMissionManager.onComplete(m.id)
                DamoclesServerHooks_broadcastState()
            end
        elseif m.type == "FIND_GENERATOR_FUEL" then
            if p and DamoclesMissionManager.checkGeneratorAcquired(p) then
                print("[DamoclesServerHooks] Mission FIND_GENERATOR_FUEL completee : " .. m.id)
                DamoclesMissionManager.onComplete(m.id)
                DamoclesServerHooks_broadcastState()
            end
        end
    end

    DamoclesMissionManager._saveToModData()
end

Events.EveryOneMinute.Add(onEveryOneMinute)

-- Hook : Verification lors de la descente d'un vehicule (permet de valider immediatement si stationne au QG)
local function onExitVehicle(character)
    local mVeh = DamoclesMissionDB.getById("prep_vehicle")
    if mVeh and mVeh.status == "ACTIVE" then
        local isComplete, steps = DamoclesMissionManager.checkVehicleSecured(character)
        if isComplete then
            print("[DamoclesServerHooks] Vehicule pleinement securise au QG (3/3 etapes) -> prep_vehicle validee !")
            DamoclesMissionManager.onComplete("prep_vehicle")
            DamoclesServerHooks_broadcastState()
        end
    end
end

Events.OnExitVehicle.Add(onExitVehicle)


------------------------------------------------------------------------
-- Hook : Radar de menace zombies (EveryTenMinutes)
------------------------------------------------------------------------

local function onEveryTenMinutes()
    local hqLoc = DamoclesMissionManager.getHQLocation()
    if not hqLoc then return end

    local count = countZombiesNear(hqLoc.x, hqLoc.y, hqLoc.z or 0, THREAT_SCAN_RADIUS)

    if count >= THREAT_CRIT_THRESHOLD then
        DamoclesMissionManager.setHQStatus(
            string.format("SIEGE EN COURS - %d ZOMBIES !", count),
            "critical"
        )
        if count >= THREAT_CRIT_THRESHOLD and count < THREAT_CRIT_THRESHOLD + 5 then
            addWorldSound(hqLoc.x, hqLoc.y, hqLoc.z or 0, 150, 80, false)
        end
    elseif count >= THREAT_WARN_THRESHOLD then
        DamoclesMissionManager.setHQStatus(
            string.format("ATTENTION : %d ZOMBIES A PROXIMITE", count),
            "warning"
        )
    else
        local termLocked = DamoclesMissionManager.isTerminalLocked()
        if termLocked then
            DamoclesMissionManager.setHQStatus("TERMINAL ACTIF - ZONE SECURISEE", "normal")
        else
            DamoclesMissionManager.setHQStatus("QG ETABLI - EN ATTENTE", "normal")
        end
    end

    DamoclesServerHooks_broadcastState()
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)

------------------------------------------------------------------------
-- Commandes Client -> Serveur
------------------------------------------------------------------------

local function onClientCommand(module, command, player, args)
    if module ~= "DamoclesClient" then return end

    if command == "ClaimHQ" then
        local m = DamoclesMissionDB.getById("hq_claim")
        if m and m.status == "ACTIVE" then
            DamoclesMissionManager.setHQBuilding(args)
            DamoclesMissionManager.onComplete("hq_claim")
            print(string.format("[DamoclesServerHooks] QG IRIS etabli par %s via ClaimHQ.",
                tostring(player and player:getUsername() or "Joueur Solo")))
            DamoclesServerHooks_broadcastState()
        end

    elseif command == "RadioContact" then
        local success, mission = DamoclesMissionManager.onRadioContact(player)
        if success then
            print(string.format("[DamoclesServerHooks] Contact radio valide pour : %s", mission and mission.id or "Inconnu"))
            DamoclesServerHooks_broadcastState()
        end

    elseif command == "SubmitItems" then
        local missionId = args and args.missionId
        local amount    = args and args.amount or 0
        if missionId and amount > 0 then
            DamoclesMissionManager.onProgress(missionId, amount)
            DamoclesServerHooks_broadcastState()
        end

    elseif command == "RequestState" then
        DamoclesServerHooks_sendStateToPlayer(player)
    end
end

Events.OnClientCommand.Add(onClientCommand)

--- Diffuse l'etat complet a tous les clients (ou au state local en Solo)
function DamoclesServerHooks_broadcastState()
    local activeMissions = {}
    for _, m in ipairs(DamoclesMissionManager.getActiveMissions()) do
        table.insert(activeMissions, {
            id                = m.id,
            title             = m.title,
            description       = m.description,
            currentCount      = m.currentCount,
            targetCount       = m.targetCount,
            unit              = m.unit,
            type              = m.type,
            status            = m.status,
            radioTransmission = m.radioTransmission,
        })
    end

    local completedList = {}
    for _, m in ipairs(DamoclesMissionDB.getAll()) do
        if m.status == "COMPLETED" then
            table.insert(completedList, {
                id           = m.id,
                title        = m.title,
                description  = m.description,
                researchGain = m.researchGain,
            })
        end
    end

    local payload = {
        globalResearchPercent = DamoclesMissionManager.getGlobalResearch(),
        countdownGameSeconds  = DamoclesMissionManager.getCountdown(),
        deadlineWorldHours    = DamoclesMissionManager.getDeadlineWorldHours(),
        hqStatus              = DamoclesMissionManager.getHQStatus(),
        hqLocation            = DamoclesMissionManager.getHQLocation(),
        hqBuilding            = DamoclesMissionManager.getHQBuilding(),
        terminalLocation      = DamoclesMissionManager.getTerminalLocation(),
        terminalLocked        = DamoclesMissionManager.isTerminalLocked(),
        missions              = activeMissions,
        completedMissions     = completedList,
    }

    if isServer() then
        sendServerCommand("DamoclesServer", "StateUpdate", payload)
    elseif DamoclesClientState then
        DamoclesClientState.onServerStateUpdate(payload)
    end
end

function DamoclesServerHooks_sendStateToPlayer(player)
    DamoclesServerHooks_broadcastState()
end
