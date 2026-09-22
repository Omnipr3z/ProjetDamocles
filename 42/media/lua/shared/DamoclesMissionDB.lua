--[[
    PROJET DAMOCLES - DamoclesMissionDB.lua
    Catalogue complet du scenario en 12 taches et boucles de transmission radio.
    Structure narrative :
        Phase 0 - Tete de pont & Terminal Radio
        Phase 1 - Etablissement de la base & Protocoles d'urgence (Taches 1 a 3)
        Phase 2 - Donnees virologiques & Echantillonnage primaire (Taches 4 a 6)
        Phase 3 - Culture cellulaire & Attenuation du virus (Taches 7 a 9)
        Phase 4 - Le Vaccin Damocles & Cloture du compte a rebours (Taches 10 a 12)
]]

require "DamoclesMissionDef"

DamoclesMissionDB = DamoclesMissionDB or {}
DamoclesMissionDB.catalog = {}

local function reg(data)
    local m = DamoclesMissionDef.new(data)
    DamoclesMissionDB.catalog[m.id] = m
end

------------------------------------------------------------------------
-- PHASE 0 -- DEPLOIEMENT INITIAL & TETE DE PONT
------------------------------------------------------------------------

reg({
    id              = "hq_claim",
    phase           = 0,
    order           = 1,
    category        = "HQ",
    title           = "ETABLIR LA TETE DE PONT (POINT D'INSERTION)",
    description     = "Revendiquez un batiment comme refuge securise. Ce lieu deviendra le Point d'Insertion et le QG de l'Operation IRIS.",
    type            = "SAFEHOUSE_CLAIM",
    targetCount     = 1,
    unit            = "QG",
    status          = "ACTIVE",
    minResearch     = 0,
    researchGain    = 0,
    eventOnComplete = "DamoclesHQClaimed",
})

reg({
    id              = "hq_radio",
    phase           = 0,
    order           = 2,
    category        = "HQ",
    title           = "INSTALLER LE TERMINAL RADIO",
    description     = "Posez le terminal radio d'etat-major ALPHA-01 sur une table ou un bureau a l'interieur du QG.",
    type            = "PLACE_OBJECT_SURFACE",
    targetItem      = "Radio.HamRadio2",
    targetCount     = 1,
    unit            = "Terminal",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "hq_claim" },
    researchGain    = 5,
    eventOnComplete = "DamoclesRadioInstalled",
})

reg({
    id              = "contact_central_1",
    phase           = 0,
    order           = 3,
    category        = "RADIO",
    title           = "SITREP CENTRAL // OUVERTURE LIAISON",
    description     = "Approchez-vous du terminal radio dans le QG et etablissez le contact initial avec le Commandement Central.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "hq_radio" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Nous recevons votre signal 5 sur 5.",
        "Insertion sous couverture civile confirmee sans incident sur zone.",
        "SITREP : Avant d'entamer les protocoles scientifiques, votre base doit acquerir une autonomie logistique immediate.",
        "Directive prioritaire : rassemblez au moins 20 boites de conserves et 4 contenants d'eau ou boissons de reserve pour parer a la coupure d'aqueduc. A vous.",
    },
})

-- Mission Preparatoire 1 : Ravitaillement de vivres et eau
reg({
    id              = "prep_food",
    phase           = 0,
    order           = 4,
    category        = "LOGISTICS",
    title           = "PREPARATION QG : RAVITAILLEMENT & EAU",
    description     = "Stockez au moins 20 vivres ou conserves non-perissables et 4 reserves d'eau/boissons dans les conteneurs du QG.",
    type            = "GATHER_FOOD",
    targetCount     = 24,
    targetFood      = 20,
    targetWater     = 4,
    unit            = "Ressources",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "contact_central_1" },
    researchGain    = 3,
})

reg({
    id              = "contact_central_food",
    phase           = 0,
    order           = 5,
    category        = "RADIO",
    title           = "SITREP CENTRAL // COMPTE RENDU VIVRES & EAU",
    description     = "Transmettez votre Compte Rendu (CR) de ravitaillement au terminal radio.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "prep_food" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. CR de ravitaillement bien recu.",
        "Autonomie alimentaire et reserves hydriques de la base confirmees.",
        "SITREP : Prochaine directive prioritaire, mobilite tactique.",
        "Trouvez et prenez le controle d'un vehicule motorise fonctionnel pour vos deplacements et evacuations. A vous.",
    },
})

