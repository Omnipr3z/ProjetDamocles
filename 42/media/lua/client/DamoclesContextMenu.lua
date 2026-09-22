--[[
    PROJET DAMOCLES - DamoclesContextMenu.lua
    Menu contextuel de clic droit dans le monde (World Object Context Menu).

    Responsabilites :
        - Revendication du QG IRIS (reserve a l'Operateur IRIS)
        - Interaction avec le terminal radio : "Contacter le Commandement Central"
        - Protection anti-vol : empeche de ramasser ou demonter le terminal radio pose
]]

require "DamoclesMissionManager"
require "DamoclesMissionDB"
require "Actions/DamoclesRadioContactAction"
require "DamoclesDeployableRegistry"

local DamoclesContextMenu = {}

--- Verifie si la mission hq_claim est actuellement active pour le joueur.
local function isHQClaimMissionActive()
    -- Si le QG est deja etabli, aucune modification n'est permise
    if DamoclesMissionManager then
        if DamoclesMissionManager.getHQBuilding() or DamoclesMissionManager.getHQLocation() then
            return false
        end
        if DamoclesMissionManager.isMissionCompleted("hq_claim") then
            return false
        end
    end
    if DamoclesClientState and DamoclesClientState.initialized and DamoclesClientState.missions then
        for _, m in ipairs(DamoclesClientState.missions) do
            if m.id == "hq_claim" then
                return m.status == "ACTIVE"
            end
        end
    end
    if DamoclesMissionDB and DamoclesMissionDB.getById then
        local m = DamoclesMissionDB.getById("hq_claim")
        if m then
            return m.status == "ACTIVE"
        end
    end
    -- Fallback de securite en Solo : si aucun QG n'est etabli, permettre l'interaction
    return true
end

--- Action executee lorsque le joueur clique sur l'option de revendication
local function onClaimHQ(worldobjects, playerNum, building, square)
    if not building or not square then return end
    if DamoclesMissionManager and DamoclesMissionManager.getHQBuilding() then
        print("[DamoclesContextMenu] QG deja etabli ! Modification interdite.")
        return
    end

    local def = building:getDef()
    if not def then return end

    local minX = def:getX()
    local minY = def:getY()
    local maxX = def:getX() + def:getW()
    local maxY = def:getY() + def:getH()
    local centerX = math.floor(minX + def:getW() / 2)
    local centerY = math.floor(minY + def:getH() / 2)
    local room = square:getRoom()
    local roomName = room and room:getName() or "Batiment Principal"

    local payload = {
        x        = centerX,
        y        = centerY,
        z        = square:getZ() or 0,
        minX     = minX,
        minY     = minY,
        maxX     = maxX,
        maxY     = maxY,
        roomName = roomName,
    }

    print(string.format("[DamoclesContextMenu] Revendication QG : (%d, %d) -> (%d, %d)", minX, minY, maxX, maxY))

    if isClient() then
        sendClientCommand("DamoclesClient", "ClaimHQ", payload)
    else
        DamoclesMissionManager.setHQBuilding(payload)
        DamoclesMissionManager.onComplete("hq_claim")
        if DamoclesServerHooks_broadcastState then
            DamoclesServerHooks_broadcastState()
        end
    end

    if DamoclesNotifyMissionComplete then
        DamoclesNotifyMissionComplete("ETABLIR LA TETE DE PONT", 0)
    end

    local playerObj = getSpecificPlayer(playerNum)
    if playerObj then
        playerObj:Say(getTextOrNull("UI_Damocles_HQEstablished") or "QG IRIS ETABLI : Tete de pont securisee.")
    end
end

--- Deplacement intelligent vers le terminal sans traverser les murs
local function damoclesWalkToTerminal(player, radioObj)
    if not player or not radioObj then return end
    local radioSq = radioObj:getSquare()
    if not radioSq then return end
    local playerSq = player:getCurrentSquare() or player:getSquare()
    if not playerSq then return end

    -- Si le joueur est deja adjacent et sans mur separateur, aucun deplacement necessaire
    local isAdjacent = math.abs(playerSq:getX() - radioSq:getX()) <= 1 and math.abs(playerSq:getY() - radioSq:getY()) <= 1
    if isAdjacent and not radioSq:isSomethingTo(playerSq) then
        return
    end

    local cell = getCell()
    if not cell then return end
    local z = radioSq:getZ()
    local bestSq = nil
    local bestDist = 999999

    local radioRoom = radioSq:getRoom()
    local offsets = {
        {0, 1}, {0, -1}, {1, 0}, {-1, 0},
        {1, 1}, {1, -1}, {-1, 1}, {-1, -1}
    }

    for _, off in ipairs(offsets) do
        local nx = radioSq:getX() + off[1]
        local ny = radioSq:getY() + off[2]
        local candSq = cell:getGridSquare(nx, ny, z)
        if candSq and not radioSq:isSomethingTo(candSq) then
            if candSq:isFree(false) or not candSq:isSolid() then
                local candRoom = candSq:getRoom()
                local roomMatches = (not radioRoom) or (candRoom == radioRoom)
                if roomMatches then
                    local dist = (playerSq:getX() - nx)^2 + (playerSq:getY() - ny)^2
                    if dist < bestDist then
                        bestDist = dist
                        bestSq = candSq
                    end
                end
            end
        end
    end

    -- Si aucune case avec room identique trouvee, assouplir la contrainte de room mais garder l'absence de mur
    if not bestSq then
        for _, off in ipairs(offsets) do
            local nx = radioSq:getX() + off[1]
            local ny = radioSq:getY() + off[2]
            local candSq = cell:getGridSquare(nx, ny, z)
            if candSq and not radioSq:isSomethingTo(candSq) then
                if candSq:isFree(false) or not candSq:isSolid() then
                    local dist = (playerSq:getX() - nx)^2 + (playerSq:getY() - ny)^2
                    if dist < bestDist then
                        bestDist = dist
                        bestSq = candSq
                    end
                end
            end
        end
    end

    if bestSq then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(player, bestSq))
    else
        luautils.walkToObject(player, radioObj)
    end
