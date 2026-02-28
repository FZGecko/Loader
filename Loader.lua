-- [ Loader.lua ]
-- The single entry point for the Universal Core Engine.
-- It fetches, compiles, and links all modules from a remote source.

-- ============================ CONFIGURATION ============================
-- This is the ONLY place you should ever define a URL.
local REPO_URL = "https://raw.githubusercontent.com/YourUser/YourRepo/main/"
-- =======================================================================

local ModuleCache = {}

-- The custom import function. This is the heart of the loader.
local function Import(path)
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    local url = REPO_URL .. path .. ".lua"
    print("[Loader] Importing: " .. path)
    
    local success, content = pcall(game.HttpGet, game, url)
    if not success or not content then
        error("[Loader] FATAL: Failed to download module at " .. url .. ". " .. tostring(content))
    end

    -- Compile the downloaded string into a Lua function.
    local func, compile_error = loadstring(content)
    if not func then
        error("[Loader] FATAL: Syntax error in module '" .. path .. "'. " .. tostring(compile_error))
    end

    -- Execute the module, passing it the Import function so it can load its own dependencies.
    -- This is called Dependency Injection.
    local module = func(Import)
    
    ModuleCache[path] = module
    return module
end

-- The main boot sequence.
local function Boot()
    print("[Loader] Boot sequence initiated.")
    
    -- Import the Kernel. The Kernel will then import its own dependencies (Scope, Services).
    local Kernel = Import("Core/Kernel")
    
    -- Make the Kernel and its shutdown function globally accessible for control.
    getgenv().UniversalCore = {
        Kernel = Kernel,
        Shutdown = function()
            Kernel:Shutdown()
            getgenv().UniversalCore = nil -- Clean up the global table itself.
        end
    }
    
    print("[Loader] Universal Core Engine is active. Call UniversalCore.Shutdown() to unload.")

    -- From here, you would load your features.
    -- Example:
    -- local ESP = Import("Features/ESP")
    -- ESP:Run(Kernel)
end

-- Run the bootstrapper.
pcall(Boot)
