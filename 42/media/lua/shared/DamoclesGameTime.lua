--[[
    PROJET DAMOCL S - DamoclesGameTime.lua
    Utilitaire partag  (client ET serveur) pour la gestion du temps de jeu PZ.

    Responsabilit  : Encapsuler les appels   l'API GameTime de PZ et exposer
    des fonctions propres pour le countdown et les conversions.

    API PZ B42 utilis e :
        GameTime.getInstance():getWorldAgeHours()    heures  coul es depuis la cr ation du monde (flottant)
        GameTime.getInstance():getHour()             heure courante (0-23)
        GameTime.getInstance():getDay()              jour courant
        GameTime.getInstance():getTimeScale()        multiplicateur de vitesse du temps

    Strat gie du countdown :
        On ne stocke PAS un compteur d croissant fragile aux red marrages.
        On stocke une "deadline" en heures de jeu :
            deadlineWorldHours = currentWorldAgeHours + countdownDurationHours
        Dur e restante = deadlineWorldHours - GameTime.getWorldAgeHours()
          Survit aux arr ts/relances serveur sans aucune d rive.
]]

DamoclesGameTime = DamoclesGameTime or {}

-- Duree par defaut du compte a rebours, en heures de JEU
-- 336 heures de jeu = 14 jours in-game par defaut
DamoclesGameTime.DEFAULT_COUNTDOWN_HOURS = 336

--- Retourne la duree initiale du compte a rebours configuree dans les options Sandbox (ou 14 jours par defaut).
--- @return number Duree en heures de jeu
function DamoclesGameTime.getInitialCountdownHours()
    local days = 14
    if SandboxVars and SandboxVars.Damocles and SandboxVars.Damocles.CountdownDays then
        days = tonumber(SandboxVars.Damocles.CountdownDays) or 14
    end
    if days < 5 then days = 5 end
    if days > 30 then days = 30 end
    return days * 24
end

------------------------------------------------------------------------
-- Accesseurs du temps de jeu
------------------------------------------------------------------------

--- Retourne le nombre total d'heures de jeu ecoulees depuis la creation du monde.
--- Fonctionne cote client ET serveur.
--- @return number Heures de jeu totales (flottant)
function DamoclesGameTime.getWorldAgeHours()
    local gt = GameTime.getInstance()
    if not gt then return 0 end
    return gt:getWorldAgeHours()
end

--- Retourne l'heure actuelle dans la journee (0.0 a 23.999...).
--- @return number
function DamoclesGameTime.getCurrentHour()
    local gt = GameTime.getInstance()
    if not gt then return 0 end
    return gt:getHour() + (gt:getMinutes() / 60.0)
end

--- Retourne le jour de jeu actuel (commence a 1).
--- @return number
function DamoclesGameTime.getCurrentDay()
    local gt = GameTime.getInstance()
    if not gt then return 1 end
    return gt:getDay()
end

--- Retourne le multiplicateur de vitesse du temps (ex: 60 = 1min reelle = 1h jeu).
--- @return number
function DamoclesGameTime.getTimeScale()
    local gt = GameTime.getInstance()
    if not gt then return 60 end
    return gt:getTimeScale()
end

------------------------------------------------------------------------
-- Calcul du countdown
------------------------------------------------------------------------

--- Calcule le nombre de SECONDES DE JEU restantes avant la deadline.
--- Retourne 0 si la deadline est depassee.
--- @param deadlineWorldHours number Heure de jeu cible (stockee dans ModData)
--- @return number Secondes de jeu restantes
function DamoclesGameTime.getRemainingGameSeconds(deadlineWorldHours)
    if not deadlineWorldHours then return 0 end
    local current = DamoclesGameTime.getWorldAgeHours()
    local remainingHours = deadlineWorldHours - current
    if remainingHours <= 0 then return 0 end
    return remainingHours * 3600
end

--- Calcule la deadline a partir de maintenant + une duree en heures de jeu.
--- A appeler une seule fois a l'initialisation du mod (premiere partie).
--- @param durationHours number Duree souhaitee en heures de jeu
--- @return number deadlineWorldHours a stocker dans ModData
function DamoclesGameTime.computeDeadline(durationHours)
    local targetHours = durationHours or DamoclesGameTime.getInitialCountdownHours()
    return DamoclesGameTime.getWorldAgeHours() + targetHours
end

--- V rifie si la deadline est atteinte ou d pass e.
--- @param deadlineWorldHours number
--- @return boolean
function DamoclesGameTime.isExpired(deadlineWorldHours)
    return DamoclesGameTime.getWorldAgeHours() >= deadlineWorldHours
end

------------------------------------------------------------------------
-- Formatage pour l'affichage UI
------------------------------------------------------------------------

--- Formate des secondes de jeu en cha ne "JJj HHh MMm SSs" ou "HHh MMm SSs".
--- @param totalGameSeconds number
--- @return string
function DamoclesGameTime.formatGameSeconds(totalGameSeconds)
    if not totalGameSeconds or totalGameSeconds <= 0 then
        return "00h 00m 00s"
    end

    local totalSec = math.floor(totalGameSeconds)
    local days     = math.floor(totalSec / 86400)
    local hours    = math.floor((totalSec % 86400) / 3600)
    local minutes  = math.floor((totalSec % 3600) / 60)
    local seconds  = totalSec % 60

    if days > 0 then
        return string.format("%dj %02dh %02dm %02ds", days, hours, minutes, seconds)
    else
        return string.format("%02dh %02dm %02ds", hours, minutes, seconds)
    end
end

--- Formate des heures de jeu restantes en cha ne lisible.
--- @param deadlineWorldHours number
--- @return string
function DamoclesGameTime.formatRemainingFromDeadline(deadlineWorldHours)
    local secs = DamoclesGameTime.getRemainingGameSeconds(deadlineWorldHours)
    return DamoclesGameTime.formatGameSeconds(secs)
end