-- Mission Preparatoire 2 : Mobilite Tactique
reg({
    id              = "prep_vehicle",
    phase           = 0,
    order           = 6,
    category        = "LOGISTICS",
    title           = "PREPARATION QG : MOBILITE TACTIQUE",
    description     = "Securisez un vehicule : 1. Demarrer le moteur / 2. Niveau de carburant min. (3L) / 3. Rapatrier a proximite du QG.",
    type            = "SECURE_VEHICLE",
    targetCount     = 3,
    unit            = "Etapes",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "contact_central_food" },
    researchGain    = 4,
    objectives      = {
        "Demarrer le moteur du vehicule",
        "Assurer un niveau de carburant suffisant (min. 3L)",
        "Rapprocher et stationner le vehicule pres du QG",
    },
})

reg({
    id              = "contact_central_vehicle",
    phase           = 0,
    order           = 7,
    category        = "RADIO",
    title           = "SITREP CENTRAL // COMPTE RENDU MOBILITE",
    description     = "Transmettez votre Compte Rendu (CR) d'acquisition vehicule au terminal radio.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "prep_vehicle" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. CR mobilite bien recu et valide.",
        "Vecteur de transport motorise enregistre.",
        "SITREP : Traitement numerique des donnees de terrain.",
        "Recuperez un poste informatique de bureau et installez-le sur une table de votre QG pour liaison reseau. A vous.",
    },
})

-- Mission Preparatoire 3 : Poste Informatique & Reseau IRIS
reg({
    id              = "prep_computer",
    phase           = 0,
    order           = 8,
    category        = "LOGISTICS",
    title           = "PREPARATION QG : POSTE INFORMATIQUE",
    description     = "Recuperez un ordinateur de bureau (Desktop Computer) et installez-le sur une table dans le QG pour le traitement des donnees.",
    type            = "INSTALL_COMPUTER",
    targetItem      = "Base.Mov_DesktopComputer",
    targetCount     = 1,
    unit            = "Poste Info",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "contact_central_vehicle" },
    researchGain    = 4,
})

reg({
    id              = "contact_central_computer",
    phase           = 0,
    order           = 9,
    category        = "RADIO",
    title           = "SITREP CENTRAL // LIAISON SERVEUR",
    description     = "Confirmez le raccordement du poste informatique au terminal radio.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "prep_computer" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Liaison numerique et serveur IRIS operationnels. Vos telemetries sont synchronisees.",
        "SITREP : Derniere etape logistique avant les protocoles scientifiques.",
        "Nos centrifugeuses et equipements virologiques exigent du courant continu autonome.",
        "Directive : Acheminez au QG un groupe electrogene et au moins un jerrican de carburant plein. A vous.",
    },
})

-- Mission Preparatoire 4 : Approvisionnement Energetique
reg({
    id              = "prep_generator",
    phase           = 0,
    order           = 10,
    category        = "LOGISTICS",
    title           = "PREPARATION QG : APPROVISIONNEMENT ENERGETIQUE",
    description     = "Trouvez un groupe electrogene et un jerrican d'essence pour preparer l'alimentation du laboratoire.",
    type            = "FIND_GENERATOR_FUEL",
    targetCount     = 1,
    unit            = "Equipement",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "contact_central_computer" },
    researchGain    = 4,
})

reg({
    id              = "contact_central_generator",
    phase           = 0,
    order           = 11,
    category        = "RADIO",
    title           = "SITREP CENTRAL // COMPTE RENDU ENERGETIQUE",
    description     = "Notifiez le Central de la securisation du groupe electrogene et du carburant.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "prep_generator" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. CR logistique approuve.",
        "SITREP : Votre base repond desormais a l'ensemble des criteres d'un QG autonome de niveau 1.",
        "Nous declenchons la Phase 1. Tache 1 : Mise en conformite de la zone sterile.",
        "Evacuez tous les cadavres du batiment et barricadez les acces. A vous.",
    },
})

------------------------------------------------------------------------
-- PHASE 1 -- ETABLISSEMENT DE LA BASE & PROTOCOLES D'URGENCE
------------------------------------------------------------------------

