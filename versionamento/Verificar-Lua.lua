-- Syntax and pure recorder regression only: no OTClient, network or database.
for _, path in ipairs(arg) do
    local chunk, message = loadfile(path)
    assert(chunk, path .. ": " .. tostring(message))
end
local evidence = assert(loadfile("jogo/atualizacao-1525/cliente/evidence.lua"))()
local test = assert(loadfile("jogo/atualizacao-1525/cliente/evidence-tests.lua"))()
local result = test(evidence)
assert(result.passed and #result.checks == 5, "Recorder regression failed")
print("PASS: Lua syntax and five synthetic recorder checks; no gameplay executed.")
