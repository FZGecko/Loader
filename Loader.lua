-- [ Universal Core Engine : Loader ]
-- !!! CHANGE THIS TO YOUR REPOSITORY URL !!!
local REPO_URL = "https://raw.githubusercontent.com/FZGecko/Loader/main/"

local Loader = {}
local Kernel -- Forward declaration
local ModuleCache = {}

-- Imports modules from the remote repository, handling caching and dependency injection.
local function Import(path)
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    -- 1. Fetch Module
    local url = REPO_URL .. path .. ".lua"
    local success, response = pcall(game.HttpGet, game, url)
    if not success then error(string.format("[Loader] HTTP Error: %s | Path: %s", tostring(response), path)) end
    
    -- 2. Compile Module
    local func, loadErr = loadstring(response, "@" .. path)
    if not func then error(string.format("[Loader] Compile Error: %s | Path: %s", tostring(loadErr), path)) end

    -- 3. Execute Module (and cache)
    local module
    local callSuccess, callResult = pcall(func)
    
    if callSuccess then
        -- Check that module returns factory function
        if type(callResult) == "function" then
            local factory = callResult
            local importSuccess, importResult = pcall(factory, Import)
    
            if importSuccess then
                 module = importResult
                 ModuleCache[path] = module
                 return module
            else
                error(string.format("[Loader] Factory Error: %s | Path: %s", tostring(importResult), path))
            end
        else
            error(string.format("[Loader] Module must return a factory function! | Path: %s", path))
        end
    else
        error(string.format("[Loader] Execute Error: %s | Path: %s", tostring(callResult), path))
    end
end

local function Start()
    Kernel = Import("Core/Kernel")
    local EntityManager = Import("Core/EntityManager")
    EntityManager.Init() -- Initialize the entity manager, or we will not see other players
end

-- Initialize engine
local Engine = {}

Engine.Start = Start
Engine.Import = Import
Engine.Unload = function()
    if Kernel then
        Kernel:Shutdown()
    end
    for k, v in pairs(ModuleCache) do
        ModuleCache[k] = nil
    end
end

return Engine
