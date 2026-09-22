--[[
    PROJET DAMOCLES - DamoclesRadioContactAction.lua
    Action temporisee pour etablir la liaison avec le Commandement Central depuis le terminal radio.
    Decompose le message en transmissions successives espacees avec delai de captation,
    bruitages radio et accuse de reception de l'agent.
--]]

require "TimedActions/ISBaseTimedAction"

DamoclesRadioContactAction = ISBaseTimedAction:derive("DamoclesRadioContactAction")

function DamoclesRadioContactAction:isValid()
    return self.character ~= nil and self.radioObj ~= nil
end

function DamoclesRadioContactAction:playRadioSound(soundName)
    if not soundName then return end

    -- 1. Son spatial sur la case du terminal radio
    pcall(function()
        local sq = self.radioObj and self.radioObj:getSquare()
        if sq and sq.playSound then
            sq:playSound(soundName)
        end
    end)

    -- 2. Emetteur audio du personnage
    pcall(function()
        if self.character and self.character.getEmitter then
            self.character:getEmitter():playSound(soundName)
        elseif self.character and self.character.playSound then
            self.character:playSound(soundName)
        end
    end)

    -- 3. SoundManager UI pour certitude absolue d'audition
    pcall(function()
        if getSoundManager() and getSoundManager().playUISound then
            getSoundManager():playUISound(soundName)
        end
    end)
end

function DamoclesRadioContactAction:displayColoredMessage(text, r, g, b)
    if not text or #text == 0 then return end

    -- 1. Affichage au-dessus du terminal radio dans le monde (IsoWaveSignal ChatElement)
    if self.radioObj then
        pcall(function()
            local chatElem = (self.radioObj.getChatElement and self.radioObj:getChatElement())
            if chatElem and chatElem.addChatLine then
                chatElem:addChatLine(text, r, g, b, 1.0)
            end
        end)
        pcall(function()
            if self.radioObj.AddDeviceText then
                self.radioObj:AddDeviceText(text, r, g, b, "-1", "-1", 10)
            end
        end)
    end

    -- 2. Affichage au-dessus du joueur avec coloration RGB native (sans Say() qui forcerait du blanc)
    if self.character and self.character.addLineChatElement then
        pcall(function()
            self.character:addLineChatElement(text, r, g, b)
        end)
    end
end

function DamoclesRadioContactAction:displayLine(index)
    self.currentLineIndex = index
    local text = self.lines[index]
    if not text or #text == 0 then return end

    local fullMsg = string.format("[CENTRAL %d/%d] : %s", index, #self.lines, text)

    -- Bruitage de squelch / transmission
    self:playRadioSound("RadioTalk")

    -- Affichage en Cyan electrique vibrant
    self:displayColoredMessage(fullMsg, 0.15, 0.95, 1.00)
end

function DamoclesRadioContactAction:displayAlphaAck()
    if self.alphaAckShown then return end
    self.alphaAckShown = true

    local ackMsg = "[ALPHA] : Unite Alpha au Central, bien recu. Termine."

    -- Bruitage de clic micro / fin de transmission
    self:playRadioSound("RadioButton")

    -- Affichage en Vert Emeraude tactique
    self:displayColoredMessage(ackMsg, 0.25, 1.00, 0.45)
end

function DamoclesRadioContactAction:update()
    if self.radioObj and self.character and self.radioObj.getX then
        self.character:faceThisObject(self.radioObj)
    end

    self.tickCount = (self.tickCount or 0) + 1

    -- Phase 1 : Delai initial de captation du signal (~1.5s)
    if self.tickCount < self.captureDelay then
        return
    end

    -- Phase 2 : Affichage sequentiel des messages du Central
    local elapsed = self.tickCount - self.captureDelay
    local targetLine = math.min(#self.lines, math.floor(elapsed / self.lineDuration) + 1)

    if targetLine > self.currentLineIndex then
        self:displayLine(targetLine)
    end

    -- Phase 3 : Accuse de reception d'ALPHA apres la derniere transmission
    if self.currentLineIndex >= #self.lines then
        local lineFinishTick = self.captureDelay + (#self.lines * self.lineDuration)
        if self.tickCount >= (lineFinishTick + self.ackDelay) and not self.alphaAckShown then
            self:displayAlphaAck()
        end
    end
end

function DamoclesRadioContactAction:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLoot")

    -- Bruitage de mise sous tension et gresillement de captation
    self:playRadioSound("RadioStatic")

    -- Message de syntonisation initiale en Cyan gris metallique
    local tuningMsg = "*Gresillement radio... Syntonisation de la frequence securisee...*"
    self:displayColoredMessage(tuningMsg, 0.70, 0.85, 0.95)
end

function DamoclesRadioContactAction:stop()
    self:playRadioSound("RadioButton")
    ISBaseTimedAction.stop(self)
end

function DamoclesRadioContactAction:perform()
    self:playRadioSound("RadioButton")

    if isClient() then
        sendClientCommand("DamoclesClient", "RadioContact", {})
    else
        DamoclesMissionManager.onRadioContact(self.character)
    end

    ISBaseTimedAction.perform(self)
end

function DamoclesRadioContactAction:new(character, radioObj, mission)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.radioObj  = radioObj
    o.mission   = mission

    -- Extraction des lignes de transmission
    o.lines = {}
    if mission and mission.radioTransmission then
        if type(mission.radioTransmission) == "table" then
            for _, l in ipairs(mission.radioTransmission) do
                table.insert(o.lines, l)
            end
        elseif type(mission.radioTransmission) == "string" then
            for sentence in mission.radioTransmission:gmatch("([^.!?]+[.!?]*)") do
                local trimmed = sentence:gsub("^%s+", ""):gsub("%s+$", "")
                if #trimmed > 0 then
                    table.insert(o.lines, trimmed)
                end
            end
            if #o.lines == 0 then
                table.insert(o.lines, mission.radioTransmission)
            end
        end
    end

    if #o.lines == 0 then
        table.insert(o.lines, "Liaison etablie. En attente de donnees.")
    end

    o.captureDelay     = 50  -- ~1.5 seconde de captation / syntonisation
    o.lineDuration     = 240 -- ~6 secondes par transmission
    o.ackDelay         = 40  -- ~1 seconde apres la derniere ligne avant la reponse ALPHA
    o.alphaAckShown    = false
    o.currentLineIndex = 0
    o.tickCount        = 0

    o.maxTime = o.captureDelay + (#o.lines * o.lineDuration) + o.ackDelay + 60
    o.stopOnWalk = true
    o.stopOnRun  = true
    return o
end
