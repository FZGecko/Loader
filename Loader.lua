-- [ Universal Core Engine : Loader ]
-- The entry point. Handles remote fetching and dependency injection.

local REPO_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/" -- CHANGE THIS!

local Loader = {}
local ModuleCache = {}

--// The Import Function (The Heart of the System)
-- This function is passed to every module so they can request other modules.
local function Import(path)
    -- 1. Check Cache (Speed Optimization)
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    -- 2. Fetch Source (Network Layer)
    local url = REPO_URL .. path .. ".lua"
    -- print("[Loader] Fetching: " .. path) -- Debug only. Remove for stealth.

    local success, response = pcall(game.HttpGet, game, url)
    if not success then
        error("[Loader] Failed to fetch module: " .. path .. " | Error: " .. tostring(response))
    end

    -- 3. Compile (Execution Layer)
    local func, loadErr = loadstring(response)
    if not func then
        error("[Loader] Syntax Error in " .. path .. ": " .. tostring(loadErr))
    end

    -- 4. Inject Dependencies (The Magic)
    -- We call the loaded function and pass 'Import' to it.
    -- This allows the module to load its own dependencies without knowing the URL.
    local module = func(Import)

    -- 5. Cache and Return
    ModuleCache[path] = module
    return module
end

--// Boot Sequence
local function Boot()
    -- Load the Kernel. The Kernel will use 'Import' to load Janitor/Services.
    local Kernel = Import("Core/Kernel")
    
    -- Initialize Managers
    local EntityManager = Import("Core/EntityManager")
    EntityManager.Init()

    -- Expose Control (Optional, for debugging or user commands)
    getgenv().UniversalCore = {
        Unload = function()
            Kernel:Shutdown()
            getgenv().UniversalCore = nil
            ModuleCache = nil
        end
    }

    print("[Loader] Engine Loaded. Waiting for input.")
end

--// Execute
Boot()