-- Tache 1 : Mise en conformite de la zone sterile
reg({
    id              = "task_1_sterile",
    phase           = 1,
    order           = 12,
    category        = "HQ",
    title           = "TACHE 1 : MISE EN CONFORMITE DE LA ZONE STERILE",
    description     = "Evacuez tous les cadavres du batiment du QG et barricadez les acces principaux (portes ou fenetres).",
    type            = "HQ_CLEAN_BARRICADE",
    targetCount     = 1,
    unit            = "Securisation",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "contact_central_generator" },
    researchGain    = 5,
})

reg({
    id              = "contact_central_2",
    phase           = 1,
    order           = 13,
    category        = "RADIO",
    title           = "SITREP CENTRAL // COMPTE RENDU ZONE STERILE",
    description     = "Faites votre rapport de securisation au terminal radio.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "task_1_sterile" },
    researchGain    = 3,
    radioTransmission = {
        "Ici Central a Unite ALPHA. CR de sterilisation recu et approuve.",
        "SITREP : L'equipe civile du Dr Evans tentait de cartographier la souche avant rupture du signal.",
        "Ses travaux sont consignes dans le Dossier Vol. 1. Fouillez les structures medicales.",
        "Recuperez le document et revetez une protection biologique. A vous.",
    },
})

-- Tache 2 : Operation "Blackout" - Recuperation Protocole 01
reg({
    id              = "task_2_blackout",
    phase           = 1,
    order           = 14,
    category        = "INTEL",
    title           = "TACHE 2 : OPERATION BLACKOUT - DOSSIER VOL. 1",
    description     = "Trouvez le Dossier Evans Vol. 1 et equipez-vous d'une protection respiratoire ou d'une combinaison Hazmat.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "Damocles.Damocles_Doc_Vol1" },
    spawnTarget     = { item = "Damocles.Damocles_Doc_Vol1", outfit = "Doctor" },
    targetCount     = 1,
    unit            = "Protocole",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "contact_central_2" },
    researchGain    = 8,
    unlocksRecipe   = "Damocles.BasicSterilization",
})

reg({
    id              = "contact_central_3",
    phase           = 1,
    order           = 15,
    category        = "RADIO",
    title           = "SITREP CENTRAL // TRANSMISSION PROTOCOLE 01",
    description     = "Transmettez les donnees du Dossier Evans au Central depuis votre terminal.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "task_2_blackout" },
    researchGain    = 3,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Telemetrie du Dossier Evans bien transmise.",
        "SITREP : L'analyse avancee requiert un laboratoire sous tension permanente.",
        "Installez la station d'analyse dans le QG et raccordez le groupe electrogene operationnel. A vous.",
    },
})

-- Tache 3 : Deploiement de la station d'analyse
reg({
    id              = "task_3_lab_station",
    phase           = 1,
    order           = 16,
    category        = "HQ",
    title           = "TACHE 3 : DEPLOIEMENT DE LA STATION D'ANALYSE",
    description     = "Installez le materiel de laboratoire dans le QG et alimentez la zone avec un generateur connecte et charge.",
    type            = "HQ_FURNITURE_POWER",
    targetCount     = 1,
    unit            = "Laboratoire",
    status          = "LOCKED",
    minResearch     = 0,
    prereqMissions  = { "contact_central_3" },
    researchGain    = 9,
    eventOnComplete = "DamoclesLabReady",
})

------------------------------------------------------------------------
-- PHASE 2 -- DONNEES VIROLOGIQUES & ECHANTILLONNAGE PRIMAIRE
------------------------------------------------------------------------

reg({
    id              = "contact_central_4",
    phase           = 2,
    order           = 17,
    category        = "RADIO",
    title           = "SITREP CENTRAL // DIRECTIVE PRELEVEMENTS",
    description     = "Contactez le Central pour recevoir l'ordre de collecte biologique.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 25,
    prereqMissions  = { "task_3_lab_station" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Station d'analyse active et connectee.",
        "SITREP : Les protocoles virologiques requierent des tissus non necrotiques.",
        "Neutralisez des specimens recents et effectuez des prelevements sanguins a la seringue sterile.",
        "Rapportez au moins 3 fioles viables. A vous.",
    },
})

