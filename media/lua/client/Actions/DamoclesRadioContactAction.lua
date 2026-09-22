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
    if self.character and self.character.playSound then
        pcall(function() self.character:playSound(soundName) end)
    elseif getSoundManager() then
        pcall(function() getSoundManager():playUISound(soundName) end)
    end
end

function DamoclesRadioContactAction:displayLine(index)
    self.currentLineIndex = index
    local text = self.lines[index]
    if not text or #text == 0 then return end

    local fullMsg = string.format("[CENTRAL %d/%d] : %s", index, #self.lines, text)

    -- Bruitage de squelch / transmission
    self:playRadioSound("RadioTalk")

    -- Affichage au-dessus du terminal radio dans le monde (Cyan electrique)
    if self.radioObj and self.radioObj.addLineChatElement then
        self.radioObj:addLineChatElement(fullMsg, 0.15, 0.95, 1.0)
    end

    -- Affichage egalement dans le chat du joueur
    if self.character and self.character.Say then
        self.character:Say(fullMsg)
    end
end

function DamoclesRadioContactAction:displayAlphaAck()
    if self.alphaAckShown then return end
    self.alphaAckShown = true

    local ackMsg = "[ALPHA] : Unite Alpha au Central, bien recu. Termine."

    -- Bruitage de clic micro / fin de transmission
    self:playRadioSound("RadioButton")

    -- Affichage au-dessus du terminal radio en Vert Emeraude
    if self.radioObj and self.radioObj.addLineChatElement then
        self.radioObj:addLineChatElement(ackMsg, 0.25, 1.0, 0.45)
    end

    -- Dialogue emis par le personnage
    if self.character and self.character.Say then
        self.character:Say(ackMsg)
    end
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

    -- Message de syntonisation initiale
    local tuningMsg = "*Gresillement radio... Syntonisation de la frequence securisee...*"
    if self.radioObj and self.radioObj.addLineChatElement then
        self.radioObj:addLineChatElement(tuningMsg, 0.7, 0.8, 0.9)
    end
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
