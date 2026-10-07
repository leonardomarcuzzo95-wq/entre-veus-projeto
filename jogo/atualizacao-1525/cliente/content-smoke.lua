-- One real mission run with Explorador QA. No Viajante login or movement.
local E=assert(EntreVeusEvidence)
local previewOnly=os.getenv('ENTREVEUS_UI_PREVIEW')=='1'
local record=E.fileRecorder(previewOnly and "ui-preview" or "content-smoke",{
    runId=EntreVeusRunId,test=previewOnly and "initial-ui-preview" or "original-npc-exploration-reward",mode=previewOnly and "preview" or "qa",
    scope=previewOnly and "Initial QA screen only; no mission executed" or "NPC exploration and unique 100 XP reward, observed by the real client"
})
local result=record.data
result.dialogue={}
result.ui={snapshots={},checksPassed=false}
local runtime=os.getenv('LOCALAPPDATA'):gsub('\\','/') .. '/EntreVeus1525'
local f=assert(io.open(runtime .. '/credentials.json','r'))
local secrets=json.decode(f:read('*a'));f:close()
local done=false
local function finish(message)
    if done then return end
    done=true
    result.state.phase="completed"
    record:complete(message==nil,message)
    if g_game.isOnline() then
        record:event("logoutRequested")
        g_game.safeLogout()
    end
    scheduleEvent(function() record:event("clientExitRequested");g_app.exit() end,1800)
