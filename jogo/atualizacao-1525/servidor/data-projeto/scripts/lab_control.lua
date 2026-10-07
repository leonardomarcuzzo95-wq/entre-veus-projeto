-- Local-only graceful shutdown trigger for the development lab, 2026-10-02.
local control = GlobalEvent("EntreVeus1525LabControl")
local localPath = os.getenv("LOCALAPPDATA")
if not localPath then return end
local request = localPath:gsub("\\", "/") .. "/EntreVeus1525/shutdown.request"
function control.onThink()
    local file = io.open(request, "r")
    if not file then return true end
    file:close()
    if #Game.getPlayers() > 0 then return true end
    os.remove(request)
    Game.setGameState(GAME_STATE_SHUTDOWN)
    return true
end
control:interval(1000)
control:register()