end

--- Action pour contacter le Central depuis le terminal
local function onContactCentral(worldobjects, playerNum, radioObj, mission)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not radioObj then return end

    damoclesWalkToTerminal(playerObj, radioObj)
    ISTimedActionQueue.add(DamoclesRadioContactAction:new(playerObj, radioObj, mission))
end

--- Hook OnFillWorldObjectContextMenu : injecte les options IRIS et securise le terminal
local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    ------------------------------------------------------------------------
    -- 1. REVENDICATION DU QG (hq_claim)
    ------------------------------------------------------------------------
    if isHQClaimMissionActive() then
        local building = nil
        local targetSquare = nil

        for _, obj in ipairs(worldobjects) do
            if obj and obj:getSquare() then
                local sq = obj:getSquare()
                local b = sq:getBuilding()
                if b then
                    building = b
                    targetSquare = sq
                    break
                end
            end
        end

        if not building and playerObj:getCurrentSquare() then
            local pSq = playerObj:getCurrentSquare()
            if pSq:getBuilding() then
                building = pSq:getBuilding()
                targetSquare = pSq
            end
        end

        if building and targetSquare then
            local desc = playerObj:getDescriptor()
            local isIrisOperator = desc and (desc:getProfession() == "iris_operator")
            local room = targetSquare:getRoom()

            if isIrisOperator then
                local label = getTextOrNull("UI_Damocles_ClaimHQ") or "[IRIS] Etablir le QG de l'Operation ici"
                if room then
                    label = string.format("%s (%s)", label, tostring(room:getName()))
                end

                local opt = context:addOption(label, worldobjects, onClaimHQ, playerNum, building, targetSquare)
                local icon = getTexture("media/textures/Damocles/logo_iris.png")
                if icon then opt.iconTexture = icon end
            else
                local label = getTextOrNull("UI_Damocles_ClaimHQ_Disabled") or "[IRIS] Etablir le QG (Reserve aux Operateurs IRIS)"
                local opt = context:addOption(label, worldobjects, nil)
                opt.notAvailable = true

                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = getTextOrNull("UI_Damocles_ClaimHQ_Tooltip")
                    or "Seul un Operateur IRIS certifie possede les codes de securite pour deployer la tete de pont."
                opt.toolTip = tooltip
            end
        end
    end

    ------------------------------------------------------------------------
    -- 2. INTERACTION TERMINAL RADIO & PROTECTION ANTI-VOL
    ------------------------------------------------------------------------
    local termLoc = DamoclesMissionManager.getTerminalLocation()

    --- Verifie si un objet est specifiquement le terminal radio IRIS
    --- Exclut categoriquement les televiseurs et les postes civils de maison
    local function isDamoclesTerminalObject(obj)
        if not obj then return false end

        -- Exclusion formelle des televiseurs
        if instanceof(obj, "IsoTelevision") then return false end
        if obj.getDeviceData and obj:getDeviceData() and obj:getDeviceData().getIsTelevision and obj:getDeviceData():getIsTelevision() then
            return false
        end

        local sq = obj:getSquare()
        if not sq or not DamoclesMissionManager.isSquareInHQ(sq) then return false end

        -- 1. Objet directement tague comme terminal IRIS
        if obj.getModData and obj:getModData().isDamoclesTerminal then
            return true
        end

        -- 2. Coordonnees exactes du terminal enregistre et verrouille
        if DamoclesMissionManager.isMissionCompleted("hq_radio") and termLoc and obj.getX and obj.getY then
            if math.floor(obj:getX()) == termLoc.x and math.floor(obj:getY()) == termLoc.y then
                return true
            end
        end

        -- 3. Item d'inventaire pose sur la table portant la balise ALPHA-01
        if instanceof(obj, "IsoWorldInventoryObject") and obj.getItem then
            local it = obj:getItem()
            if it then
                if it.getModData and it:getModData().isDamoclesTerminal then return true end
                local name = it.getName and it:getName() or ""
                if name:find("ALPHA%-01") or name:find("Terminal d'Etat-Major") then
                    return true
                end
            end
        end

        return false
    end

    --- Recherche si le joueur a clique SPECIFIQUEMENT sur le terminal ou la table qui le supporte
    local terminalObj = nil
    for _, obj in ipairs(worldobjects) do
        if obj then
            local sq = obj:getSquare()
            if sq and DamoclesMissionManager.isSquareInHQ(sq) then
                if isDamoclesTerminalObject(obj) then
                    terminalObj = obj
                    break
                end

                -- Si le clic a ete fait sur la table supportant le terminal
                if DamoclesMissionManager.isTableSquare(sq) then
                    local isSquareTerminal = termLoc and (sq:getX() == termLoc.x and sq:getY() == termLoc.y)

                    local wobjs = sq:getWorldObjects()
                    if wobjs then
                        for w = 0, wobjs:size() - 1 do
                            local wo = wobjs:get(w)
                            if isDamoclesTerminalObject(wo) then
                                terminalObj = wo
                                break
                            end
                        end
                    end
                    if terminalObj then break end

                    local sobjs = sq:getObjects()
                    if sobjs then
                        for s = 0, sobjs:size() - 1 do
                            local so = sobjs:get(s)
                            if isDamoclesTerminalObject(so) then
                                terminalObj = so
                                break
                            end
                        end
                    end
                    if terminalObj then break end

                    if isSquareTerminal then
                        terminalObj = obj
                        break
                    end
                end
            end
        end
    end

    -- L'interaction n'apparait QUE si on a clique sur le terminal ou son support dans le QG
    if terminalObj then
        local isTerminalPlaced = DamoclesMissionManager.isMissionCompleted("hq_radio")

        -- On ne peut contacter le Central QUE si le terminal est effectivement pose au QG
        if isTerminalPlaced then
            local activeMissions = DamoclesMissionManager.getActiveMissions()
            local contactMission = nil
            local currentTask = nil

            for _, m in ipairs(activeMissions) do
                if m.type == "RADIO_CONTACT" or m.type == "RADIO_CRYPTO_FINAL" then
                    contactMission = m
                    break
                else
                    currentTask = m
                end
            end

            local icon = getTexture("media/textures/Damocles/logo_iris.png")

            if contactMission then
                -- Option active : etablir le contact
                local opt = context:addOption(
                    "[IRIS] Contacter le Commandement Central",
                    worldobjects,
                    onContactCentral,
                    playerNum,
                    terminalObj,
                    contactMission
                )
                if icon then opt.iconTexture = icon end
            else
                -- Option informative : statut de veille
                local label = "[IRIS] Terminal Radio IRIS (En veille)"
                if currentTask then
                    label = string.format("[IRIS] Terminal IRIS (En cours : %s)", currentTask.title)
                end
                local opt = context:addOption(label, worldobjects, nil)
                opt.notAvailable = true
                if icon then opt.iconTexture = icon end
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = currentTask and (currentTask.title .. "\n" .. currentTask.description) or "Aucune transmission prioritaire en attente."
                opt.toolTip = tooltip
            end

            -- Protection anti-vol : supprimer les options de demontage ou de ramassage UNIQUEMENT si le terminal est installe dans le QG
            for i = #context.options, 1, -1 do
                local o = context.options[i]
                if o and o.name then
                    local lowerName = string.lower(o.name)
                    if string.find(lowerName, "prendre")
                        or string.find(lowerName, "grab")
                        or string.find(lowerName, "take")
                        or string.find(lowerName, "demonter")
                        or string.find(lowerName, "disassemble")
                        or string.find(lowerName, "ramasser")
                        or string.find(lowerName, "pick up") then
                        table.remove(context.options, i)
                    end
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