end
local function observeUi(phase,stage)
    local snapshot=EntreVeusGuide and EntreVeusGuide.snapshot()
    if not snapshot or not snapshot.visible or snapshot.phase~=phase then
        finish('Guidance phase not confirmed: '..phase);return false
    end
    for _,label in ipairs(snapshot.labels) do
        if not label.fits then finish('Guidance text clipped: '..label.id);return false end
    end
    for _,control in ipairs(snapshot.hiddenControls) do
        if not control.present or not control.hidden then finish('Unused control still visible: '..control.id);return false end
    end
    snapshot.stage=stage
    result.ui.snapshots[#result.ui.snapshots+1]=snapshot
    record:event('uiObserved',{stage=stage,phase=phase,snapshot=snapshot})
    return true
end
-- Compile without executing the source; exercise recorder logic with synthetic events
-- separately from the actual game events of this run.
local syntaxFiles={'/evidence.lua','/evidence-tests.lua','/entreveus1525rc.lua','/content-smoke.lua','/init.lua','/orientacao.lua'}
local checked={}
for _,path in ipairs(syntaxFiles) do
    local compiled,err=loadstring(g_resources.readFileContents(path),path)
    if not compiled then finish("Lua syntax check failed: "..path);return end
    checked[#checked+1]=path
end
result.luaSyntax={passed=true,files=checked}
local ok,regression=pcall(function() return dofile('/evidence-tests.lua')(E) end)
if not ok then finish("Evidence synthetic regression failed");return end
result.recorderUnitTests=regression
record:event("preflightPassed",{luaFiles=#checked,syntheticChecks=#regression.checks})

local function position()
    local player=g_game.getLocalPlayer()
    return player and player:getPosition()
end
local function waitAt(x,y,nextStep,tries)
    if done then return end
    local p=position()
    if p and p.x==x and p.y==y then
        record:event("destinationReached",{x=x,y=y,z=p.z})
        return scheduleEvent(nextStep,400)
    end
    if (tries or 0)>=50 then return finish('Walking destination not reached: '..x..','..y) end
    scheduleEvent(function() waitAt(x,y,nextStep,(tries or 0)+1) end,300)
end
local function walk(directions,x,y,nextStep)
    if done then return end
    g_game.autoWalk(directions,position());waitAt(x,y,nextStep)
end
local function dirs(direction,count)
    local path={};for i=1,count do path[#path+1]=direction end;return path
end
local function verifyReward()
    if done then return end
    result.experienceAfter=g_game.getLocalPlayer():getExperience()
    result.rewardOnce=result.experienceAfter-result.experienceBefore==100
    record:event("rewardObserved",{experience=result.experienceAfter,delta=result.experienceAfter-result.experienceBefore})
    if not result.rewardOnce then return finish('Expected exactly 100 experience reward') end
    if not observeUi('completed','reward') then return end
    g_game.talkPrivate(MessageModes.NpcTo,'Maia','missao')
    record:event("duplicateRewardRequested")
    scheduleEvent(function()
        if done then return end
        result.duplicateRewardRejected=g_game.getLocalPlayer():getExperience()==result.experienceAfter
        record:event("duplicateRewardChecked",{rejected=result.duplicateRewardRejected,experience=g_game.getLocalPlayer():getExperience()})
        scheduleEvent(function()
            if done or not observeUi('completed','duplicate_reward') then return end
            result.ui.checksPassed=true
            result.screenshot='porto-memoria-'..EntreVeusRunId..'.png'
            record:save()
            g_app.doScreenshot(result.screenshot)
            scheduleEvent(function()
                if result.duplicateRewardRejected then finish() else finish('Duplicate experience reward') end
            end,5000)
        end,6000)
    end,1600)
end
local function completeQuest()
    if done then return end
    g_game.talk('oi')
    scheduleEvent(function()
        if done then return end
        g_game.talkPrivate(MessageModes.NpcTo,'Maia','missao')
        scheduleEvent(verifyReward,1600)
    end,1600)
end
local function returnToMaia()
    walk(dirs(South,4),112,100,function() walk(dirs(West,12),100,100,completeQuest) end)
end
local function reachFragment()
    walk(dirs(East,12),112,100,function()
        for _,creature in pairs(g_map.getSpectators(position(),false)) do
            if creature:getName()=='Eco Errante' then result.creaturePresent=true end
        end
        walk(dirs(North,4),112,96,function()
            result.fragmentReached=true
            record:event("fragmentReached")
            scheduleEvent(function()
                if observeUi('returning','fragment') then
                    result.ui.fragmentScreenshot='ui-fragmento-'..EntreVeusRunId..'.png'
                    g_app.doScreenshot(result.ui.fragmentScreenshot)
                    scheduleEvent(returnToMaia,1500)
                end
            end,1000)
        end)
    end)
end
local function beginMission()
    if done then return end
    g_game.talk('oi')
    scheduleEvent(function()
        if done or not observeUi('dialogue','greeting') then return end
        g_game.talkPrivate(MessageModes.NpcTo,'Maia','missao')
        record:event('missionRequested')
        scheduleEvent(function()
            if done or not observeUi('seeking','accepted') then return end
            reachFragment()
        end,1600)
    end,1500)
end
connect(g_game,{
    onLoginError=function(message) record:error("onLoginError",message);finish("Login error; see timed events") end,
    onConnectionError=function(message) record:error("onConnectionError",message);finish("Connection error; see timed events") end,
    onGameEnd=function()
        result.state.connection="offline"
        record:event("onGameEnd")
        if not done then finish("Disconnected before mission completed") end
    end,
    onTalk=function(name,level,mode,message)
        if name=='Maia' then
            result.dialogue[#result.dialogue+1]=message
            record:event("npcDialogue",{speaker=name,message=message})
        end
    end,
    onTextMessage=function(mode,message)
        if message:find('recuperou a primeira memoria',1,true) then
            result.fragmentMessage=true
            record:event("fragmentMessage",{message=message})
        end
    end,
    onGameStart=function()
        result.state.connection="online"
        result.state.phase="mission"
        record:event("onGameStart",{player=g_game.getLocalPlayer():getName()})
        scheduleEvent(function()
            if done then return end
            local player=g_game.getLocalPlayer()
            if not player or player:getName()~='Explorador QA' then return finish('Unexpected test character') end
            result.character=player:getName()
            result.clientVersion=g_game.getClientVersion()
            result.experienceBefore=player:getExperience()
            record:event("initialExperience",{experience=result.experienceBefore})
            if result.experienceBefore~=0 then return finish("QA must start with zero experience") end
            if previewOnly then
                local p=position()
                if not p or p.x~=100 or p.y~=100 or p.z~=7 then return finish('QA preview must start at 100,100,7') end
                result.position={x=p.x,y=p.y,z=p.z}
                result.screenshot='ui-before-'..EntreVeusRunId..'.png'
                -- Screenshot reads the renderer asynchronously; keep the game visible
                -- long enough to draw and finish writing before logging out.
                scheduleEvent(function()
                    if done then return end
                    result.previewUi={gameVisible=modules.game_interface.getRootPanel():isVisible(),
                        mapVisible=modules.game_interface.getMapPanel():isVisible(),
                        windowVisible=g_window.isVisible(),windowFocused=g_window.hasFocus(),fps=g_app.getGraphicsFps()}
                    if not result.previewUi.gameVisible or not result.previewUi.mapVisible then return finish('Game UI was not visible for preview') end
                    if not observeUi('initial','preview') then return end
                    result.ui.checksPassed=true
                    record:event('initialUiCaptureRequested',{player=result.character,position=result.position,ui=result.previewUi})
                    g_app.doScreenshot(result.screenshot)
                    scheduleEvent(function() finish() end,5000)
                end,5000)
                return
            end
            for _,creature in pairs(g_map.getSpectators(position(),false)) do
                if creature:getName()=='Maia' then result.npcPresent=true end
            end
            if not result.npcPresent then return finish('Maia was not spawned near the plaza') end
            if not observeUi('initial','start') then return end
            result.ui.initialScreenshot='ui-inicial-'..EntreVeusRunId..'.png'
            record:save()
            g_app.doScreenshot(result.ui.initialScreenshot)
            scheduleEvent(beginMission,3000)
        end,5000)
    end
})
local http
scheduleEvent(function()
    if done then return end
    g_window.show()
    g_game.setClientVersion(1525)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(1525))
    g_game.chooseRsa('127.0.0.1')
    if not modules.game_things.isLoaded() then return finish('Assets failed to load') end
    result.assetsLoaded=true
    EnterGame.loginFailed=function(_,message)
        EntreVeusLauncherEvidence:error("httpLoginError",message)
        record:error("httpLoginError",message);finish("HTTP login failed; see timed events")
    end
    EnterGame.loginSuccess=function(_,session,worlds,characters)
        local s=json.decode(session)
        local world=json.decode(worlds)[1]
        local char=json.decode(characters)[1]
        if not char or char.name~="Explorador QA" then return finish("Unexpected QA character list") end
        G.account='ensaio';G.password=secrets.password;G.sessionKey=s.sessionkey;G.authenticatorToken=''
        result.formCredentialsMatch=G.account=='ensaio' and G.password==secrets.password
        EntreVeusLauncherEvidence.data.formCredentialsMatch=result.formCredentialsMatch
        EntreVeusLauncherEvidence:event("credentialsPrepared",{matches=result.formCredentialsMatch})
        record:event("characterListReceived",{character=char.name})
        EnterGame.hide()
        g_game.loginWorld(G.account,G.password,world.name,world.externaladdressprotected,world.externalportprotected,char.name,'',G.sessionKey)
    end
    result.state.connection="connecting"
    EntreVeusLauncherEvidence.data.state.connection="connecting"
    EntreVeusLauncherEvidence:event("loginRequested",{character="Explorador QA"})
    record:event("loginRequested")
    http=LoginHttp.create()
    http:httpLogin('127.0.0.1','/login',8090,'ensaio',secrets.password,1,true,'')
end,1800)
scheduleEvent(function() if not done then finish('Content test timed out') end end,90000)

