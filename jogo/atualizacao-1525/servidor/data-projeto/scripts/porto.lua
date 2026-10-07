-- Original map population and persistent, one-time exploration objective.
local startup=GlobalEvent("EntreVeusPortoStartup")
function startup.onStartup()
    local maia=Game.createNpc("Maia",Position(100,98,7))
    local eco=Game.createMonster("Eco Errante",Position(119,100,7),true,true)
    if not maia or not eco then logger.error("Entre Veus: missing original world inhabitants") end
    return true
end
startup:register()
local fragment=MoveEvent()
function fragment.onStepIn(creature,item,position,fromPosition)
    local player=creature:getPlayer()
    if not player then return true end
    if player:getStorageValue(110020)==0 then
        player:setStorageValue(110020,1)
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE,"Voce recuperou a primeira memoria. Volte a Maia e diga: missao.")
        position:sendMagicEffect(CONST_ME_MAGIC_BLUE)
    elseif player:getStorageValue(110020)<0 then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE,"O fragmento parece guardar uma historia. Fale com Maia na praca: oi, depois missao.")
    end
    return true
end
fragment:type("stepin")
fragment:id(62009)
fragment:register()