------------------------------------------------------------------------
-- 3. BOUTON INTERACTIF DIRECT DANS L'INTERFACE RADIO (ISRadioWindow)
-- Reserve EXCLUSIVEMENT au terminal pose dans le QG
------------------------------------------------------------------------

require "RadioCom/ISRadioWindow"

if ISRadioWindow then
    local old_readFromObject = ISRadioWindow.readFromObject
    function ISRadioWindow:readFromObject(_player, _deviceObject)
        old_readFromObject(self, _player, _deviceObject)

        local isIris = false
        local termLoc = DamoclesMissionManager.getTerminalLocation()
        local isPlaced = DamoclesMissionManager.isMissionCompleted("hq_radio")

        if isPlaced and _deviceObject then
            local isTV = instanceof(_deviceObject, "IsoTelevision")
            if not isTV and _deviceObject.getDeviceData and _deviceObject:getDeviceData() and _deviceObject:getDeviceData().getIsTelevision then
                isTV = _deviceObject:getDeviceData():getIsTelevision()
            end

            if not isTV then
                if _deviceObject.getModData and _deviceObject:getModData().isDamoclesTerminal then
                    isIris = true
                elseif termLoc and _deviceObject.getX and _deviceObject.getY then
                    local devX = math.floor(_deviceObject:getX())
                    local devY = math.floor(_deviceObject:getY())
                    if devX == termLoc.x and devY == termLoc.y then
                        isIris = true
                    end
                end
            end
        end

        if not self.damoclesContactBtn then
            local btnW = self:getWidth() - 20
            local btnH = 26
            self.damoclesContactBtn = ISButton:new(10, self:getHeight() + 4, btnW, btnH, "[IRIS] CONTACTER LE CENTRAL", self, function(win)
                local player = win.player or getPlayer()
                local dev = win.device

                local activeMissions = DamoclesMissionManager.getActiveMissions()
                local contactMission = nil
                local currentTask = nil
                for _, m in ipairs(activeMissions) do
                    if m.type == "RADIO_CONTACT" or m.type == "RADIO_CRYPTO_FINAL" then
                        contactMission = m
                        break
                    else
                        currentTask = m
                    end
                end

                if contactMission then
                    win:close()
                    if dev and player then
                        damoclesWalkToTerminal(player, dev)
                    end
                    ISTimedActionQueue.add(DamoclesRadioContactAction:new(player, dev or player, contactMission))
                else
                    if player and player.Say then
                        if currentTask then
                            player:Say("[IRIS] Frequence en veille. Tache en cours : " .. tostring(currentTask.title))
                        else
                            player:Say("[IRIS] Frequence securisee. Aucune transmission prioritaire.")
                        end
                    end
                end
            end)
            self.damoclesContactBtn:initialise()
            self.damoclesContactBtn:instantiate()
            self.damoclesContactBtn.borderColor = { r = 0.0, g = 0.8, b = 1.0, a = 0.9 }
            self.damoclesContactBtn.backgroundColor = { r = 0.05, g = 0.20, b = 0.25, a = 0.90 }
            self:addChild(self.damoclesContactBtn)
        end

        if self.damoclesContactBtn then
            self.damoclesContactBtn:setVisible(isIris)
        end
    end

    local old_prerender = ISRadioWindow.prerender
    function ISRadioWindow:prerender()
        old_prerender(self)
        if self.damoclesContactBtn and self.damoclesContactBtn:isVisible() then
            local curH = self:getHeight()
            self.damoclesContactBtn:setY(curH + 4)
            self.damoclesContactBtn:setWidth(self:getWidth() - 20)
            self:setHeight(curH + 34)
        end
    end
