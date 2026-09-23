# Modifications & Reponses Damocles

## 1. UI IRIS : Fermeture au clic en dehors
- **Fermeture dynamique** : Ajout de la methode `DamoclesMainWindow:onMouseDownOutside(x, y)`. Si la fenetre n'est pas epinglee (`not self.pin`), tout clic effectue en dehors de la fenetre la ferme proprement (`self:close()`).
- **Suppression du repli automatique au survol** : Retrait du timer de repli au survol de la souris. Vous pouvez desormais deplacer la souris librement sur votre ecran sans que la fenetre ne se replie de maniere intempestive.

---

## 2. Mission Mobilite Tactique : Affichage en 3 objectifs simultanes
- **Projection dynamique dans l'UI IRIS** :
  - La jauge unique globale `[x/3] Etapes` a ete retiree.
  - La mission se projette desormais dans la liste des ordres d'operation sous forme de **3 missions/taches distinctes et simultanees**, chacune possedant son icone thematique, son intitule, son compteur et sa propre barre de progression :
    1. ⚙️ **`VEHICULE : PRENDRE LE CONTROLE`**
       - Valide des que le joueur entre dans le vehicule ou demarre le moteur (`[0/1]` -> `[OK] VALIDE`).
    2. ⛽ **`VEHICULE : NIVEAU DE CARBURANT (3L)`**
       - Affiche le niveau precis de carburant du reservoir en litres (`[x.x/3.0] L` -> `[OK] VALIDE (3.0L)`).
    3. 🛡️ **`VEHICULE : RAPATRIER AU QG`**
       - Valide des que le vehicule est conduit et stationne a proximite du QG (<= 35 cases) (`[0/1]` -> `[OK] VALIDE`).
  - **Retour visuel dynamique** : Chaque tache accomplie passe immediatement en vert emeraude tactique avec le libelle `[OK] VALIDE` et sa barre a 100%. Des que les 3 taches sont remplies, la mission globale se cloture et declenche la liaison radio avec le Central.

---

## 2. Mission Ravitaillement & Eau (`prep_food`)
- **Comptage STRICTEMENT limite aux conteneurs du QG** :
  - Suppression de la prise en compte de l'inventaire personnel du joueur.
  - La mission scanne desormais les conteneurs (placards, caisses, etageres, frigos, armoires, comptoirs) situes a l'interieur du batiment du QG sur tous les etages (z = 0 a 7).
  - Prise en compte recursive : si vous rangez un sac a dos ou une glaciere contenant des vivres dans un placard du QG, son contenu est egalement inspecte et comptabilise.
- **Prise en charge etendue des denrees non perissables** :
  - Biscuits, cookies, crackers, chips, aperitifs secs.
  - Chocolats, barres de cereales, bonbons, sucreries.
  - Cereales, flocons d'avoine, pates, riz, nouilles instantanees/ramen, beurre de cacahuete, boeuf seche (jerky).
- **Prise en charge complete de Project France** :
  - Plats cuisines et bocaux : Tartiflette, Boeuf Bourguignon, Cassoulet, Confit de Canard, Blanquette, Bouillabaisse, Garbure, Andouillette, Piperade, Daube, Ratatouille, Axoa, Choucroute, Moules, Petit Sale.
  - Terrines, pates, rillettes, foies gras, pots de confiture, snickers/mars.
  - Reconnaissance des termes francais et mots-cles : `bocal`, `bocaux`, `terrine`, `confit`, `rillettes`, `foiegras`, `confiture`, `conserve`.
- **Mission contextuelle de contact radio** :
  - Des que le quota (20 vivres / 4 boissons) est depose au QG, la mission se valide immediatement avec notification et replique de votre agent : *"Ravitaillement du QG termine. Je dois etablir la liaison radio avec le Central."*
  - Le terminal radio affiche alors explicitement l'option contextuelle :
    `[IRIS] Liaison Radio : SITREP CENTRAL // COMPTE RENDU VIVRES & EAU`
  - L'action effectue le compte-rendu aupres du Central par radio securisee avant de debloquer l'etape suivante (Mobilite Tactique / Vehicule).

---

