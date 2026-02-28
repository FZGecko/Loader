-- [ Universal Core Engine : Loader ]
-- !!! CHANGE THIS TO YOUR REPOSITORY URL !!!
local REPO_URL = "https://raw.githubusercontent.com/FZGecko/Loader/main/"

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

    -- [ DEBUG ] Print the raw content to check for corruption/caching issues.
    print("--- CONTENT OF " .. path .. " ---")
    print(response)
    print("--------------------------")

    local func, loadErr = loadstring(response)
    if not func then
        error("[Loader] Syntax Error in " .. path .. ": " .. tostring(loadErr))
    end

    -- The first call `func()` executes the chunk and returns the factory function.
    -- The second call `(Import)` invokes the factory with the dependency.
    local module = func()(Import)
    ModuleCache[path] = module
    return module
end

local function Boot()
    local Kernel = Import("Core/Kernel")
    local EntityManager = Import("Core/EntityManager")
    EntityManager.Init()
    
    -- Return the engine interface directly to the caller.
    return {
        Kernel = Kernel,
        Import = Import,
        Unload = function()
            Kernel:Shutdown()
            ModuleCache = nil
        end
    }
end

return Boot()