end

------------------------------------------------------------------------
-- 4. PROTECTION INVENTAIRE : RESTRICTION DE DEPLOIEMENT ET ANTI-DROP
------------------------------------------------------------------------


local function onFillInventoryTerminalProtection(playerNum, context, items)
    pcall(function()
        local deployableDef = nil
        for _, it in ipairs(items or {}) do
            local itemObj = it
            if type(it) == "table" and it.items then
                itemObj = it.items[1]
            end
            deployableDef = DamoclesDeployableRegistry.matchItem(itemObj)
            if deployableDef then break end
        end

        if deployableDef and context and context.options then
            local isHqClaimed = DamoclesMissionManager.isMissionCompleted("hq_claim")
            local label = deployableDef.label or "Cet equipement"
            for _, opt in ipairs(context.options) do
                if opt and opt.name then
                    local lowerName = string.lower(opt.name)
                    -- Jeter au sol est toujours interdit
                    if string.find(lowerName, "jeter") or string.find(lowerName, "drop") then
                        opt.notAvailable = true
                        local tooltip = ISWorldObjectContextMenu.addToolTip()
                        tooltip.description = string.format("[IRIS] %s ne peut pas etre jete au sol. Utilisez l'action 'Placer' sur une table du QG.", label)
                        opt.toolTip = tooltip
                    -- Placer est bloque tant que le QG n'est pas etabli
                    elseif not isHqClaimed and (string.find(lowerName, "placer") or string.find(lowerName, "place")) then
                        opt.notAvailable = true
                        local tooltip = ISWorldObjectContextMenu.addToolTip()
                        tooltip.description = "[IRIS] Vous devez d'abord etablir le QG de l'Operation avant de pouvoir deployer cet equipement."
                        opt.toolTip = tooltip
                    end
                end
            end
        end
    end)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryTerminalProtection)

