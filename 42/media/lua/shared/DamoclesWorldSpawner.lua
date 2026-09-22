--[[
    PROJET DAMOCLES - DamoclesWorldSpawner.lua
    Framework modulaire d'injection dynamique d'objets, conteneurs et zombies personnalises.
    
    Fonctionnalites :
      1. Injection de loot dans les conteneurs du monde (OnFillContainer)
      2. Apparition d'objets sur coordonnees de carte (LoadGridsquare)
      3. Generation instantanee de zombies avec paquetage specifique (outfit + loot)
      4. Support de filtres multi-cartes (Knox Country / Project France)
--]]

DamoclesWorldSpawner = DamoclesWorldSpawner or {}
DamoclesWorldSpawner.lootRules = {}
DamoclesWorldSpawner.coordSpawns = {}
DamoclesWorldSpawner.spawnedCoords = {}

--- Identifie la carte active (Knox Country, Project France, etc.)
function DamoclesWorldSpawner.getCurrentMapId()
    local mapName = "KnoxCountry"
    pcall(function()
        if getCore() and getCore().getGameMode then
            local mode = getCore():getGameMode()
            if mode and mode:find("France") then mapName = "ProjectFrance" end
        end
        local mapDir = getServerOptions and getServerOptions():getOption("Map")
        if mapDir and tostring(mapDir):find("France") then
            mapName = "ProjectFrance"
        end
    end)
    return mapName
end

------------------------------------------------------------------------
-- 1. REGISTRE ET GESTION DU LOOT DANS LES CONTENEURS
------------------------------------------------------------------------

--- Enregistre une regle d'injection de loot dans les conteneurs
--- @param rule table { id, itemType, chance (1-100), maxSpawns, roomTypes, containerTypes, mapId }
function DamoclesWorldSpawner.registerLootRule(rule)
    if not rule or not rule.id or not rule.itemType then return end
    DamoclesWorldSpawner.lootRules[rule.id] = rule
end

--- Hook OnFillContainer : Injecte les objets selon les regles enregistrees
local function onFillContainer(roomType, containerType, container)
    if not container then return end

    local currentMap = DamoclesWorldSpawner.getCurrentMapId()

    for _, rule in pairs(DamoclesWorldSpawner.lootRules) do
        -- Verification de la carte compatible
        local mapMatch = true
        if rule.mapId and rule.mapId ~= currentMap then
            mapMatch = false
        end

        -- Verification du type de piece (roomType)
        local roomMatch = true
        if rule.roomTypes and roomType then
            roomMatch = rule.roomTypes[roomType] or false
        end

        -- Verification du type de conteneur
        local contMatch = true
        if rule.containerTypes and containerType then
            contMatch = rule.containerTypes[containerType] or false
        end

        if mapMatch and roomMatch and contMatch then
            local roll = ZombRand(100) + 1
            if roll <= (rule.chance or 20) then
                local count = rule.count or 1
                for _ = 1, count do
                    container:AddItem(rule.itemType)
                end
                print(string.format("[DamoclesWorldSpawner] Item injecte '%s' dans conteneur '%s' (Piece: %s)",
                    rule.itemType, tostring(containerType), tostring(roomType)))
            end
        end
    end
end

Events.OnFillContainer.Add(onFillContainer)

------------------------------------------------------------------------
-- 2. SPAWN D'OBJETS SUR COORDONNEES DU MONDE
------------------------------------------------------------------------

--- Enregistre un point d'apparition sur coordonnees precises
--- @param def table { id, itemType, x, y, z, inContainer, mapId }
function DamoclesWorldSpawner.registerCoordinateSpawn(def)
    if not def or not def.id or not def.x or not def.y then return end
    DamoclesWorldSpawner.coordSpawns[def.id] = def
end

