--[[
    PROJET DAMOCLES - DamoclesMissionDef.lua
    Constructeur et schema de reference pour un objet Mission.
    Responsabilite : definir la structure d'une mission, sans logique ni donnees.
]]

DamoclesMissionDef = DamoclesMissionDef or {}

--- Cree un objet Mission complet avec valeurs par defaut.
--- @param data table Tableau de champs a surcharger
--- @return table Mission validee avec tous les champs garantis
function DamoclesMissionDef.new(data)
    if not data or not data.id then
        error("[DamoclesMissionDef] Une mission doit avoir un champ 'id'.")
    end

    local mission = {
        -----------------------------------------------------------------------
        -- Identite
        -----------------------------------------------------------------------
        id              = data.id,
        title           = data.title          or "MISSION INCONNUE",
        description     = data.description    or "",
        category        = data.category       or "LOGISTICS",
        -- "HQ" | "VACCINE" | "LOGISTICS" | "INTEL" | "DEFENSE" | "RADIO"

        phase           = data.phase          or 1,
        -- Phase de recherche a laquelle cette mission appartient (0 a 4)

        order           = data.order          or 0,
        -- Ordre d'enchainement strict dans le scenario

        -----------------------------------------------------------------------
        -- Dialogue & Transmission Radio du Central
        -----------------------------------------------------------------------
        radioTransmission = data.radioTransmission or nil,
        -- Lignes de transmission transmises par le Commandement au terminal

        -----------------------------------------------------------------------
        -- Condition d'activation
        -----------------------------------------------------------------------
        minResearch     = data.minResearch    or 0,
        -- % de recherche globale minimum pour que cette mission passe a ACTIVE

        prereqMissions  = data.prereqMissions or {},
        -- Liste d'IDs de missions devant etre COMPLETED avant activation

        -----------------------------------------------------------------------
        -- Objectif de progression
        -----------------------------------------------------------------------
        type            = data.type           or "ITEM_DELIVERY",
        -- "ITEM_DELIVERY" | "PLACE_OBJECT" | "PLACE_OBJECT_SURFACE" | "RADIO_CONTACT"
        -- | "HQ_CLEAN_BARRICADE" | "HOLD_ITEMS" | "HQ_FURNITURE_POWER" | "CRAFT"
        -- | "RADIO_CRYPTO_FINAL" | "SAFEHOUSE_CLAIM" | "GATHER_FOOD" | "SECURE_VEHICLE"
        -- | "FIND_GENERATOR_FUEL"

        targetItem      = data.targetItem     or nil,
        -- ID PZ complet de l'item si pertinent (ex: "Radio.HamRadio2")

        requiredItems   = data.requiredItems  or nil,
        -- Liste d'items requis en inventaire pour type "HOLD_ITEMS"

        spawnTarget     = data.spawnTarget    or nil,
        -- Donnees de generation dynamique de l'objectif { item = "...", outfit = "..." }

        targetCount     = data.targetCount    or 1,
        currentCount    = data.currentCount   or 0,
        unit            = data.unit           or "unite(s)",
        -- Label affiche dans la jauge

        -----------------------------------------------------------------------
        -- Completion & Recompenses
        -----------------------------------------------------------------------
        isRepeatable    = data.isRepeatable   or false,
        status          = data.status         or "LOCKED",
        -- "LOCKED" | "ACTIVE" | "COMPLETED"

        researchGain    = data.researchGain   or 0,
        -- % ajoute a la recherche globale IRIS a la completion

        -----------------------------------------------------------------------
        -- Bridge Zombie Vaccine & Evenements
        -----------------------------------------------------------------------
        unlocksRecipe   = data.unlocksRecipe  or nil,
        -- ID de recette debloquee cote Zombie Vaccine a la completion

        eventOnComplete = data.eventOnComplete or nil,
        -- Nom de l'event serveur emis a la completion (sendServerCommand)
    }

    return mission
end

--- Verifie qu'un objet a bien la structure d'une Mission (guard basique).
--- @param m table
--- @return boolean
function DamoclesMissionDef.isValid(m)
    return type(m) == "table"
        and type(m.id) == "string"
        and type(m.status) == "string"
        and type(m.targetCount) == "number"
        and type(m.currentCount) == "number"
end
