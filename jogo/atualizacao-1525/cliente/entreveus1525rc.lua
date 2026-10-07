-- Local launcher and QA observer. Evidence is independent from login behavior.
local smoke = os.getenv("ENTREVEUS_SMOKE") == "1"
local contentSmoke = os.getenv("ENTREVEUS_CONTENT_SMOKE") == "1"
local play = os.getenv("ENTREVEUS_PLAY") == "1"
local header
connect(g_game, {
    onGameStart=function()
        if not header then header=g_ui.loadUI('/entreveus.otui',modules.game_interface.getMapPanel()) end
        header:show()
    end,
    onGameEnd=function() if header then header:hide() end end
})
if contentSmoke or play then
    EntreVeusEvidence = dofile('/evidence.lua')
    EntreVeusRunId = EntreVeusEvidence.runId()
    local expected = contentSmoke and "Explorador QA" or "Viajante"
    local mode = contentSmoke and "qa-observer" or "interactive"
    local record=EntreVeusEvidence.fileRecorder("launcher-login",{
        runId=EntreVeusRunId,test="launcher-login-observation",mode=mode,
        scope="login confirmed with character and position; not continuous connection health"
    })
    EntreVeusLauncherEvidence=record
    record.data.expectedCharacter=expected
    local epoch=0
    connect(g_game, {
        onGameStart=function()
            epoch=epoch+1
            local thisEpoch=epoch
            local player=g_game.getLocalPlayer()
            record.data.state.connection="online"
            record.data.state.phase="checking_login"
            record:event("onGameStart",{player=player and player:getName()})
            scheduleEvent(function()
                if epoch~=thisEpoch then
                    record:event("loginCheckSkipped",{reason="connection changed before confirmation"})
                    return
                end
                local current=g_game.getLocalPlayer()
                local pos=current and current:getPosition()
                record.data.character=current and current:getName()
                record.data.position=pos and {x=pos.x,y=pos.y,z=pos.z}
                record.data.clientVersion=g_game.getClientVersion()
                local passed=g_game.isOnline() and record.data.character==expected and pos~=nil
                record.data.state.phase=passed and "login_confirmed" or "login_not_confirmed"
                local reason
                if not passed then reason="Character/position not confirmed" end
                record:complete(passed,reason)
                if passed then
                    record.data.screenshot="launcher-login-" .. EntreVeusRunId .. ".png"
                    record:save()
                    g_app.doScreenshot(record.data.screenshot)
                end
            end,1200)
        end,
        onLoginError=function(message) record:error("onLoginError",message) end,
        onConnectionError=function(message) record:error("onConnectionError",message) end,
        onGameEnd=function()
            epoch=epoch+1
            record.data.state.connection="offline"
            record:event("onGameEnd")
        end
    })
end
if contentSmoke then dofile('/content-smoke.lua');return end
if not smoke and not play then return end
local runtime = os.getenv("LOCALAPPDATA"):gsub("\\", "/") .. "/EntreVeus1525"
local secretFile = assert(io.open(runtime .. "/credentials.json", "r"))
local secrets = json.decode(secretFile:read("*a")); secretFile:close()
if not smoke then
    local record=EntreVeusLauncherEvidence
    -- Use the ordinary form and character list; preserve existing automatic login.
    local createCharacterList=CharacterList.create
    CharacterList.create=function(characters,account,otui)
        createCharacterList(characters,account,otui)
        if #characters==1 and characters[1].name=="Viajante" then
            CharacterList.create=createCharacterList
            scheduleEvent(function() CharacterList.doLogin() end,300)
        end
    end
    scheduleEvent(function()
        -- These upstream setters accept encrypted stored values, not plaintext.
        EnterGame.setAccountName(g_crypt.encrypt(secrets.account))
        EnterGame.setPassword(g_crypt.encrypt(secrets.password))
        g_window.show()
        if not g_game.isOnline() and not g_game.isLogging() then
            record.data.state.connection="connecting"
            record:event("loginRequested")
            EnterGame.doLogin()
        end
        record.data.formCredentialsMatch=G.account==secrets.account and G.password==secrets.password
        record:event("credentialsPrepared",{matches=record.data.formCredentialsMatch})
    end,1800)
    return