local function onLoadGridsquare(square)
    if not square then return end
    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    local currentMap = DamoclesWorldSpawner.getCurrentMapId()

    for id, def in pairs(DamoclesWorldSpawner.coordSpawns) do
        if not DamoclesWorldSpawner.spawnedCoords[id] then
            if def.x == sx and def.y == sy and (def.z or 0) == sz then
                local mapOk = (not def.mapId) or (def.mapId == currentMap)
                if mapOk then
                    DamoclesWorldSpawner.spawnedCoords[id] = true

                    pcall(function()
                        if def.inContainer then
                            local objs = square:getObjects()
                            local placed = false
                            if objs then
                                for i = 0, objs:size() - 1 do
                                    local o = objs:get(i)
                                    if o and o.getContainer and o:getContainer() then
                                        o:getContainer():AddItem(def.itemType)
                                        placed = true
                                        break
                                    end
                                end
                            end
                            if not placed then
                                square:AddWorldInventoryItem(def.itemType, 0.5, 0.5, 0)
                            end
                        else
                            square:AddWorldInventoryItem(def.itemType, 0.5, 0.5, 0)
                        end
                        print(string.format("[DamoclesWorldSpawner] Item pose sur coordonnees '%s' en (%d, %d, %d)",
                            def.itemType, sx, sy, sz))
                    end)
                end
            end
        end
    end
end

Events.LoadGridsquare.Add(onLoadGridsquare)

------------------------------------------------------------------------
-- 3. INTERFACE SIMPLE DE SPAWN DE ZOMBIES EQUIPES (METHODE RAPIDE)
------------------------------------------------------------------------

--- Fait apparaitre un zombie avec une tenue particuliere et un butin d'inventaire specifique
--- @param x number|table Coordonnee X ou objet IsoGridSquare
--- @param y number|nil Coordonnee Y (optionnel si x est une IsoGridSquare)
--- @param z number|nil Coordonnee Z (optionnel si x est une IsoGridSquare)
--- @param outfit string|nil Nom de l'outfit vanilla (ex: "ArmyGeneral", "Doctor", "PoliceState", "HazardSuit")
--- @param items table|nil Liste d'ID d'items a placer dans son inventaire (ex: { "Damocles.Damocles_Doc_Vol1", "Base.Pistol" })
--- @param options table|nil Options { femaleChance, crawler, health, attachedWeapon }
--- @return IsoZombie|nil Le zombie instancie
function DamoclesWorldSpawner.spawnZombieWithLoot(x, y, z, outfit, items, options)
    local zx, zy, zz = 0, 0, 0
    if type(x) == "table" and x.getX and x.getY then
        zx = x:getX()
        zy = x:getY()
        zz = x:getZ() or 0
    else
        zx = x or 0
        zy = y or 0
        zz = z or 0
    end

    options = options or {}
    local femaleChance = options.femaleChance or 50
    local crawler = options.crawler or false
    local isFallOnFront = false
    local isFakeDead = false
    local knockedDown = false
    local health = options.health or 1.0

    local zombieList = nil
    pcall(function()
        if addZombiesInOutfit then
            zombieList = addZombiesInOutfit(zx, zy, zz, 1, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, health)
        end
    end)

    if zombieList and zombieList:size() > 0 then
        local zombie = zombieList:get(0)
        if zombie and items and type(items) == "table" then
            local inv = zombie:getInventory()
            if inv then
                for _, itemType in ipairs(items) do
                    local it = inv:AddItem(itemType)
                    if it and it.getName then
                        print(string.format("[DamoclesWorldSpawner] Item '%s' ajoute a l'inventaire du zombie (%s)", it:getName(), tostring(outfit)))
                    end
                end
            end
        end
        return zombie
    end

    return nil
end

--- Raccourci rapide : Fait apparaitre un chercheur / virologue zombie porteur d'echantillon
function DamoclesWorldSpawner.spawnScientistZombie(x, y, z, lootItems)
    return DamoclesWorldSpawner.spawnZombieWithLoot(x, y, z, "Doctor", lootItems or { "ZombieVaccine.BloodSample" }, { femaleChance = 40 })
end

--- Raccourci rapide : Fait apparaitre un officier militaire zombie equipe
function DamoclesWorldSpawner.spawnMilitaryZombie(x, y, z, lootItems)
    return DamoclesWorldSpawner.spawnZombieWithLoot(x, y, z, "ArmyGeneral", lootItems or { "Base.Pistol", "Base.9mmClip" }, { femaleChance = 20 })
end

--- Raccourci rapide : Fait apparaitre un infecte en combinaison Hazmat
function DamoclesWorldSpawner.spawnHazmatZombie(x, y, z, lootItems)
    return DamoclesWorldSpawner.spawnZombieWithLoot(x, y, z, "HazardSuit", lootItems, { femaleChance = 50 })
end