-- Tache 4 : Collecte de matiere biologique fraiche
reg({
    id              = "task_4_fresh_blood",
    phase           = 2,
    order           = 18,
    category        = "VACCINE",
    title           = "TACHE 4 : COLLECTE DE SANG INFECTE FRAIS",
    description     = "Prelevez au moins 3 fioles de sang infecte viable sur des infectes recents et gardez-les sur vous ou au QG.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "ZombieVaccine.BloodSample" },
    targetCount     = 3,
    unit            = "Fioles Sang",
    status          = "LOCKED",
    minResearch     = 25,
    prereqMissions  = { "contact_central_4" },
    researchGain    = 8,
})

reg({
    id              = "contact_central_5",
    phase           = 2,
    order           = 19,
    category        = "RADIO",
    title           = "SITREP CENTRAL // COMPTE RENDU ECHANTILLONS",
    description     = "Notifiez le Central de la reussite des prelevements sanguins.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 25,
    prereqMissions  = { "task_4_fresh_blood" },
    researchGain    = 3,
    radioTransmission = {
        "Ici Central a Unite ALPHA. CR echantillons valide. Tissus viables enregistres.",
        "SITREP : L'equipe biologique avait isole le profil genetique avant dispersion.",
        "Infiltrez leur avant-poste, extrayez le Dossier Archimede Vol. 2 et appliquez les equations. A vous.",
    },
})

-- Tache 5 : Operation "Archimede" - Recuperation Dossier Virologie Vol. 2
reg({
    id              = "task_5_archimedes",
    phase           = 2,
    order           = 20,
    category        = "INTEL",
    title           = "TACHE 5 : OPERATION ARCHIMEDE - DOSSIER VOL. 2",
    description     = "Infiltrez l'avant-poste de l'equipe biologique et extrayez le Dossier Archimede Vol. 2.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "Damocles.Damocles_Doc_Vol2" },
    spawnTarget     = { item = "Damocles.Damocles_Doc_Vol2", outfit = "Scientist" },
    targetCount     = 1,
    unit            = "Dossier",
    status          = "LOCKED",
    minResearch     = 25,
    prereqMissions  = { "contact_central_5" },
    researchGain    = 9,
    unlocksRecipe   = "Damocles.CentrifugeEquations",
})

reg({
    id              = "contact_central_6",
    phase           = 2,
    order           = 21,
    category        = "RADIO",
    title           = "SITREP CENTRAL // ACTIVATION CENTRIFUGATION",
    description     = "Contactez le Central pour synchroniser les parametres de centrifugation.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 25,
    prereqMissions  = { "task_5_archimedes" },
    researchGain    = 3,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Equations et reglages de centrifugation telecharges.",
        "SITREP : Analysez la structure sous microscope puis activez la centrifugeuse.",
        "Isolez la fiole de souche concentree purifiee. A vous.",
    },
})

-- Tache 6 : Analyse microscopique & Separation plasmique
reg({
    id              = "task_6_plasmic_sep",
    phase           = 2,
    order           = 22,
    category        = "VACCINE",
    title           = "TACHE 6 : ISOLEMENT DE LA SOUCHE CONCENTREE",
    description     = "Passez le sang a la centrifugeuse de laboratoire pour obtenir une fiole de virus concentre purifie.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "ZombieVaccine.ConcentratedStrain" },
    targetCount     = 1,
    unit            = "Souche Concentree",
    status          = "LOCKED",
    minResearch     = 25,
    prereqMissions  = { "contact_central_6" },
    researchGain    = 10,
})

------------------------------------------------------------------------
-- PHASE 3 -- CULTURE CELLULAIRE & ATTENUATION DU VIRUS
------------------------------------------------------------------------

reg({
    id              = "contact_central_7",
    phase           = 3,
    order           = 23,
    category        = "RADIO",
    title           = "SITREP CENTRAL // PROTOCOLE DE CULTURE",
    description     = "Rapportez l'isolement de la souche et demandez les autorisations de culture.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 50,
    prereqMissions  = { "task_6_plasmic_sep" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Souche concentree en securite.",
        "SITREP : Nous entrons dans la phase critique d'attenuation.",
        "Recuperez les travaux du Pr Miller dans son laboratoire secondaire (Dossier Vol. 3) et ses reactifs. A vous.",
    },
})

