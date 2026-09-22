--[[
    PROJET DAMOCLES - DamoclesProfessions.lua
    Enregistrement du metier exclusif "Operateur IRIS" (iris_operator).

    Caracteristiques :
        - Profil militaire similaire au Veteran : Trait gratuit "Desensitized" (Insensible a la panique).
        - Competences de depart : Tir +2, Rechargement +2, Electricite +1, Mecanique +1, Premiers Secours +1.
        - Equipement militaire de dotation a la creation du survivant :
          Treillis militaire, bottes d'armee, veste pare-balles, beret et emetteur radio.
        - Regle exclusive : Seul l'Operateur IRIS detient les accreditations pour etablir le QG IRIS.
]]

require "NPCs/MainCreationMethods"

local function initDamoclesProfessions()
    local name = getTextOrNull("UI_prof_iris_operator") or "Operateur IRIS"
    -- Enregistrement de la profession (cout -6 points pour equilibrage avec Veteran)
    local prof = ProfessionFactory.addProfession(
        "iris_operator",
        name,
        "media/textures/Damocles/logo_agent.png",
        -6
    )

    -- Competences martiales et techniques
    prof:addXPBoost(Perks.Aiming, 2)
    prof:addXPBoost(Perks.Reloading, 2)
    prof:addXPBoost(Perks.Electricity, 1)
    prof:addXPBoost(Perks.Mechanics, 1)
    prof:addXPBoost(Perks.Doctor, 1)

    -- Trait emblematique : Insensible a la panique (comme le Veteran)
    prof:addFreeTrait("Desensitized")

    print("[DamoclesProfessions] Profession 'iris_operator' enregistree avec succes.")
end

Events.OnGameBoot.Add(initDamoclesProfessions)

