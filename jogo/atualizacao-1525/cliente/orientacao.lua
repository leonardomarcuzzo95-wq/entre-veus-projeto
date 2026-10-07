-- Guidance observes existing dialogue/text messages. It never sends game commands,
-- changes quest storage, handles login or assumes progress from XP/inventory.
local guide={phase='initial'}
local panel
local pending
local fitting=false
local hints={
    initial='FALE COM MAIA: ela esta ao norte da praca (para cima). No chat Local, digite oi e aperte Enter.',
    dialogue='CONVERSE COM MAIA: na janela de conversa dela, digite missao e aperte Enter para saber o proximo passo.',
    seeking='BUSQUE O FRAGMENTO: da praca, ande 12 passos para a direita e 4 para cima. Pise no fragmento azul.',
    returning='VOLTE A MAIA: ande 4 passos para baixo e 12 para a esquerda. Diga oi; na conversa dela, diga missao.',
    completed='MISSAO CONCLUIDA: lembranca do porto e 100 XP recebidos uma unica vez. Voce pode continuar explorando.'
}
local hiddenControls={
    -- No shop/catalogue or purchases exist in the original playable slice.
    {id='Store shop',reason='Loja sem catalogo proprio neste recorte'},
    -- Prey bonuses are disabled by the local server configuration.
    {id='preyButton',reason='Sistema Prey desativado no servidor local'},
    -- Hunting tasks are disabled; Maia is the only mission in this slice.
    {id='taskHuntButton',reason='Task Hunt desativado; nao orienta a missao de Maia'}
}
local function fit()
    if not panel or fitting or panel:getWidth()<40 then return end
    fitting=true
    local height=16
    for index,id in ipairs({'title','objective','controls'}) do
        local label=panel:getChildById(id)
        label:setHeight(math.max(14,label:getTextSize().height))
        height=height+label:getHeight()+(index>1 and 6 or 0)
    end
    if panel:getHeight()~=height then panel:setHeight(height) end
    fitting=false
end
local function setPhase(phase)
    guide.phase=phase
    if panel then panel:getChildById('objective'):setText(hints[phase]);fit() end
end
local function hideUnusedControls()
    local root=modules.game_interface.getRootPanel()
    for _,control in ipairs(hiddenControls) do
        local widget=root:recursiveGetChildById(control.id)
        if widget then widget:hide() end
    end
    modules.game_mainpanel.reloadMainPanelSizes()
end
-- Diagnostic snapshot reads the actual widgets; QA checks this at each real step.
function guide.snapshot()
    local snapshot={phase=guide.phase,visible=panel and panel:isVisible() or false,labels={},hiddenControls={}}
    if panel then
        for _,id in ipairs({'title','objective','controls'}) do
            local label=panel:getChildById(id)
            local size=label:getTextSize()
            snapshot.labels[#snapshot.labels+1]={id=id,text=label:getText(),width=label:getWidth(),height=label:getHeight(),
                textWidth=size.width,textHeight=size.height,fits=size.width<=label:getWidth() and size.height<=label:getHeight()}
        end
    end
    for _,control in ipairs(hiddenControls) do
        local widget=modules.game_interface.getRootPanel():recursiveGetChildById(control.id)
        snapshot.hiddenControls[#snapshot.hiddenControls+1]={id=control.id,reason=control.reason,present=widget~=nil,hidden=widget~=nil and not widget:isVisible()}
    end
    return snapshot
end
connect(g_game,{
    onGameStart=function()
        if pending then removeEvent(pending) end
        if not panel then
            panel=g_ui.loadUI('/entreveus.otui',modules.game_interface.getMapPanel())
            panel.onGeometryChange=fit
        end
        -- On reconnect the authoritative next step comes from Maia again.
        setPhase('initial')
        panel:show()
        pending=scheduleEvent(function()
            pending=nil
            if not g_game.isOnline() then return end
            hideUnusedControls();fit()
        end,250)
    end,
    onGameEnd=function()
        if pending then removeEvent(pending);pending=nil end
        if panel then panel:hide() end
        guide.phase='initial'
    end,
    onTalk=function(name,level,mode,message)
        if name~='Maia' then return end
        if message:find('Missao concluida',1,true) or message:find('Voce ja restaurou',1,true) then setPhase('completed')
        elseif message:find('Procure o fragmento azul',1,true) then setPhase('seeking')
        elseif message:find('nesta conversa e aperte Enter',1,true) and guide.phase=='initial' then setPhase('dialogue') end
    end,
    onTextMessage=function(mode,message)
        if message:find('Voce recuperou a primeira memoria',1,true) then setPhase('returning') end
    end
})
return guide