-- Tache 7 : Operation "Promethee" - Protocoles de Culture Vol. 3
reg({
    id              = "task_7_prometheus",
    phase           = 3,
    order           = 24,
    category        = "INTEL",
    title           = "TACHE 7 : OPERATION PROMETHEE - DOSSIER VOL. 3",
    description     = "Trouvez le Dossier Miller Vol. 3 et les reactifs chimiques necessaires a la culture cellulaire.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "Damocles.Damocles_Doc_Vol3" },
    spawnTarget     = { item = "Damocles.Damocles_Doc_Vol3", outfit = "Scientist" },
    targetCount     = 1,
    unit            = "Dossier & Reactifs",
    status          = "LOCKED",
    minResearch     = 50,
    prereqMissions  = { "contact_central_7" },
    researchGain    = 8,
    unlocksRecipe   = "Damocles.CultureMedium",
})

reg({
    id              = "contact_central_8",
    phase           = 3,
    order           = 25,
    category        = "RADIO",
    title           = "SITREP CENTRAL // LANCEMENT INCUBATION",
    description     = "Recevez les reglages thermiques de l'incubateur aupres du Central.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 50,
    prereqMissions  = { "task_7_prometheus" },
    researchGain    = 3,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Reactifs et protocoles de culture recus.",
        "SITREP : Preparez les boites de Petri selon les ratios Miller et amorcez l'incubateur.",
        "Maintenez les constantes thermiques jusqu'a replication complete. A vous.",
    },
})

-- Tache 8 : Multiplication & Incubation thermique
reg({
    id              = "task_8_incubation",
    phase           = 3,
    order           = 26,
    category        = "VACCINE",
    title           = "TACHE 8 : MULTIPLICATION VIRALE EN INCUBATEUR",
    description     = "Menez a terme la culture virale dans l'incubateur du QG pour developper une colonie virale active.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "ZombieVaccine.ActiveColony" },
    targetCount     = 1,
    unit            = "Colonie Active",
    status          = "LOCKED",
    minResearch     = 50,
    prereqMissions  = { "contact_central_8" },
    researchGain    = 10,
})

reg({
    id              = "contact_central_9",
    phase           = 3,
    order           = 27,
    category        = "RADIO",
    title           = "SITREP CENTRAL // INACTIVATION THERMIQUE",
    description     = "Contactez le Central des que la colonie virale a atteint sa pleine maturite.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 50,
    prereqMissions  = { "task_8_incubation" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Colonie virale mature detectee.",
        "SITREP : Engagez l'inactivation thermique et chimique preconisee par Miller.",
        "Neutralisez la virulence pour obtenir la souche attenuee. A vous.",
    },
})

-- Tache 9 : Inactivation & Synthese de la souche attenuee
reg({
    id              = "task_9_attenuation",
    phase           = 3,
    order           = 28,
    category        = "VACCINE",
    title           = "TACHE 9 : INACTIVATION DE LA SOUCHE (ATTENUATION)",
    description     = "Appliquez le choc thermique et les desinfectants pour creer une fiole de souche virale attenuee.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "ZombieVaccine.AttenuatedStrain" },
    targetCount     = 1,
    unit            = "Souche Attenuee",
    status          = "LOCKED",
    minResearch     = 50,
    prereqMissions  = { "contact_central_9" },
    researchGain    = 10,
})

------------------------------------------------------------------------
-- PHASE 4 -- LE VACCIN DAMOCLES & CLOTURE DU COMPTE A REBOURS
------------------------------------------------------------------------

reg({
    id              = "contact_central_10",
    phase           = 4,
    order           = 29,
    category        = "RADIO",
    title           = "SITREP CENTRAL // CRASH COURRIER TACTIQUE",
    description     = "Recevez les coordonnees du crash aerien du courrier militaire portant la formule finale.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 75,
    prereqMissions  = { "task_9_attenuation" },
    researchGain    = 2,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Souche attenuee confirmee. Etape decisive.",
        "SITREP : Radar signale le crash d'un transporteur tactique militaire en secteur boise.",
        "Le courrier transportait le Dossier Lazare Vol. 4 (Stabilisation & Adjuvants).",
        "Securisez l'epave et recuperez la formule finale. A vous.",
    },
})

