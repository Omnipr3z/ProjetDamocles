# Walkthrough : Projet Damoclès - Résolutions, Refactoring & Nouveaux Systèmes

Ce document synthétise l'ensemble des correctifs, améliorations de confort, refactorisations d'architecture et nouveaux systèmes intégrés à l'Opération Damoclès.

---

## 1. Synthèse des Systèmes & Correctifs

### A. Autonomie Alimentaire & Hydrique du QG (`prep_food`)
- **Deux jauges de progression distinctes dans l'interface IRIS** ([DamoclesMainWindow.lua](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/client/UI/DamoclesMainWindow.lua)) :
  - **Ligne 1 - Conserves alimentaires** : Jauge cyan dédiée avec décompte `Conserves : [X/20]`.
  - **Ligne 2 - Réserves d'eau et boissons** : Jauge verte dédiée avec décompte `Reserves Eau : [Y/4]`.
- **Détection universelle de toutes les boissons (Vanilla & Mods)** ([DamoclesMissionManager.lua](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/shared/DamoclesMissionManager.lua)) :
  - Reconnaissance automatique des sources d'eau actives (`it:isWaterSource()`, gourdes, marmites, seaux).
  - Reconnaissance automatique de tout consommable étanchant la soif (`it:getThirstChange() < -0.05`), garantissant une compatibilité totale avec les mods ajoutant des canettes de soda, bouteilles de jus, boissons énergisantes, etc.
  - Exclusion formelle des contenants vides.
- **Briefing radio adapté** ([DamoclesMissionDB.lua](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/shared/DamoclesMissionDB.lua)) :
  - Le Commandement Central avertit de l'imminence de la coupure des réseaux d'aqueduc et ordonne de sécuriser 20 conserves et 4 contenants d'eau de réserve.
  - La validation par transmission radio confirme l'autonomie nutritionnelle et hydrique de la base.

### B. Immutabilité Stricte du QG Établi
- **Protection anti-écrasement et verrouillage définitif** ([DamoclesMissionManager.lua](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/shared/DamoclesMissionManager.lua) & [DamoclesContextMenu.lua](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/client/DamoclesContextMenu.lua)) :
  - Dès qu'un bâtiment est revendiqué comme QG par un Agent IRIS, `DamoclesMissionManager.setHQBuilding()` verrouille définitivement l'emplacement. Toute tentative ultérieure de modification est formellement bloquée.
  - L'option de clic droit `[IRIS] Etablir le QG de l'Operation ici` disparaît à tout jamais pour l'ensemble des joueurs dès la revendication initiale.

### C. Gestion du Terminal Unique en Multijoueur & Sécurité Décès
- **Unicité absolue et déduplication** ([DamoclesProfessions.lua](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/shared/NPCs/DamoclesProfessions.lua)) :
  - Si le terminal est déjà installé au QG (`hq_radio` complétée ou `terminalLocation` défini) : **aucun nouvel agent ne reçoit de terminal radio** à son spawn.
  - Si le terminal n'est pas encore posé : le premier agent est enregistré comme `terminalCarrier`. Tout autre joueur rejoignant la partie ne reçoit pas de doublon tant que le porteur est actif.
- **Sécurité Décès / Purge Cadavre & Zombie** :
  - Sur l'événement `Events.OnPlayerDeath`, le terminal d'état-major `Radio.HamRadio2` est **immédiatement détruit de l'inventaire et des sacs du joueur** (`DoRemoveItem`).
  - Il ne reste ainsi jamais abandonné sur un cadavre en décomposition ni transporté par un zombie errant.
  - Le statut de porteur est libéré pour qu'un nouvel agent puisse prendre le relais.

### D. Balise Cartographique en Direct du Porteur (`DamoclesMapManager`)
- **Traçage tactique sur la carte du monde (`ISWorldMap`)** ([DamoclesMapManager.lua](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/client/DamoclesMapManager.lua)) :
  - Tant que le terminal n'a pas été posé sur une table du QG, une balise ambre dynamique `[IRIS] TERMINAL ALPHA // EN TRANSIT (NomDuJoueur)` s'affiche en temps réel sur la carte du monde à l'emplacement du porteur.
  - Dès la pose effective dans le bâtiment du QG, la balise de transit est automatiquement retirée au profit du repère fixe du QG (`[IRIS] POINT D'INSERTION // QG ALPHA`).

