--[[
    PROJET DAMOCL S - Mod le de donn es Mock ( tape 1)
    Ce fichier encapsule l' tat factice consomm  par l'interface en attendant la couche de donn es persistante (ModData/Serveur).
]]

DamoclesMockData = DamoclesMockData or {}

DamoclesMockData.state = {
    -- Compte   rebours avant frappe nucl aire (en secondes)
    -- 142 heures, 24 minutes, 5 secondes
    countdownSeconds = (142 * 3600) + (24 * 60) + 5,
    countdownActive = true,

    -- Progression de la recherche globale IRIS (0   100%)
    globalResearchPercent = 40,
    researchMilestones = { 20, 40, 60, 80 },

    -- Profil joueur
    operatorRole = "OPERATEUR LOGISTIQUE",
    operatorIcon = "media/textures/Damocles/icon_gear.png",

    -- Etat du QG IRIS
    hqStatus = {
        label = "ATTENTION : ATTAQUE IMMINENTE",
        level = "warning", -- "normal", "warning", "critical"
        icon = "media/textures/Damocles/icon_warning.png",
    },

    -- Missions en cours
    missions = {
        {
            id = "mission_fuel",
            title = "RAMENER ESSENCE (STATION)",
            current = 5,
            target = 100,
            unit = "Jerricans",
            icon = "media/textures/Damocles/icon_fuel.png",
            completed = false,
        },
        {
            id = "mission_data",
            title = "RAPPORTER DONNEES ARNAULT",
            current = 0,
            target = 1,
            unit = "Document",
            icon = "media/textures/Damocles/icon_mic.png",
            completed = false,
        },
        {
            id = "mission_samples",
            title = "PRELEVER ECHANTILLONS INFECTES",
            current = 15,
            target = 50,
            unit = "Sang Stable",
            icon = "media/textures/Damocles/icon_vial.png",
            completed = false,
        },
    }
}

--- Retourne les donn es courantes
function DamoclesMockData.getData()
    return DamoclesMockData.state
end

--- Formate des secondes en cha ne "XXh YYm ZZs"
function DamoclesMockData.formatCountdown(totalSeconds)
    if not totalSeconds or totalSeconds < 0 then
        return "00h 00m 00s"
    end
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = math.floor(totalSeconds % 60)
    return string.format("%02dh %02dm %02ds", hours, minutes, seconds)
end