------------------------------------------------------------------------
-- 5. PATCHS SYSTEMES DE DEPLOIEMENT ET ANTI-VOL (MOVEABLES & DROPS)
------------------------------------------------------------------------

Events.OnGameStart.Add(function()
    -- 5.1 Restriction de pose Moveable : OBLIGATOIREMENT DANS LE BATIMENT DU QG ET SUR UNE TABLE
    if ISMoveableSpriteProps and ISMoveableSpriteProps.canPlaceMoveableInternal then
        local old_canPlace = ISMoveableSpriteProps.canPlaceMoveableInternal
        ISMoveableSpriteProps.canPlaceMoveableInternal = function(self, _character, _square, _item, _forceTypeObject)
            local deployableDef = DamoclesDeployableRegistry.match(_item, self and self.spriteName)
            if deployableDef then
                local canPlace = DamoclesDeployableRegistry.canPlace(deployableDef, _square, _character)
                if not canPlace then
                    return false
                end

                -- Ajustement de hauteur pour un rendu parfait sur le meuble
                if self.getTotalTableHeight then
                    local h = self:getTotalTableHeight(_square)
                    if h and h > 0 then
                        if self.surface and self.surfaceIsOffset then
                            h = h - self.surface
                        end
                        self.yOffsetCursor = h
                    else
                        self.yOffsetCursor = 32
                    end
                end

                return true
            end

            return old_canPlace(self, _character, _square, _item, _forceTypeObject)
        end
    end

    -- 5.2 Interdiction et validation dans l'action ISMoveablesAction (Place, Pickup, Scrap, Rotate)
    if ISMoveablesAction and ISMoveablesAction.isValid then
        local old_moveable_isValid = ISMoveablesAction.isValid
        ISMoveablesAction.isValid = function(self)
            local shouldBlock = false
            local blockReason = nil

            pcall(function()
                -- A. Interdiction de soulever / demonter / tourner un equipement ancre au QG
                if (self.mode == "pickup" or self.mode == "scrap" or self.mode == "rotate") then
                    local isLocked, lockReason = DamoclesDeployableRegistry.isLocked(self.moveProps and self.moveProps.object, self.square, self.mode)
                    if isLocked then
                        shouldBlock = true
                        blockReason = lockReason
                        return
                    end
                    -- Protection du meuble support sous le terminal
                    local termLoc = DamoclesMissionManager.getTerminalLocation()
                    if termLoc and self.square and self.square:getX() == termLoc.x and self.square:getY() == termLoc.y then
                        if DamoclesMissionManager.isMissionCompleted("hq_radio") then
                            shouldBlock = true
                            blockReason = "[IRIS] Ce meuble supporte le terminal radio IRIS et ne peut pas etre deplace !"
                            return
                        end
                    end
                end

                -- B. Verification a la pose via l'outil Moveable
                if self.mode == "place" then
                    local item = self.item or (self.moveProps and self.moveProps.findInInventory and self.character and self.moveProps:findInInventory(self.character, self.origSpriteName))
                    local sprite = self.origSpriteName or (self.moveProps and self.moveProps.spriteName)
                    local deployableDef = DamoclesDeployableRegistry.match(item, sprite)

                    if deployableDef then
                        local canPlace, reason = DamoclesDeployableRegistry.canPlace(deployableDef, self.square, self.character)
                        if not canPlace then
                            shouldBlock = true
                            blockReason = reason
                            return
                        end
                    end
                end
            end)

            if shouldBlock then
                if self.character and self.character.Say and blockReason then
                    self.character:Say(blockReason)
                end
                self:stop()
                return false
            end

            return old_moveable_isValid(self)
        end
    end

    -- 5.3 Execution et validation stricte a la pose Moveable
    if ISMoveablesAction and ISMoveablesAction.perform then
        local old_moveable_perform = ISMoveablesAction.perform
        ISMoveablesAction.perform = function(self)
            local wasPlace = self.mode == "place"
            local targetSq = self.square
            local character = self.character
            local item = self.item or (self.moveProps and self.moveProps.findInInventory and character and self.moveProps:findInInventory(character, self.origSpriteName))
            local sprite = self.origSpriteName or (self.moveProps and self.moveProps.spriteName)
            local deployableDef = DamoclesDeployableRegistry.match(item, sprite)

            old_moveable_perform(self)

            if wasPlace and deployableDef and targetSq then
                local canPlace = DamoclesDeployableRegistry.canPlace(deployableDef, targetSq, character)
                if canPlace then
                    DamoclesDeployableRegistry.onPerformPlace(deployableDef, targetSq, character, nil)
                end
            end
        end
    end

    -- 5.4 Interdiction de deposer au sol par glisser-deposer d'inventaire
    if ISDropItemAction and ISDropItemAction.isValid then
        local old_drop_isValid = ISDropItemAction.isValid
        ISDropItemAction.isValid = function(self)
            local shouldBlock = false
            pcall(function()
                if DamoclesDeployableRegistry.matchItem(self.item) then
                    shouldBlock = true
                end
            end)
            if shouldBlock then
                if self.character and self.character.Say then
                    self.character:Say("[IRIS] Cet equipement ne peut pas etre jete au sol. Utilisez 'Placer' sur une table du QG !")
                end
                return false
            end
            return old_drop_isValid(self)
        end
    end

    -- 5.5 Interdiction et validation via le curseur de placement 3D
    if ISDropWorldItemAction and ISDropWorldItemAction.isValid then
        local old_dropWorld_isValid = ISDropWorldItemAction.isValid
        ISDropWorldItemAction.isValid = function(self)
            local shouldBlock = false
            local blockReason = nil

            pcall(function()
                local deployableDef = DamoclesDeployableRegistry.matchItem(self.item)
                if deployableDef then
                    local canPlace, reason = DamoclesDeployableRegistry.canPlace(deployableDef, self.sq, self.character)
                    if not canPlace then
                        shouldBlock = true
                        blockReason = reason
                        return
                    end
                end
            end)

            if shouldBlock then
                if self.character and self.character.Say and blockReason then
                    self.character:Say(blockReason)
                end
                return false
            end

            return old_dropWorld_isValid(self)
        end
    end

    if ISDropWorldItemAction and ISDropWorldItemAction.perform then
        local old_dropWorld_perform = ISDropWorldItemAction.perform
        ISDropWorldItemAction.perform = function(self)
            local item = self.item
            local targetSq = self.sq
            local character = self.character
            local deployableDef = DamoclesDeployableRegistry.matchItem(item)

            old_dropWorld_perform(self)

            if deployableDef and targetSq then
                local canPlace = DamoclesDeployableRegistry.canPlace(deployableDef, targetSq, character)
                if canPlace then
                    DamoclesDeployableRegistry.onPerformPlace(deployableDef, targetSq, character, nil)
                end
            end
        end
    end

    -- 5.6 Protection anti-ramassage avec l'outil Moveable (Prendre un meuble)
    if ISMoveableSpriteProps then
        local function shouldBlockPickup(selfProps, char, sq, obj)
            local isLocked = DamoclesDeployableRegistry.isLocked(obj, sq, "pickup")
            if isLocked then return true end
            if DamoclesMissionManager.isMissionCompleted("hq_radio") then
                local termLoc = DamoclesMissionManager.getTerminalLocation()
                if termLoc and sq and sq:getX() == termLoc.x and sq:getY() == termLoc.y then
                    return true
                end
            end
            return false
        end

        if ISMoveableSpriteProps.canPickUpMoveableInternal then
            local old_canPickUp = ISMoveableSpriteProps.canPickUpMoveableInternal
            ISMoveableSpriteProps.canPickUpMoveableInternal = function(self, _character, _square, _object, _isMulti)
                if shouldBlockPickup(self, _character, _square, _object) then
                    return false
                end
                return old_canPickUp(self, _character, _square, _object, _isMulti)
            end
        end

        if ISMoveableSpriteProps.canPickUpMoveable then
            local old_canPickUpParent = ISMoveableSpriteProps.canPickUpMoveable
            ISMoveableSpriteProps.canPickUpMoveable = function(self, _character, _square, _object)
                if shouldBlockPickup(self, _character, _square, _object) then
                    return false
                end
                return old_canPickUpParent(self, _character, _square, _object)
            end
        end
    end
end)

