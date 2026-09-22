# Projet Damocles — Documentation Technique & Guide du Mod

> **Compatibilite :** Project Zomboid **Build 41** et **Build 42** (Structure hybride native)  
> **Identifiant Mod :** `ProjetDamocles`  
> **Derniere mise a jour :** Septembre 2026

---

## 1. Vue d'Ensemble & Lore

Le **Projet Damocles** introduit une course contre la montre scenarisee dans Project Zomboid :
- **L'Epee de Damocles :** Un compte a rebours inalterable base sur le temps virtuel du monde (7 jours in-game par defaut = 168 heures de jeu). Si le temps s'ecoule avant d'avoir developpe le vaccin, l'operation Damocles s'abat sur le secteur d'operation (frappe d'eradication orbitale).
- **Le Reseau IRIS & Unité ALPHA :** L'operation s'adresse a l'**Unite ALPHA** (appellation neutre s'adaptant aussi bien a un joueur solo qu'a un groupe en multijoueur).
- **Infiltration sous Couverture Civile :** L'Unite ALPHA est infiltree en tenue civile afin de ne pas attirer l'attention du public ni declencher de panique de masse (expliquant egalement l'absence initiale d'un contingent militaire lourd).
- **Profession Exclusive "Operateur IRIS" :** Profil militaire tactique (insensible a la panique). L'operateur conserve sa tenue civile sur lui au depart et transporte son paquetage tactique complet (rangers, treillis, gilet pare-balles, beret, terminal radio lourd et jerrican) dans son inventaire. **Seul l'Operateur IRIS detient les accreditations de securite pour etablir le QG.**
- **Terminal Radio d'Etat-Major (`Radio.HamRadio2`) :** Le relais de communication officiel avec micro deporte. **Doit etre pose sur une surface surelevee (table, bureau ou comptoir) a l'interieur du QG.** Une fois installe, le terminal est verrouille (anti-vol / anti-demontage) pour garantir la continuite de la liaison.
- **Boucle Interactive « Contacter le Central » :**
  $$\text{MISSION} \longrightarrow \text{ACCOMPLISSEMENT} \longrightarrow \text{CONTACTER LE CENTRAL} \longrightarrow \text{NOUVELLE MISSION}$$
  Chaque nouvelle directive ou validation necessite d'interagir au terminal radio. Les transmissions du Commandement s'affichent sous forme de bulles de dialogue radio au-dessus du terminal.
- **Missions Preparatoires du QG :** Avant d'attaquer la virologie pure, l'Unite ALPHA doit securiser la base :
  1. *Ravitaillement de vivres* : rassembler 5 boites de conserves/rations durables.
  2. *Mobilite tactique* : trouver et securiser un vehicule motorise fonctionnel.
  3. *Approvisionnement energetique* : obtenir un groupe electrogene et du carburant.
- **La Trame Narrative en 12 Taches (Phases 1 a 4) :** Un scenario complet allant de la securisation sterile du QG et du laboratoire jusqu'a l'inactivation virale, la synthese du vaccin, l'extraction finale par helicoptere et l'annulation du tir orbital.
- **Generation Dynamique des Quetes :** Les dossiers de recherche (`Damocles_Doc_Vol1` a `Vol4`) sont automatiquement generes dans un conteneur medical/bureau du secteur ou portes par un zombie special des que la radio transmet l'ordre de mission.
- **Code 100% ASCII & Localisation Officielle :** Aucun caractere special direct dans le Lua afin d'eviter les corruptions de polices bitmap PZ, relie a `UI_FR.txt` et `UI_EN.txt`.


---

## 2. Arborescence du Projet & Dualite B41 / B42

```
mods/ProjetDamocles/
├── mod.info                                 # Metadonnees B41 (versionMin=41.0.0)
├── poster.png                               # Affiche officielle du mod (menu PZ)
├── README.md                                # Ce guide de reference
├── 42/                                      # Repertoire dedie Build 42 (prioritaire en B42)
│   ├── mod.info                             # Metadonnees B42 (versionMin=42.0.0)
│   ├── poster.png
│   ├── README.md
│   └── media/                               # Miroir synchronise 1:1 de media/
└── media/
    ├── scripts/
    │   └── damocles_items.txt               # Definitions des dossiers Vol. 1-4 et fiole vaccin
    ├── ui/
    │   └── Profession_iris_operator.png     # Icone officielle du metier Operateur IRIS
    ├── textures/Damocles/                   # Assets graphiques d'interface (PNG)
    │   ├── logo_iris.png                    # Logo officiel IRIS (64x64)
    │   ├── hud_iris_btn.png                 # Bouton flottant du HUD (48x48)
    │   ├── icon_gear.png                    # Icone operateur / logistique (24x24)
    │   ├── icon_fuel.png                    # Icone mission carburant (32x32)
    │   ├── icon_mic.png                     # Icone mission radio/dossier (32x32)
    │   ├── icon_vial.png                    # Icone mission sang/echantillons (32x32)
    │   ├── icon_warning.png                 # Alerte de menace QG (32x32)
    │   └── icon_radiation.png               # Alerte compte a rebours Damocles (32x32)
    └── lua/
        ├── shared/                          # Code commun (Client & Serveur & Solo)
        │   ├── Translate/
        │   │   ├── FR/UI_FR.txt             # Dictionnaire de traduction Francais
        │   │   └── EN/UI_EN.txt             # Dictionnaire de traduction Anglais
        │   ├── NPCs/
        │   │   └── DamoclesProfessions.lua  # Metier Operateur IRIS + HamRadio2 starter
        │   ├── DamoclesGameTime.lua         # Gestion du temps mondial PZ & compte a rebours
        │   ├── DamoclesMissionDef.lua       # Modele Mission (support RADIO_CONTACT, HOLD_ITEMS, etc.)
        │   ├── DamoclesMissionDB.lua        # Scenario complet en 12 taches + transmissions radio
        │   ├── DamoclesMissionManager.lua   # Moteur logique, gestionnaire terminal sur table, QG
        │   └── DamoclesMockData.lua         # Donnees factices pour tests UI isoles
        ├── client/                          # Code cote Client
        │   ├── Actions/
        │   │   └── DamoclesRadioContactAction.lua # Action temporisee de contact radio & dialogue
        │   ├── DamoclesClientMain.lua       # Point d'entree UI, feedback sonore/halo, synchro state
        │   ├── DamoclesContextMenu.lua      # Clic droit QG + Clic droit terminal radio + lock
        │   └── UI/
        │       ├── DamoclesIntroWindow.lua  # Fenetre de briefing operationnel initial
        │       ├── DamoclesHUDButton.lua    # Bouton flottant HUD (draggable + alerte clignotante)
        │       ├── DamoclesMainWindow.lua   # Console IRIS principale (Pin, Auto-hide, Archives)
        │       ├── DamoclesProgressBar.lua  # Barre de progression segmentee neon
        │       ├── DamoclesHQWindow.lua     # Console secondaire dediee au statut du QG IRIS
        │       └── DamoclesHistoryWindow.lua # Registre d'archives des missions accomplies
        └── server/                          # Code cote Serveur / Solo
            └── DamoclesServerHooks.lua      # Hooks PZ, verification pose sur table, spawns quetes
```

---

## 3. Le Scenario Narratif en 12 Taches

| Phase | Etape | Titre de la Tache | Type d'Action & Condition | Lore & Transmission du Central |
| :---: | :---: | :--- | :--- | :--- |
| **0** | **1** | **Etablir la tete de pont** | Revendication batiment (Clic droit Operateur IRIS) | *Fondation du QG clandestin.* |
| **0** | **2** | **Installer le terminal radio** | Pose de `Radio.HamRadio2` sur une **table/bureau** dans le QG | *Deploiement de la station d'etat-major US ARMY COMM.* |
| **0** | **3** | **Consulter le Central (Liaison)** | Action clic droit sur le terminal | *« Agent, nous recevons vos coordonnees. Nettoyez et securisez la zone de confinement : aucun cadavre, barricadez les acces. »* |
| **1** | **4** | **Tache 1 : Mise en conformite sterile** | 0 cadavre dans le QG + fenetres/portes barricadees | *Assainissement de l'environnement de travail.* |
| **1** | **5** | **Consulter le Central (Rapport 1)** | Action au terminal radio | *« Zone sterile confirmee. Recuperation du dossier Dr Evans ordonnee. »* |
| **1** | **6** | **Tache 2 : Operation Blackout** | Inventaire : `Damocles_Doc_Vol1` + Masque/Tenue Hazmat | *Notes preliminaires du Dr Evans retrouvees dans une structure medicale.* |
| **1** | **7** | **Consulter le Central (Rapport 2)** | Action au terminal radio | *« Dossier 01 integre. Deploiement du laboratoire d'analyse requis. »* |
| **1** | **8** | **Tache 3 : Deploiement station analyse** | Etabli/labo dans le QG + Generateur connecte avec essence | *Mise sous tension des equipements de virologie.* |
| **2** | **9** | **Consulter le Central (Rapport 3)** | Action au terminal radio | *« Laboratoire en ligne. Prelevez des tissus biologiques non necroser. »* |
| **2** | **10** | **Tache 4 : Collecte sang frais** | 3 fioles de sang infecte viables en inventaire | *Echantillonnage primaire a la seringue sterile.* |
| **2** | **11** | **Consulter le Central (Rapport 4)** | Action au terminal radio | *« Echantillons recus. Extraction du Dossier Archimede Vol. 2 requise. »* |
| **2** | **12** | **Tache 5 : Operation Archimede** | Inventaire : `Damocles_Doc_Vol2` | *Equations de centrifugation et sequencage ARN de l'avant-poste.* |
| **2** | **13** | **Consulter le Central (Rapport 5)** | Action au terminal radio | *« Parametres recus. Lancez l'analyse et la separation plasmique. »* |
| **2** | **14** | **Tache 6 : Isolement souche concentree** | Possession d'une fiole de virus concentre purifie | *Separation plasmique a la centrifugeuse.* |
| **3** | **15** | **Consulter le Central (Rapport 6)** | Action au terminal radio | *« Souche concentree isolee. Recuperez les travaux du Pr Miller (Vol. 3). »* |
| **3** | **16** | **Tache 7 : Operation Promethee** | Inventaire : `Damocles_Doc_Vol3` + reactifs chimiques | *Formules d'incubation et reactifs du labo secondaire.* |
| **3** | **17** | **Consulter le Central (Rapport 7)** | Action au terminal radio | *« Reactifs prets. Ensemencez les boites de culture et demarrez l'incubateur. »* |
| **3** | **18** | **Tache 8 : Multiplication virale** | Colonie virale active obtenue dans l'incubateur | *Replication thermique controlee.* |
| **3** | **19** | **Consulter le Central (Rapport 8)** | Action au terminal radio | *« Colonie mature. Appliquez le choc thermique et l'agent attenuateur. »* |
| **3** | **20** | **Tache 9 : Inactivation de la souche** | Possession d'une fiole de souche virale attenuee | *Neutralisation de la pathogenicite sans detruire l'antigene.* |
| **4** | **21** | **Consulter le Central (Rapport 9)** | Action au terminal radio | *« Souche attenuee validee. Securisez le crash du courrier militaire (Vol. 4). »* |
| **4** | **22** | **Tache 10 : Operation Lazare** | Inventaire : `Damocles_Doc_Vol4` (Crash militaire) | *Formule finale de stabilisation et adjuvants pour ampoule injectable.* |
| **4** | **23** | **Consulter le Central (Rapport 10)** | Action au terminal radio | *« Autorisation de synthese finale accordee. Conditionnez le vaccin sous vide. »* |
| **4** | **24** | **Tache 11 : Synthese Vaccin Damocles** | Possession de `Damocles_Vaccine_Vial` | *Le vaccin definitif est enfin cree.* |
| **4** | **25** | **Tache 12 : Cle crypto & Extraction** | Transmission au terminal avec le vaccin en inventaire | *Arret immediat du compte a rebours des 7 jours, victoire et helicoptere d'extraction.* |

---

## 4. Fonctionnement du Relais de Communication

### 4.1. Pose Exclusive sur Meuble & Securisation
- Le terminal radio `Radio.HamRadio2` doit imperativement etre depose sur une table, un bureau ou un comptoir situe dans le batiment du QG.
- Si le joueur tente de le poser a meme le sol, la mission n'est pas validee et un message d'alerte s'affiche : `[!] Le terminal radio doit etre pose sur une table ou un meuble !`.
- Des que le terminal est valide sur un meuble dans le QG :
  - L'objet est tague `isDamoclesTerminal = true`.
  - Les options de ramassage (`Prendre`, `Grab`, `Take`) et de demontage (`Demonter`, `Disassemble`) sont retirees du menu contextuel.
  - Le module de deplacement de meuble (`ISMoveableSpriteProps`) empeche categoriquement sa prise en inventaire.

### 4.2. Action "Contacter le Commandement Central"
- En faisant un clic droit sur le terminal : option **`[IRIS] Contacter le Commandement Central`**.
- Le survivant s'approche du terminal, un son d'ouverture radio retentit.
- La replique officielle du Central s'affiche sous forme de texte radio au-dessus du terminal (`radioObj:addLineChatElement(...)`).
- A la fin de l'action (~3 secondes), le contact est valide, l'objectif s'actualise dans la console HUD, et la mission suivante s'active automatiquement.

---

## 5. Guide de Test Pas-a-Pas en Solo

1. Lancer **Project Zomboid** (Build 41 ou 42).
2. Dans **Mods**, activer **Projet Damocles**.
3. Creer une partie Solo avec le metier **Operateur IRIS** :
   - Observer que le personnage est en **tenue civile** et que son **paquetage militaire complet** (rangers, treillis, gilet pare-balles, beret), le terminal **`Radio.HamRadio2`**, le jerrican d'essence et les bandages sont dans l'inventaire.
   - Constater l'ouverture du **Briefing Tactique IRIS**, mentionnant l'**Unite ALPHA** et la couverture civile. Cliquer sur **`ACCEPTER LA MISSION & DEPLOYER L'UNITE`**.
4. Trouver un batiment convenable et faire un clic droit au sol : selectionner **`[IRIS] Etablir le QG de l'Operation ici`**.
   - Le QG est etabli (son `LevelUp` et texte vert flottant).
5. Poser le terminal radio sur le sol nu : verifier que la mission n'est pas validee et que le personnage refuse l'emplacement avec avertissement.
6. Poser le terminal radio sur une **table ou un bureau** dans le QG :
   - La mission `INSTALLER LE TERMINAL RADIO` se valide.
   - Le terminal est desormais fixe et inamovible.
7. Faire un clic droit sur le terminal radio : selectionner **`[IRIS] Contacter le Commandement Central`** :
   - Observer l'animation, le son radio et la transmission du Central au-dessus du terminal ordonnant le ravitaillement de la base.
8. **Missions Preparatoires du QG** :
   - *Ravitaillement* : Reunir 5 boites de conserves (inventaire ou conteneurs du QG) $\rightarrow$ faire le rapport au terminal.
   - *Mobilite* : Monter a bord ou approcher un vehicule motorise fonctionnel $\rightarrow$ faire le rapport au terminal.
   - *Energie* : Obtenir un groupe electrogene et un jerrican d'essence plein $\rightarrow$ faire le rapport au terminal.
9. **Lancement de la Phase 1** :
   - Le Central valide les fondations logistiques et ordonne la **Tache 1 : Mise en conformite de la zone sterile** (nettoyage des cadavres et pose de barricades), debloquant ensuite l'Operation Blackout (Dossier Vol. 1) !

---

## 6. Architecture Future : Modularite Multi-Metiers & Interactions Multijoueur

### 6.1. Scenarios Dedies par Metier (Systeme de Plugins)
La trame du **QG IRIS** et de la recherche du remede sera reservee au joueur ayant choisi la profession **Operateur IRIS**.
Les autres metiers disposeront de leurs propres lignes narratives, objectifs et interfaces via des modules plugins optionnels :
- **L'Officier de Police / Enqueteur** : Investigation sur les causes et l'origine de l'epidemie, collecte de preuves dans les commissariats et les centres gouvernementaux, recherche des premiers foyers d'infection.
- **Le Reporter / Journaliste** : Collecte d'enregistrements audio, de journaux intimes et de documents d'archives pour documenter la chute de la societe et diffuser la verite.
- **Le Cambrioleur / Hors-la-loi** : Objectif opportuniste centre sur l'accumulation de richesses (bijoux precieux, lingots, devises dans les coffres-forts) en vue d'une exfiltration clandestine de la zone avant l'eradication.
- **Le Medecin Civil / Urgentiste** : Mise en place d'un dispensaire de fortune, sauvetage de survivants et stabilisation des stocks pharmaceutiques critiques.

### 6.2. Embranchements et Confluences en Multijoueur
En session multijoueur, la rencontre entre des joueurs incarnant des metiers differents ouvrira des embranchements narratifs conditionnels :
- **Convergence vers le Remede** : Un policier, un reporter ou un medecin pourra choisir de rallier l'Operateur IRIS en lui apportant des composants virologiques ou des donnees de terrain en echange d'une extraction conjointe.
- **Dilemmes Relationnels (ex: Flic & Truand)** : Un officier de police pourra identifier un cambrioleur recherche et devoir choisir entre tenter de l'apprehender ou collaborer face a la menace zombie imminente.
- **Partage Dynamique de Renseignements** : Les decouvertes de chaque role enrichiront les autres voies narratives pour une immersion roleplay maximale.

