-- [ Universal Core Engine : Loader ]
-- !!! CHANGE THIS TO YOUR REPOSITORY URL !!!
local REPO_URL = "https://raw.githubusercontent.com/FZGecko/Loader/main/"

local Loader = {}

-- Imports modules from the remote repository, handling caching and dependency injection.
local function Import(path)
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    local url = REPO_URL .. path .. ".lua"
    local success, response = pcall(game.HttpGet, game, url)
    if not success then
        error("[Loader] Failed to fetch module: " .. path .. " | Error: " .. (response or "Unknown error"))
    end

    local source = response
    source = source:gsub("^\239\187\191", "") -- Remove BOM

    local func, loadErr = loadstring(source, "@" .. path)
    if not func then
        error("[Loader] Syntax Error in " .. path .. ": " .. tostring(loadErr))
    end

    -- The first call `func()` executes the chunk and returns the factory function.
    -- The second call `(Import)` invokes the factory with the dependency.
    local module, err = pcall(func)
    if not module then
        error("[Loader] Error running module: " .. path .. " | Error: " .. (err or "Unknown error"))
    end
    module = module(Import)
    ModuleCache[path] = module
    return module
end
    
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