end
local result = { test = "native-client-login-move-reconnect", protocol = 1525, entries = {}, success = false }
local loginCount = 0
local finished = false
local expectedPosition
local function save()
    local f=assert(io.open(runtime .. "/client-smoke.json", "w"));f:write(json.encode(result));f:close()
end
local function fail(message)
    if finished then return end
    finished=true;result.error=tostring(message);save()
    g_logger.error("ENTREVEUS_SMOKE: " .. tostring(message))
    g_app.doScreenshot("client-smoke.png")
    if g_game.isOnline() then g_game.safeLogout() end
    scheduleEvent(function() g_app.exit() end, 500)
end
local http
local function login()
    EnterGame.loginFailed=function(_,message) fail(message) end
    EnterGame.loginSuccess=function(_,session,worlds,characters)
        local response={session=json.decode(session),playdata={worlds=json.decode(worlds),characters=json.decode(characters)}}
        G.sessionKey=response.session.sessionkey
        result.characterListReceived=true
        local character=response.playdata.characters[1]
        local world=response.playdata.worlds[1]
        if not character then return fail("No character returned") end
        G.account=secrets.account;G.password=secrets.password;G.authenticatorToken=""
        EnterGame.hide()
        scheduleEvent(function()
            g_game.loginWorld(secrets.account,secrets.password,world.name,world.externaladdressprotected,world.externalportprotected,character.name,"",G.sessionKey)
        end,500)
    end
    http=LoginHttp.create()
    http:httpLogin("127.0.0.1","/login",8090,secrets.account,secrets.password,1,true,"")
end
connect(g_game, {
    onTextMessage=function(mode,message) result.lastMessage=message end,
    onLoginError=function(message) fail(message) end,
    onConnectionError=function(message) fail(message) end,
    onGameStart=function()
      scheduleEvent(function()
        loginCount=loginCount+1
        local player=g_game.getLocalPlayer()
        local position=player:getPosition()
        if not position then return fail("Map position unavailable after login") end
        result.entries[loginCount]={x=position.x,y=position.y,z=position.z}
        if loginCount==1 then
            expectedPosition={x=position.x+1,y=position.y,z=position.z}
            scheduleEvent(function() result.walkAccepted=g_game.walk(East) end,800)
            scheduleEvent(function()
                local p=player:getPosition()
                result.moved={x=p.x,y=p.y,z=p.z}
                if p.x~=expectedPosition.x or p.y~=expectedPosition.y then return fail("Movement not confirmed") end
                result.screenshot=g_resources.getWriteDir() .. "client-smoke.png"
                g_app.doScreenshot("client-smoke.png")
                save();scheduleEvent(function() g_game.safeLogout() end,700)
            end,2600)
        else
            result.positionPersisted=position.x==expectedPosition.x and position.y==expectedPosition.y and position.z==expectedPosition.z
            result.success=result.positionPersisted
            finished=true;save()
            scheduleEvent(function() g_game.safeLogout() end,800)
            scheduleEvent(function() g_app.exit() end,2500)
        end
      end,750)
    end,
    onGameEnd=function()
        if not finished and loginCount==1 then scheduleEvent(login,2000) end
    end
})
scheduleEvent(function()
    save()
    g_window.show()
    g_game.setClientVersion(1525)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(1525))
    g_game.chooseRsa("127.0.0.1")
    if not modules.game_things.isLoaded() then return fail("Generated client assets failed to load") end
    result.assetsLoaded=true;login()
end,1800)
scheduleEvent(function() if not finished then fail("Timed out after 40 seconds") end end,40000)