--- Equipement automatique de la tenue de soldat et de dotation au premier spawn
local function onPlayerSpawn(playerIndex, player)
    local p = (player and type(player) == "userdata" and player)
        or (playerIndex and type(playerIndex) == "userdata" and playerIndex)
        or (type(playerIndex) == "number" and getSpecificPlayer(playerIndex))
        or getPlayer()

    if not p then return end

    local desc = p:getDescriptor()
    if not desc then return end

    local profId = desc:getProfession()
    if profId ~= "iris_operator" then return end

    local pData = p:getModData()
    if pData and not pData.Damocles_GearGiven then
        pData.Damocles_GearGiven = true
        local inv = p:getInventory()
        if not inv then return end

        pcall(function()
            -- Paquetage militaire tactique (place dans l'inventaire sous couverture civile)
            inv:AddItem("Base.Shoes_ArmyBoots")
            inv:AddItem("Base.Trousers_CamoGreen")
            inv:AddItem("Base.Shirt_CamoGreen")
            inv:AddItem("Base.Vest_BulletCivilian")
            inv:AddItem("Base.Hat_BeretArmy")

            -- 1. Sac a dos de deploiement tactique ALICE equipe sur le dos (reduction de poids 80%)
            local bag = inv:AddItem("Base.Bag_ALICEpack_Army")
            if bag then
                if bag.setName then
                    bag:setName("Sac de Deploiement Tactique IRIS (ALPHA-01)")
                end
                if p.setClothingItem_Back then
                    p:setClothingItem_Back(bag)
                end
            end
            local bagContainer = (bag and bag.getItemContainer and bag:getItemContainer()) or inv

            -- 2. Dotation tactique lourde stockee dans le sac de deploiement
            local shouldSpawnTerminal = true

            -- Verification multijoueur : UNIQUEMENT en mode Client/Serveur MP
            if isClient() and DamoclesMissionManager then
                if DamoclesMissionManager.isMissionCompleted("hq_radio") or DamoclesMissionManager.getTerminalLocation() then
                    shouldSpawnTerminal = false
                    print("[DamoclesProfessions] [MP] Le terminal IRIS est deja installe au QG. Aucun terminal attribue.")
                else
                    local currentCarrier = DamoclesMissionManager.getTerminalCarrier()
                    local myName = (p.getUsername and p:getUsername()) or ""
                    if currentCarrier and currentCarrier ~= "" and currentCarrier ~= myName then
                        local carrierOnline = false
                        if getOnlinePlayers then
                            local players = getOnlinePlayers()
                            if players then
                                for pIdx = 0, players:size() - 1 do
                                    local op = players:get(pIdx)
                                    if op and op:getUsername() == currentCarrier and not op:isDead() then
                                        carrierOnline = true
                                        break
                                    end
                                end
                            end
                        end
                        if carrierOnline then
                            shouldSpawnTerminal = false
                            print(string.format("[DamoclesProfessions] [MP] Terminal deja transporte par %s. Aucun doublon attribue.", currentCarrier))
                        end
                    end
                end
            end

            -- Attribution du terminal radio
            if shouldSpawnTerminal then
                local radio = bagContainer:AddItem("Radio.HamRadio2")
                if radio then
                    if radio.getModData then
                        radio:getModData().isDamoclesTerminal = true
                        radio:getModData().damoclesUID = "IRIS-TERM-ALPHA-01"
                    end
                    if radio.setName then
                        radio:setName("Terminal d'Etat-Major IRIS (ALPHA-01)")
                    end
                end
                if DamoclesMissionManager and DamoclesMissionManager.setTerminalCarrier then
                    local uName = (p.getUsername and p:getUsername()) or "SoloOperator"
                    DamoclesMissionManager.setTerminalCarrier(uName)
                end
                print("[DamoclesProfessions] Terminal unique IRIS-TERM-ALPHA-01 attribue avec succes.")
            end

            -- Ravitaillement logistique & survie
            bagContainer:AddItem("Base.PetrolCan")        -- Jerrican pour la mobilite tactique
            bagContainer:AddItem("Base.Bandage")
            bagContainer:AddItem("Base.Bandage")

            -- 3. Dotation d'armement de service et combat
            inv:AddItem("Base.HolsterSimple")
            inv:AddItem("Base.Pistol")
            inv:AddItem("Base.9mmClip")
            inv:AddItem("Base.9mmClip")
            inv:AddItem("Base.Bullets9mmBox")
            inv:AddItem("Base.HuntingKnife")

            -- 4. Accessoires tactiques (Montre digitale militaire operationnelle)
            local watch = inv:AddItem("Base.WristWatch_Left_DigitalBlack")
            if watch and p.setWornItem and watch.getBodyLocation then
                pcall(function() p:setWornItem(watch:getBodyLocation(), watch) end)
            end

            print("[DamoclesProfessions] Paquetage militaire complet, dotation d'armement, montre digitale et sac ALICE deployes avec succes.")
        end)
    end
end

--- Securite Deces : Retrait immediat du terminal pour eviter qu'il ne reste sur le cadavre ou zombie
local function onPlayerDeath(character)
    if not character then return end
    local inv = character:getInventory()
    if inv then
        local function purgeTerminalFromContainer(container)
            if not container then return end
            local items = container:getItems()
            if items then
                for i = items:size() - 1, 0, -1 do
                    local it = items:get(i)
                    if it then
                        local t = (it.getType and it:getType()) or ""
                        local ft = (it.getFullType and it:getFullType()) or ""
                        local isTerm = (it.getModData and it:getModData().isDamoclesTerminal) or t == "HamRadio2" or ft == "Radio.HamRadio2"
                        if isTerm then
                            print("[DamoclesProfessions] Deces du porteur : retrait du terminal pour eviter la perte sur cadavre/zombie.")
                            container:DoRemoveItem(it)
                        end
                        if it.getItemContainer and it:getItemContainer() then
                            purgeTerminalFromContainer(it:getItemContainer())
                        end
                    end
                end
            end
        end
        purgeTerminalFromContainer(inv)
    end

    if DamoclesMissionManager and DamoclesMissionManager.clearTerminalCarrier then
        local name = (character.getUsername and character:getUsername()) or ""
        DamoclesMissionManager.clearTerminalCarrier(name)
    end
end

Events.OnCreatePlayer.Add(onPlayerSpawn)
Events.OnPlayerDeath.Add(onPlayerDeath)