### E. Briefing Adaptatif en Multijoueur (`DamoclesIntroWindow`)
- **Adaptation selon l'état du monde** ([DamoclesIntroWindow.lua](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/client/UI/DamoclesIntroWindow.lua)) :
  - Si le QG a déjà été établi par des coéquipiers :
    - Titre : `TETE DE PONT ACTIVE // RALLIEMENT QG ALPHA`.
    - Message : Liste dynamique des opérateurs IRIS actuellement actifs sur le serveur (*« Opérateurs actifs sur zone : [Pseudos] »*).
    - Directive : Ordre de rejoindre immédiatement la tête de pont pour prêter main-forte.
    - Bouton principal : `REJOINDRE L'UNITÉ ALPHA SUR LE TERRAIN`.

### F. Mission Véhicule en 3 Étapes Réelles (`prep_vehicle`)
- **Suppression du bug d'auto-complétion** : Le hook immédiat sur `OnEnterVehicle` a été remplacé par une évaluation rigoureuse sur `OnExitVehicle` et à chaque minute.
- **3 étapes obligatoires simultanées** :
  1. *Étape 1* : Démarrage du moteur (`isEngineRunning()`).
  2. *Étape 2* : Carburant suffisant (`>= 3.0L` dans le réservoir).
  3. *Étape 3* : Rapatriement au QG (`<= 35 cases` du centre du QG).
- Affichage dynamique dans le HUD : `[ X / 3 Étapes ]`.

### G. Immersion Radio Réaliste (`DamoclesRadioContactAction`)
- Bruitages radio authentiques du moteur PZ (`RadioStatic`, `RadioTalk`, `RadioButton`).
- Délai initial de syntonisation (1.5s) avec mention `*Grésillement radio... Syntonisation de la fréquence sécurisée...*`.
- Accusé de réception teinté d'Alpha en vert émeraude tactique `(0.25, 1.0, 0.45)` :
  - `"[ALPHA] : Unité Alpha au Central, bien reçu. Terminé."`

### H. Icône de Carte du QG & Compatibilité Universelle
- Enregistrement du symbole `Damocles_HQ` dans `MapSymbolDefinitions` (logo IRIS) avec repli vanilla `"House"` (aucun damier bleu/noir).
- Briefing totalement neutre sans mention de Knox, assurant une immersion sans accroc sur Knox Country et Project France.

---

## 2. Validation Technique & Parité

| Composant | Statut | Résultat |
| :--- | :--- | :--- |
| **Parité `media/` <-> `42/media/`** | **100% Identique** | Synchronisation stricte de l'ensemble des fichiers via script miroir. |
| **Syntaxe Lua (Équilibrage)** | **20/20 Fichiers OK** | 0 balise déséquilibrée sur les 20 scripts dans les deux branches. |
| **Intégrité de l'Encodage** | **100% Pure ASCII** | 0 caractère non-ASCII dans l'intégralité du code Lua. Accents isolés dans les dictionnaires `Translate/`. |
| **Dépendances déclarées** | **OK** | `ComputerModkum41`, `DemoniusZombieVirusVaccine`, `AliceGear` présents dans `mod.info`. |

---

## 3. Guide de Test Opérationnel

1. **Test du Ravitaillement Vivres & Eau (`prep_food`)** :
   - Ouvrez l'interface IRIS (`K`) : constatez les deux jauges distinctes `Conserves : [X/20]` et `Reserves Eau : [Y/4]`.
   - Ramassez des conserves et des bouteilles d'eau/boissons de mods : observez la montée indépendante des deux barres.
   - La mission se valide lorsque les deux quotas sont atteints (dans l'inventaire ou stockés dans les meubles du QG).
2. **Test d'Immutabilité du QG** :
   - Une fois le QG établi, faites un clic droit au sol : l'option `[IRIS] Etablir le QG de l'Operation ici` a totalement disparu.
3. **Test du Terminal Unique & Sécurité Décès** :
   - En cas de mort du personnage portant le terminal, vérifiez que le terminal radio disparaît immédiatement du cadavre.
   - À la réapparition d'un nouvel agent, le terminal est attribué si la base n'en a pas encore.
4. **Test de la Balise Cartographique** :
   - Tant que le terminal est transporté, ouvrez la carte (`M`) : une cible ambre `[IRIS] TERMINAL ALPHA // EN TRANSIT` indique la position du porteur.
   - Posez le terminal au QG : la balise de transit disparaît et cède la place au repère officiel du QG.
5. **Test du Briefing Adaptatif** :
   - Faites spawn un joueur dans une partie où le QG est déjà établi : observez le briefing de ralliement affichant la liste des opérateurs sur zone et le bouton `REJOINDRE L'UNITE ALPHA SUR LE TERRAIN`.
