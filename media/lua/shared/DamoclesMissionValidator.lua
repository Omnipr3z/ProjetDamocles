--[[
    PROJET DAMOCLES - DamoclesMissionValidator.lua
    Classe centrale dediee a la validation des conditions de succes des quetes et taches.

    Responsabilites :
      - Centraliser l'ensemble des verifications logiques de quetes (vehicules, vivres, carburant, generateur, etc.)
      - Fournir les methodes d'entree pour les hooks d'evenements (Events.EveryOneMinute, Events.OnExitVehicle, etc.)
      - Permettre l'ajout facile de futures missions s'appuyant sur les memes declencheurs (ex: nouvelles quetes de vehicule, transport, etc.)
--]]

require "DamoclesMissionDB"

DamoclesMissionValidator = DamoclesMissionValidator or {}

-- =========================================================================
-- 1. DISPATCHERS PRINCIPAUX (Appeles par les hooks d'evenements Events)
-- =========================================================================

--- Validation periodique executee par le hook Events.EveryOneMinute
--- Parcourt l'ensemble des missions actives et teste leurs conditions de reussite.
--- @param player IsoPlayer Joueur local ou nil
function DamoclesMissionValidator.onEveryOneMinute(player)
    if not DamoclesMissionDB or not DamoclesMissionDB.getById then return end
    player = player or getPlayer()

    -- 1. Verifications de taches specifiques historiques / scenario
    local mTask1 = DamoclesMissionDB.getById("task_1_sterile")
    if mTask1 and mTask1.status == "ACTIVE" then
        if DamoclesMissionValidator.checkSterileZone() then
            print("[DamoclesMissionValidator] Tache 1 validee : Zone sterile et barricadee.")
            DamoclesMissionManager.onComplete("task_1_sterile")
            if DamoclesServerHooks_broadcastState then DamoclesServerHooks_broadcastState() end
        end
    end

    local mTask3 = DamoclesMissionDB.getById("task_3_lab_station")
    if mTask3 and mTask3.status == "ACTIVE" then
        if DamoclesMissionValidator.isHQPoweredByGenerator() then
            print("[DamoclesMissionValidator] Tache 3 validee : Generateur en ligne avec carburant.")
            DamoclesMissionManager.onComplete("task_3_lab_station")
            if DamoclesServerHooks_broadcastState then DamoclesServerHooks_broadcastState() end
        end
    end

    -- 2. Dispatcher generique sur toutes les missions actives
    local activeMissions = DamoclesMissionManager.getActiveMissions()
    for _, m in ipairs(activeMissions) do
        local isComplete = false

        -- Verificateurs enregistres dynamiquement (extensibilite)
        if DamoclesMissionValidator.customCheckers and DamoclesMissionValidator.customCheckers[m.type] then
            isComplete = DamoclesMissionValidator.customCheckers[m.type](player, m)
        elseif m.type == "HOLD_ITEMS" then
            isComplete = DamoclesMissionValidator.checkHoldItems(player, m)
        elseif m.type == "GATHER_FOOD" then
            isComplete = DamoclesMissionValidator.checkFoodSupplies(player, m.targetFood or 20, m.targetWater or 4)
            if isComplete and player and player.Say then
                player:Say("Ravitaillement du QG termine. Je dois etablir la liaison radio avec le Central.")
            end
        elseif m.type == "SECURE_VEHICLE" then
            isComplete = DamoclesMissionValidator.checkVehicleSecured(player)
        elseif m.type == "INSTALL_COMPUTER" then
            isComplete = DamoclesMissionValidator.checkComputerInstalled(player)
        elseif m.type == "FIND_GENERATOR_FUEL" then
            isComplete = DamoclesMissionValidator.checkGeneratorAcquired(player)
        elseif m.type == "CLEAN_CORPSES" then
            isComplete = DamoclesMissionValidator.areCorpsesCleanedInHQ()
        elseif m.type == "BARRICADE_ACCESS" then
            isComplete = DamoclesMissionValidator.isHQBarricaded()
        elseif m.type == "CONNECT_POWER" then
            isComplete = DamoclesMissionValidator.isHQPoweredByGenerator()
        elseif m.type == "SAFEHOUSE_CLAIM" then
            isComplete = (DamoclesMissionManager.getHQBuilding() ~= nil)
        elseif m.type == "PLACE_OBJECT_SURFACE" then
            isComplete = DamoclesMissionManager.isMissionCompleted("hq_radio")
        end

        if isComplete then
            print(string.format("[DamoclesMissionValidator] Mission validee [%s] : %s", m.type, m.id))
            DamoclesMissionManager.onComplete(m.id)
            if DamoclesServerHooks_broadcastState then
                DamoclesServerHooks_broadcastState()
            end
        end
    end
end

--- Enregistre un validateur personnalise pour un type de mission specifique
--- @param missionType string Type de mission (ex: "REPAIR_VEHICLE", "ESCORT_VIP")
--- @param checkFunc function Fonction de validation (player, mission) -> boolean
function DamoclesMissionValidator.registerChecker(missionType, checkFunc)
    DamoclesMissionValidator.customCheckers = DamoclesMissionValidator.customCheckers or {}
    DamoclesMissionValidator.customCheckers[missionType] = checkFunc
end

--- Validation evenementielle executee lors de l'entree dans un vehicule (Events.OnEnterVehicle)
--- Permet de valider instantanement la prise en main d'un vehicule (ex: prep_vehicle et futures missions similaires).
--- @param character IsoGameCharacter Le personnage qui entre dans le vehicule
function DamoclesMissionValidator.onEnterVehicle(character)
    if not character or isClient() then return end
    local veh = character.getVehicle and character:getVehicle()
    if not veh then return end

    if veh.getModData then
        veh:getModData().damoclesEngineStarted = true
    end

    local activeMissions = DamoclesMissionManager.getActiveMissions()
    for _, m in ipairs(activeMissions) do
        if m.type == "SECURE_VEHICLE" then
            local isComplete = DamoclesMissionValidator.checkVehicleSecured(character)
            if isComplete then
                print(string.format("[DamoclesMissionValidator] Vehicule valide a l'entree pour mission : %s", m.id))
                DamoclesMissionManager.onComplete(m.id)
                if DamoclesServerHooks_broadcastState then
                    DamoclesServerHooks_broadcastState()
                end
            end
        end
    end
end

--- Validation evenementielle executee lors de la descente d'un vehicule (Events.OnExitVehicle)
--- Permet de valider instantanement les quetes de vehicule (prep_vehicle et futures missions similaires).
--- @param character IsoGameCharacter Le personnage qui quitte le vehicule
function DamoclesMissionValidator.onExitVehicle(character)
    if not character or isClient() then return end

    local activeMissions = DamoclesMissionManager.getActiveMissions()
    for _, m in ipairs(activeMissions) do
        if m.type == "SECURE_VEHICLE" then
            local isComplete = DamoclesMissionValidator.checkVehicleSecured(character)
            if isComplete then
                print(string.format("[DamoclesMissionValidator] Vehicule valide a la descente pour mission : %s", m.id))
                DamoclesMissionManager.onComplete(m.id)
                if DamoclesServerHooks_broadcastState then
                    DamoclesServerHooks_broadcastState()
                end
            end
        end
    end
end

--- Validation evenementielle lors de la pose d'un objet dans le monde (Events.OnObjectAdded)
--- @param obj IsoObject Objet ajoute dans le monde
function DamoclesMissionValidator.onObjectAdded(obj)
    if not obj then return end
    local hqLoc = DamoclesMissionManager.getHQLocation()
    if not hqLoc then return end

    local objType = (obj.getFullType and obj:getFullType()) or ""
    local spriteName = (obj.getSprite and obj:getSprite() and obj:getSprite():getName()) or ""
    local ox = math.floor(obj:getX())
    local oy = math.floor(obj:getY())
    local dist = math.sqrt((ox - hqLoc.x)^2 + (oy - hqLoc.y)^2)

    if dist <= 35 and (objType:find("Generator") or spriteName:find("generator")) then
        local m = DamoclesMissionDB.getById("prep_gen")
        if m and m.status == "ACTIVE" then
            print("[DamoclesMissionValidator] Generateur deploye au QG -> validation prep_gen.")
            DamoclesMissionManager.onComplete("prep_gen")
            if DamoclesServerHooks_broadcastState then
                DamoclesServerHooks_broadcastState()
            end
        end
    end
end

-- =========================================================================
-- 2. LOGIQUE SPECIFIQUE DE VALIDATION PAR DOMAINE
-- =========================================================================

-- -------------------------------------------------------------------------
-- A. VEHICULES TACTIQUES (Entree / Demarrage, Carburant, Stationnement QG)
-- -------------------------------------------------------------------------

--- Evalue un vehicule par rapport aux conditions de mobilite tactique
--- Parametrisable pour reutilisation facile sur de futures quetes de transport ou rapatriement.
--- @param veh BaseVehicle Vehicule a inspecter
--- @param player IsoPlayer Joueur examinant le vehicule
--- @param hq table Position du QG { x, y }
--- @param options table Options optionnelles { minFuel = 3.0, maxDistHQ = 35 }
--- @return boolean isComplete, number stepCount, boolean step1, boolean step2, boolean step3, number fuelAmount
function DamoclesMissionValidator.evaluateVehicle(veh, player, hq, options)
    if not veh or not veh.getX or not veh.getY then
        return false, 0, false, false, false, 0.0
    end

    options = options or {}
    local reqFuel = options.minFuel or 3.0
    local maxDist = options.maxDistHQ or 35
    local maxDistSq = maxDist * maxDist

    -- Etape 1 : Demarrage du moteur ou joueur monte a bord
    local isRunning = false
    pcall(function()
        if veh.isEngineRunning and veh:isEngineRunning() then
            isRunning = true
            veh:getModData().damoclesEngineStarted = true
        elseif veh.isEngineStarted and veh:isEngineStarted() then
            isRunning = true
            veh:getModData().damoclesEngineStarted = true
        end
    end)

    local step1 = false
    pcall(function()
        if isRunning or (veh:getModData() and veh:getModData().damoclesEngineStarted) then
            step1 = true
        end
        if player and player.getVehicle and player:getVehicle() == veh then
            step1 = true
            veh:getModData().damoclesEngineStarted = true
        end
    end)

    -- Etape 2 : Carburant suffisant
    local step2 = false
    local fuelAmount = 0.0
    pcall(function()
        local tank = veh.getPartById and veh:getPartById("GasTank")
        if tank and tank.getContainerContentAmount then
            fuelAmount = tank:getContainerContentAmount() or 0.0
            if fuelAmount >= reqFuel then
                step2 = true
            end
        end
    end)

    -- Etape 3 : Rapatriement a proximite du QG
    local step3 = false
    if hq and hq.x and hq.y then
        local dx = veh:getX() - hq.x
        local dy = veh:getY() - hq.y
        if (dx * dx + dy * dy) <= maxDistSq then
            step3 = true
        end
    end

    local count = (step1 and 1 or 0) + (step2 and 1 or 0) + (step3 and 1 or 0)
    local isComplete = (step1 and step2 and step3)

    return isComplete, count, step1, step2, step3, fuelAmount
end

--- Verifie si les 3 etapes d'acquisition d'un vehicule tactique sont remplies
--- @param player IsoPlayer
--- @return boolean isComplete, number completedSteps, table bestDetails
function DamoclesMissionValidator.checkVehicleSecured(player)
    local bestSteps = 0
    local isComplete = false
    local bestDetails = {
        step1 = false,
        step2 = false,
        step3 = false,
        fuel = 0.0,
        fuelTarget = 3.0,
    }

    local hq = DamoclesMissionManager.getHQLocation()
    local cell = getCell()
    local bestScore = -1

    -- 1. Si le joueur est actuellement a bord d'un vehicule (priorite absolue)
    if player and player.getVehicle and player:getVehicle() then
        local ok, cnt, s1, s2, s3, fuel = DamoclesMissionValidator.evaluateVehicle(player:getVehicle(), player, hq)
        bestScore = cnt + 10
        bestSteps = cnt
        bestDetails.step1 = s1
        bestDetails.step2 = s2
        bestDetails.step3 = s3
        bestDetails.fuel  = fuel
        if ok then isComplete = true end
    end

    -- 2. Scanner les vehicules dans la cellule
    if cell and cell.getVehicles then
        local okList, vehList = pcall(function() return cell:getVehicles() end)
        if okList and vehList and vehList.size then
            for i = 0, vehList:size() - 1 do
                local veh = vehList:get(i)
                local ok, cnt, s1, s2, s3, fuel = DamoclesMissionValidator.evaluateVehicle(veh, player, hq)
                if cnt > bestScore then
                    bestScore = cnt
                    bestSteps = cnt
                    bestDetails.step1 = s1
                    bestDetails.step2 = s2
                    bestDetails.step3 = s3
                    bestDetails.fuel  = fuel
                end
                if ok then
                    isComplete = true
                    bestSteps = 3
                    bestDetails.step1 = true
                    bestDetails.step2 = true
                    bestDetails.step3 = true
                    break
                end
            end
        end
    end

    return isComplete, bestSteps, bestDetails
end

-- -------------------------------------------------------------------------
-- B. VIVRES ET RESERVES D'EAU (GATHER_FOOD)
-- -------------------------------------------------------------------------

--- Verifie si le QG dispose de conserves/vivres non-perissables et de contenants d'eau/boissons
--- @param player IsoPlayer
--- @param reqFood number (defaut: 20)
--- @param reqWater number (defaut: 4)
--- @return boolean isComplete, number foodCount, number waterCount
function DamoclesMissionValidator.checkFoodSupplies(player, reqFood, reqWater)
    local targetFood = reqFood or 20
    local targetWater = reqWater or 4
    local foodCount = 0
    local waterCount = 0

    local function isNonPerishableFood(it)
        if not it then return false end

        local isFood = false
        if it.IsFood and it:IsFood() then isFood = true end
        if not isFood and it.getCategory and it:getCategory() == "Food" then isFood = true end
        if not isFood and (it.getHungerChange and it:getHungerChange() < 0) then isFood = true end
        if not isFood then return false end

        if it.isRotten and it:isRotten() then return false end
        if it.isBurnt and it:isBurnt() then return false end

        local ft = (it.getFullType and it:getFullType()) or ""
        local t = (it.getType and it:getType()) or ""
        local name = (it.getName and it:getName()) or ""
        local dName = (it.getDisplayName and it:getDisplayName()) or ""

        if t:find("Empty") or ft:find("Empty") or name:find("Empty") or dName:find("Empty")
           or name:find("vide") or dName:find("vide") then
            return false
        end

        if it.getOffAge and it:getOffAge() and it:getOffAge() >= 100000 then
            return true
        end
        if it.getOffAgeMax and it:getOffAgeMax() and it:getOffAgeMax() >= 100000 then
            return true
        end
        if it.isCanned and it:isCanned() then
            return true
        end

        if ft:find("ProjectFrance.") then
            if not t:find("Baguette") and not t:find("Croissant") and not t:find("PainChocolat") then
                return true
            end
        end

        local checkStr = (t .. " " .. ft .. " " .. name .. " " .. dName):lower()
        local keywords = {
            "canned", "tinned", "tin", "ration", "mre", "beans", "soup", "tuna",
            "cornedbeef", "sardine", "salmon", "chili", "bolognese", "evaporatedmilk", "spam",
            "bocal", "bocaux", "jar", "terrine", "pate", "confit", "rillettes", "foiegras",
            "confiture", "jam", "marmalade", "pickle", "pickled", "conserve",
            "biscuit", "cookie", "cracker", "crisps", "chips", "pretzel", "popcorn", "snack",
            "chocolate", "choc", "candy", "candies", "gummy", "lollipop", "marshmallow", "bonbon",
            "snickers", "mars",
            "cereal", "oats", "oatmeal", "pasta", "macaroni", "rice", "ramen", "noodles",
            "peanutbutter", "beefjerky", "jerky",
            "tartiflette", "boeufbourguignon", "blanquette", "bouillabaisse", "grabure",
            "andouillette", "confitdecanard", "piperade", "daube", "cassoulet", "ratatouille",
            "axoa", "choucroute", "moules", "petitsale"
        }

        for _, kw in ipairs(keywords) do
            if checkStr:find(kw) then
                return true
            end
        end

        return false
    end

    local function isWaterSupply(it)
        if not it then return false end
        if it.isWaterSource and it:isWaterSource() then
            if it.getUsedDelta and it:getUsedDelta() <= 0 then
                return false
            end
            return true
        end
        if it.getThirstChange and it:getThirstChange() < -0.05 then
            return true
        end
        local t = (it.getType and it:getType()) or ""
        local ft = (it.getFullType and it:getFullType()) or ""
        local name = (it.getName and it:getName()) or ""
        local checkStr = (t .. " " .. ft .. " " .. name):lower()
        if checkStr:find("water") or checkStr:find("pop") or checkStr:find("soda")
           or checkStr:find("juice") or checkStr:find("beer") or checkStr:find("wine")
           or checkStr:find("drink") or checkStr:find("cider") or checkStr:find("cidre")
           or checkStr:find("whiskey") or checkStr:find("bourbon") or checkStr:find("limonade")
           or checkStr:find("sirop") or checkStr:find("eau") then
            if not checkStr:find("empty") and not checkStr:find("vide") then
                return true
            end
        end
        return false
    end

    local function scanContainer(cont)
        if not cont then return end
        local items = cont:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                if isNonPerishableFood(it) then
                    foodCount = foodCount + 1
                elseif isWaterSupply(it) then
                    waterCount = waterCount + 1
                end
                if it.getItemContainer and it:getItemContainer() then
                    scanContainer(it:getItemContainer())
                end
            end
        end
    end

    local b = DamoclesMissionManager.getHQBuilding()
    local hqLoc = DamoclesMissionManager.getHQLocation()
    if not b and hqLoc then
        b = {
            minX = hqLoc.x - 15,
            maxX = hqLoc.x + 15,
            minY = hqLoc.y - 15,
            maxY = hqLoc.y + 15,
        }
    end

    if b then
        local cell = getCell()
        if cell then
            for z = 0, 7 do
                for x = b.minX, b.maxX do
                    for y = b.minY, b.maxY do
                        local sq = cell:getGridSquare(x, y, z)
                        if sq then
                            local objs = sq:getObjects()
                            if objs then
                                for o = 0, objs:size() - 1 do
                                    local obj = objs:get(o)
                                    if obj then
                                        local count = (obj.getContainerCount and obj:getContainerCount()) or 0
                                        if count > 0 then
                                            for cIdx = 0, count - 1 do
                                                scanContainer(obj:getContainerByIndex(cIdx))
                                            end
                                        elseif obj.getContainer and obj:getContainer() then
                                            scanContainer(obj:getContainer())
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local isComplete = (foodCount >= targetFood) and (waterCount >= targetWater)
    return isComplete, foodCount, waterCount
end

-- -------------------------------------------------------------------------
-- C. ITEMS REQUIS DANS L'INVENTAIRE (HOLD_ITEMS)
-- -------------------------------------------------------------------------

--- Verifie si le joueur possede les items requis pour une mission HOLD_ITEMS
function DamoclesMissionValidator.checkHoldItems(player, mission)
    if not player or not mission or not mission.requiredItems then return false end
    local inv = player:getInventory()
    if not inv then return false end
    for _, itemType in ipairs(mission.requiredItems) do
        local count = inv:getItemCount(itemType)
        if count < (mission.targetCount or 1) then
            return false
        end
    end
    return true
end

-- -------------------------------------------------------------------------
-- D. GENERATEUR & CARBURANT (FIND_GENERATOR_FUEL)
-- -------------------------------------------------------------------------

--- Verifie si un generateur et du carburant sont acquis (sur le joueur ou au QG)
function DamoclesMissionValidator.checkGeneratorAcquired(player)
    local hasGen = false
    local hasFuel = false

    -- 1. Verifier inventaire joueur
    if player then
        local inv = player:getInventory()
        if inv then
            if inv:containsTypeRec("Base.Generator") or inv:containsTypeRec("Generator") then
                hasGen = true
            end
            local cans = inv:getItemsFromType("Base.PetrolCan")
            if cans and cans:size() > 0 then
                for i = 0, cans:size() - 1 do
                    local can = cans:get(i)
                    if can and can:getUsedDelta() > 0 then
                        hasFuel = true
                        break
                    end
                end
            end
            local primary = player:getPrimaryHandItem()
            local secondary = player:getSecondaryHandItem()
            if (primary and primary:getType() == "Generator") or (secondary and secondary:getType() == "Generator") then
                hasGen = true
            end
        end
    end

    -- 2. Verifier objets poses ou dans le perimetre du QG
    local cell = getCell()
    local hqLoc = DamoclesMissionManager.getHQLocation()
    if cell and hqLoc then
        local genList = cell:getGeneratorList()
        if genList and genList:size() > 0 then
            for i = 0, genList:size() - 1 do
                local g = genList:get(i)
                if g then
                    local dx = g:getX() - hqLoc.x
                    local dy = g:getY() - hqLoc.y
                    if (dx * dx + dy * dy) <= 1600 then -- 40 cases
                        hasGen = true
                        if g:getFuel() > 0 then
                            hasFuel = true
                        end
                        break
                    end
                end
            end
        end
    end

    return hasGen and hasFuel
end

-- -------------------------------------------------------------------------
-- E. POSTE INFORMATIQUE ET TABLES (INSTALL_COMPUTER)
-- -------------------------------------------------------------------------

--- Verifie si un ordinateur de bureau est installe sur une table dans le QG
function DamoclesMissionValidator.checkComputerInstalled(player)
    local hqLoc = DamoclesMissionManager.getHQLocation()
    local b = DamoclesMissionManager.getHQBuilding()
    if not hqLoc and not b then return false end

    local cell = getCell()
    if not cell then return false end

    local minX = b and b.minX or (hqLoc.x - 20)
    local maxX = b and b.maxX or (hqLoc.x + 20)
    local minY = b and b.minY or (hqLoc.y - 20)
    local maxY = b and b.maxY or (hqLoc.y + 20)

    for x = minX, maxX do
        for y = minY, maxY do
            local sq = cell:getGridSquare(x, y, 0)
            if sq and DamoclesMissionManager.isTableSquare(sq) then
                local objs = sq:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj then
                            if obj.getModData and obj:getModData().isDamoclesComputer then
                                return true
                            end
                            local sprite = obj.getSprite and obj:getSprite() and obj:getSprite():getName() or ""
                            if sprite:find("appliances_com_01_7") or sprite:find("appliances_com_01_8") then
                                if obj.getModData then obj:getModData().isDamoclesComputer = true end
                                return true
                            end
                            local ft = obj.getFullType and obj:getFullType() or ""
                            if ft:find("DesktopComputer") or ft:find("Computer") then
                                if obj.getModData then obj:getModData().isDamoclesComputer = true end
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

-- -------------------------------------------------------------------------
-- F. ZONE STERILE & SECURISATION DU QG (CADAVRES, BARRICADES, ENERGIE)
-- -------------------------------------------------------------------------

--- Verifie qu'aucun cadavre ne se trouve a l'interieur du batiment du QG
function DamoclesMissionValidator.areCorpsesCleanedInHQ()
    local b = DamoclesMissionManager.getHQBuilding()
    if not b then return false end
    local cell = getCell()
    if not cell then return true end

    for x = b.minX, b.maxX do
        for y = b.minY, b.maxY do
            local sq = cell:getGridSquare(x, y, 0)
            if sq and sq:getBuilding() then
                local dead = sq:getDeadBodys()
                if dead and dead:size() > 0 then
                    return false
                end
            end
        end
    end
    return true
end

--- Verifie si au moins un acces du QG (porte ou fenetre) est barricade
function DamoclesMissionValidator.isHQBarricaded()
    local b = DamoclesMissionManager.getHQBuilding()
    if not b then return false end
    local cell = getCell()
    if not cell then return false end

    for x = b.minX, b.maxX do
        for y = b.minY, b.maxY do
            local sq = cell:getGridSquare(x, y, 0)
            if sq then
                local objs = sq:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj and obj.isBarricaded and obj:isBarricaded() then
                            return true
                        end
                        if obj and obj.getBarricadeOnSameSquare and obj:getBarricadeOnSameSquare() then
                            return true
                        end
                        if obj and obj.getBarricadeOnOppositeSquare and obj:getBarricadeOnOppositeSquare() then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

--- Verifie si la zone sterile du QG est etablie (aucun cadavre + barricades)
function DamoclesMissionValidator.checkSterileZone()
    return DamoclesMissionValidator.areCorpsesCleanedInHQ() and DamoclesMissionValidator.isHQBarricaded()
end

--- Verifie si un generateur connecte et pourvu en carburant alimente le QG
function DamoclesMissionValidator.isHQPoweredByGenerator()
    local b = DamoclesMissionManager.getHQBuilding()
    local hq = DamoclesMissionManager.getHQLocation()
    if not b or not hq then return false end

    local cell = getCell()
    if not cell then return false end
    local genList = cell:getGeneratorList()
    if genList then
        for i = 0, genList:size() - 1 do
            local gen = genList:get(i)
            if gen and gen:isConnected() and gen:getFuel() > 0 then
                local dx = gen:getX() - hq.x
                local dy = gen:getY() - hq.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= 35 or DamoclesMissionManager.isInsideHQ(gen:getX(), gen:getY(), gen:getZ()) then
                    return true
                end
            end
        end
    end
    return false
end
