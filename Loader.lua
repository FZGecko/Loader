-- [ Universal Core Engine : Loader ]
-- [ Stealth ] Generate a unique, random key for the global environment.
local ENV_KEY = ("UniversalCore_" .. tostring(math.random(1e5, 1e6))):gsub("%.", "")

-- [ Guard ] Unload any previous instance before loading.
-- If the engine is already running, unload it before loading the new one.
local old_env = getgenv()[ENV_KEY]
if old_env then
    if type(old_env.Unload) == "function" then
        pcall(old_env.Unload)
    end
    getgenv()[ENV_KEY] = nil
end

-- !!! CHANGE THIS TO YOUR REPOSITORY URL !!!
local REPO_URL = "https://raw.githubusercontent.com/FZGecko/Loader/refs/heads/main/Loader.lua"

local Loader = {}
local ModuleCache = {}

-- Imports modules from the remote repository, handling caching and dependency injection.
local function Import(path)
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    local url = REPO_URL .. path .. ".lua"
    local success, response = pcall(game.HttpGet, game, url)
    if not success then
        error("[Loader] Failed to fetch module: " .. path .. " | Error: " .. tostring(response))
    end

    local func, loadErr = loadstring(response)
    if not func then
        error("[Loader] Syntax Error in " .. path .. ": " .. tostring(loadErr))
    end

    local module = func(Import)
    ModuleCache[path] = module
    return module
end

local function Boot()
    local Kernel = Import("Core/Kernel")
    local EntityManager = Import("Core/EntityManager")
    EntityManager.Init()

    -- Expose Control
    getgenv()[ENV_KEY] = {
        Unload = function()
            Kernel:Shutdown()
            getgenv()[ENV_KEY] = nil
            ModuleCache = nil
        end
    }
end

Boot()
