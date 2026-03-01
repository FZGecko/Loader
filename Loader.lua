-- [ Universal Core Engine : Loader ]
-- !!! CHANGE THIS TO YOUR REPOSITORY URL !!!

local REPO_URL = "https://raw.githubusercontent.com/FZGecko/Loader/main/"

local Loader = {}

-- Loaded modules
local ModuleCache = {}

-- Modules currently loading (prevents circular crashes)
local LoadingModules = {}

--------------------------------------------------
-- INTERNAL IMPORT SYSTEM
--------------------------------------------------

local function Import(path)

    --------------------------------------------------
    -- Cache hit
    --------------------------------------------------
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    --------------------------------------------------
    -- Circular dependency protection
    --------------------------------------------------
    if LoadingModules[path] then
        error("[Loader] Circular dependency detected while loading: " .. path)
    end

    LoadingModules[path] = true

    --------------------------------------------------
    -- Fetch module source
    --------------------------------------------------
    local url = REPO_URL .. path .. ".lua"

    local success, response = pcall(game.HttpGet, game, url)
    if not success or not response then
        LoadingModules[path] = nil
        error("[Loader] Failed to fetch module: " .. path)
    end

    local source = response

    --------------------------------------------------
    -- Remove UTF-8 BOM
    --------------------------------------------------
    source = source:gsub("^\239\187\191", "")

    --------------------------------------------------
    -- GitHub returned HTML instead of Lua
    --------------------------------------------------
    if source:sub(1,1) == "<" then
        LoadingModules[path] = nil
        error("[Loader] GitHub returned HTML instead of Lua for: " .. path)
    end

    --------------------------------------------------
    -- Compile module
    --------------------------------------------------
    local chunk, loadErr = load(source, "@" .. path)

    if not chunk then
        LoadingModules[path] = nil
        error(
            "[Loader] Syntax Error in " .. path ..
            "\n----- SOURCE BEGIN -----\n" ..
            source ..
            "\n----- SOURCE END -----\n" ..
            tostring(loadErr)
        )
    end

    --------------------------------------------------
    -- Execute module chunk
    --------------------------------------------------
    local ok, result = pcall(chunk)

    if not ok then
        LoadingModules[path] = nil
        error("[Loader] Runtime error while executing module '" .. path .. "'\n" .. tostring(result))
    end

    --------------------------------------------------
    -- Validate module contract
    --------------------------------------------------
    if result == nil then
        LoadingModules[path] = nil
        error(
            "[Loader] Module '" .. path .. "' returned nil.\n" ..
            "Expected:\nreturn function(import)"
        )
    end

    if type(result) ~= "function" then
        LoadingModules[path] = nil
        error(
            "[Loader] Module '" .. path .. "' must return a factory function.\n" ..
            "Got: " .. typeof(result)
        )
    end

    --------------------------------------------------
    -- Create module instance (SAFE CALL)
    --------------------------------------------------
    local ok2, module = pcall(result, Import)

    if not ok2 then
        LoadingModules[path] = nil
        error("[Loader] Error initializing module '" .. path .. "'\n" .. tostring(module))
    end

    if module == nil then
        LoadingModules[path] = nil
        error("[Loader] Module returned nil after initialization: " .. path)
    end

    --------------------------------------------------
    -- Cache module
    --------------------------------------------------
    ModuleCache[path] = module
    LoadingModules[path] = nil

    return module
end

--------------------------------------------------
-- PUBLIC API
--------------------------------------------------

Loader.Import = Import

function Loader.Unload()
    table.clear(ModuleCache)
    table.clear(LoadingModules)
end

return Loader