## 3. Bug de disparition Sacoche / Sac ALICE : Explication
- **Mecanique vanilla du jeu** : Dans Project Zomboid (et modpacks comme Authentic Z), la **sacoche** (`Base.Bag_Satchel`) et les **sacs a dos** (`Bag_ALICEpack_Army`, etc.) partagent exactement le meme emplacement de portage corporel : `CanBeEquipped = Back` (`BodyLocation = Back`).
- **Ce qui s'est produit** :
  1. Quand vous faites un clic droit sur la sacoche et choisissez *"Porter sur le dos"*, le jeu **desequipe automatiquement** le sac ALICE pour mettre la sacoche a la place.
  2. Un sac ALICE rempli pese souvent bien plus que la limite de portage de votre personnage. Le jeu tente alors de placer le sac desequipe dans votre inventaire principal ou dans la main secondaire.
  3. Si la charge est trop lourde, ou si un conteneur etait ouvert a proximite pendant le transfert, Project Zomboid **depose le sac directement sur le sol** (sous vos pieds) ou **dans le conteneur ouvert**.
  4. De plus, une fois le sac desequipe, son onglet d'inventaire sur la colonne de droite disparait instantanement, donnant l'impression que le sac a disparu dans le neant.

---

## 4. Refactoring d'Architecture : Classe `DamoclesMissionValidator`

Pour repondre a votre demande de maintenabilite et de separation des responsabilites (Single Responsibility Principle) :

- **Nouvelle classe centrale** : [`DamoclesMissionValidator.lua`](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/shared/DamoclesMissionValidator.lua) (et sa copie miroir 42).
- **Centralisation des methodes de validation** :
  - `DamoclesMissionValidator.onEveryOneMinute(player)` : Parcours de toutes les missions actives et declenchement des regles logiques.
  - `DamoclesMissionValidator.onEnterVehicle(character)` : Hook evenementiel immediat quand un personnage entre dans un vehicule (permet de valider l'etape de prise de controle sans attendre le timer).
  - `DamoclesMissionValidator.onExitVehicle(character)` : Hook evenementiel immediat a la descente du vehicule pour tester le stationnement au QG.
  - `DamoclesMissionValidator.onObjectAdded(obj)` : Hook evenementiel lors de la pose d'objets (generateur, etc.).
- **Helpers specifiques et modulaires** :
  - `DamoclesMissionValidator.evaluateVehicle(veh, player, hq, options)` : Fonction generique et parametrisable (`minFuel`, `maxDistHQ`, etc.) permettant de creer n'importe quelle nouvelle quete de vehicule en 1 seule ligne !
  - `DamoclesMissionValidator.checkVehicleSecured(player)`
  - `DamoclesMissionValidator.checkFoodSupplies(player, reqFood, reqWater)`
  - `DamoclesMissionValidator.checkHoldItems(player, mission)`
  - `DamoclesMissionValidator.checkGeneratorAcquired(player)`
  - `DamoclesMissionValidator.checkComputerInstalled(player)`
  - `DamoclesMissionValidator.checkSterileZone()`, `areCorpsesCleanedInHQ()`, `isHQBarricaded()`, `isHQPoweredByGenerator()`
- **Extensibilite native (`registerChecker`)** :
  - `DamoclesMissionValidator.registerChecker("NOUVEAU_TYPE", function(player, mission) ... end)` permet d'enregistrer a la volee n'importe quel validateur de quete personnalise.
- **Simplification de [`DamoclesServerHooks.lua`](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/server/DamoclesServerHooks.lua)** :
  - Les hooks `Events.EveryOneMinute`, `Events.OnEnterVehicle`, `Events.OnExitVehicle` et `Events.OnObjectAdded` deleguent directement a `DamoclesMissionValidator` en 1 ligne.
- **Retro-compatibilite totale** :
  - [`DamoclesMissionManager.lua`](file:///c:/Users/herna/Zomboid/mods/ProjetDamocles/media/lua/shared/DamoclesMissionManager.lua) delegue ses methodes de verification a `DamoclesMissionValidator`, garantissant que l'UI et les scripts existants continuent de fonctionner sans modification.
