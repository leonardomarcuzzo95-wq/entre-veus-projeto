-- Original Entre Veus character and dialogue, 2026-10-02.
local npcType=Game.createNpcType("Maia")
local config={name="Maia",description="Maia, guardia das memorias",health=100,maxHealth=100,walkInterval=0,walkRadius=0,outfit={lookType=129},flags={floorchange=false}}
local keywords=KeywordHandler:new()
local handler=NpcHandler:new(keywords)
npcType.onThink=function(npc,interval) handler:onThink(npc,interval) end
npcType.onAppear=function(npc,creature) handler:onAppear(npc,creature) end
npcType.onDisappear=function(npc,creature) handler:onDisappear(npc,creature) end
npcType.onMove=function(npc,creature,from,to) handler:onMove(npc,creature,from,to) end
npcType.onSay=function(npc,creature,kind,message)
    -- Accept Portuguese greetings as well as the standard NPC greeting.
    if message:lower()=="oi" or message:lower()=="ola" then message="hi" end
    handler:onSay(npc,creature,kind,message)
end
npcType.onCloseChannel=function(npc,player) handler:onCloseChannel(npc,player) end
handler:setMessage(MESSAGE_GREET,"Bem-vindo ao Porto da Memoria, |PLAYERNAME|. Digite {missao} nesta conversa e aperte Enter para saber seu proximo passo.")
handler:setMessage(MESSAGE_FAREWELL,"Que suas lembrancas iluminem o caminho.")
handler:setMessage(MESSAGE_WALKAWAY,"Estarei aqui quando voltar.")
handler:setCallback(CALLBACK_MESSAGE_DEFAULT,function(npc,player,kind,message)
    if not handler:checkInteraction(npc,player) then return false end
    local text=message:lower()
    if text:find("missao",1,true) or text:find("memoria",1,true) then
        local state=player:getStorageValue(110020)
        if state==2 then
            handler:say("Voce ja restaurou a primeira memoria. Missao concluida: a lembranca e os 100 XP foram entregues uma unica vez. Pode explorar o porto. Obrigada!",npc,player)
        elseif state==1 then
            if player:addItem(62011,1,false) then
                player:setStorageValue(110020,2)
                player:addExperience(100,true)
                handler:say("A memoria voltou! Missao concluida. Voce recebeu a lembranca do porto e 100 pontos de experiencia, uma unica vez. Pode continuar explorando.",npc,player)
            else
                handler:say("Libere espaco para receber sua lembranca e fale {missao} novamente.",npc,player)
            end
        else
            if not player:getSlotItem(CONST_SLOT_BACKPACK) and not player:addItem(62012,1,false,1,CONST_SLOT_BACKPACK) then
                handler:say("Libere o espaco da bolsa para receber os materiais da missao.",npc,player)
                return true
            end
            player:setStorageValue(110020,0)
            handler:say("Procure o fragmento azul: da praca, ande 12 passos para leste (direita) e 4 para norte (cima). Pise nele. Depois volte, diga {oi} e, nesta conversa, {missao}. Nao e preciso lutar com o Eco Errante.",npc,player)
        end
    end
    return true
end)
handler:addModule(FocusModule:new(),config.name,true,true,true)
npcType:register(config)