-- Tache 10 : Operation "Lazare" - Recuperation Formule de Stabilisation Vol. 4
reg({
    id              = "task_10_lazarus",
    phase           = 4,
    order           = 30,
    category        = "INTEL",
    title           = "TACHE 10 : OPERATION LAZARE - DOSSIER FINAL VOL. 4",
    description     = "Localisez le site du crash militaire et rapportez le Dossier Lazare Vol. 4 contenant les adjuvants stabilisateurs.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "Damocles.Damocles_Doc_Vol4" },
    spawnTarget     = { item = "Damocles.Damocles_Doc_Vol4", outfit = "ArmyCamoDesert" },
    targetCount     = 1,
    unit            = "Formule Finale",
    status          = "LOCKED",
    minResearch     = 75,
    prereqMissions  = { "contact_central_10" },
    researchGain    = 10,
    unlocksRecipe   = "Damocles.FinalVaccineFormula",
})

reg({
    id              = "contact_central_11",
    phase           = 4,
    order           = 31,
    category        = "RADIO",
    title           = "SITREP CENTRAL // AUTORISATION DE SYNTHESE",
    description     = "Confirmez au Central la possession de tous les composants du vaccin.",
    type            = "RADIO_CONTACT",
    targetCount     = 1,
    unit            = "Transmission",
    status          = "LOCKED",
    minResearch     = 75,
    prereqMissions  = { "task_10_lazarus" },
    researchGain    = 3,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Formule finale Lazare bien chargee.",
        "SITREP : Tous les composants du vaccin sont sous votre controle.",
        "Directive : Assemblez la souche attenuee et les adjuvants sous vide au laboratoire du QG. A vous.",
    },
})

-- Tache 11 : Synthese du Vaccin Damocles
reg({
    id              = "task_11_vaccine_synth",
    phase           = 4,
    order           = 32,
    category        = "VACCINE",
    title           = "TACHE 11 : SYNTHESE DU VACCIN DAMOCLES",
    description     = "Assemblez la souche attenuee et les adjuvants dans le laboratoire du QG pour creer la fiole de vaccin definitive.",
    type            = "HOLD_ITEMS",
    requiredItems   = { "Damocles.Damocles_Vaccine_Vial" },
    targetCount     = 1,
    unit            = "Vaccin Fiole",
    status          = "LOCKED",
    minResearch     = 75,
    prereqMissions  = { "contact_central_11" },
    researchGain    = 15,
})

-- Tache 12 : Transmission de la cle cryptographique & Annulation du tir
reg({
    id              = "contact_central_12",
    phase           = 4,
    order           = 33,
    category        = "RADIO",
    title           = "TACHE 12 : CLE CRYPTOGRAPHIQUE & EXTRACTION",
    description     = "Utilisez le terminal radio avec le vaccin dans votre inventaire pour transmettre la cle d'annulation orbitale.",
    type            = "RADIO_CRYPTO_FINAL",
    targetCount     = 1,
    unit            = "Code Annulation",
    status          = "LOCKED",
    minResearch     = 75,
    prereqMissions  = { "task_11_vaccine_synth" },
    researchGain    = 25,
    radioTransmission = {
        "Ici Central a Unite ALPHA. Vaccin confirme par spectroscopie et telemetrie !",
        "Transmettez sans attendre la cle cryptographique d'arret du tir orbital Damocles.",
        "SITREP D'EXTRACTION : Ordre de frappe annule ! Vecteur aerien deployee vers votre Point d'Extraction.",
        "Rejoignez la zone d'evacuation. Mission accomplie, Unite ALPHA. Termine !",
    },
    eventOnComplete = "DamoclesMissionComplete",
})

------------------------------------------------------------------------
-- Accesseurs ordonnes
------------------------------------------------------------------------

--- Retourne toutes les missions dans l'ordre chronologique strict (order puis phase -> id)
--- @return table Liste ordonnee des missions
function DamoclesMissionDB.getAll()
    local list = {}
    for _, m in pairs(DamoclesMissionDB.catalog) do
        table.insert(list, m)
    end
    table.sort(list, function(a, b)
        local ordA = a.order or 0
        local ordB = b.order or 0
        if ordA ~= ordB then return ordA < ordB end
        if a.phase ~= b.phase then return a.phase < b.phase end
        return a.id < b.id
    end)
    return list
end

--- Retourne une mission par ID
--- @param id string
--- @return table|nil
function DamoclesMissionDB.getById(id)
    return DamoclesMissionDB.catalog[id]
end
