-- [ Universal Core Engine : Loader ]
-- !!! CHANGE THIS TO YOUR REPOSITORY URL !!!

local REPO_URL = "https://raw.githubusercontent.com/FZGecko/Loader/main/"

local ModuleCache = {}

local Loader = {}

--------------------------------------------------
-- INTERNAL IMPORT SYSTEM
--------------------------------------------------

local function Import(path)

    -- Cache hit
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    --------------------------------------------------
    -- Fetch module source
    --------------------------------------------------
    local url = REPO_URL .. path .. ".lua"

    local ok, response = pcall(game.HttpGet, game, url)
    if not ok or not response then
        error("[Loader] Failed to fetch module: " .. path)
    end

    local source = response

    -- Remove UTF-8 BOM
    source = source:gsub("^\239\187\191", "")

    --------------------------------------------------
    -- GitHub failure detection
    --------------------------------------------------
    -- GitHub returns HTML on:
    -- 404
    -- rate limit
    -- private repo
    if source:sub(1,1) == "<" then
        error("[Loader] GitHub returned HTML instead of Lua for: " .. path)
    end

    --------------------------------------------------
    -- Compile chunk
    --------------------------------------------------
    local chunk, loadErr = load(source, "@" .. path)

    if not chunk then
        error(
            "[Loader] Syntax Error in " .. path ..
            "\n----- SOURCE BEGIN -----\n" ..
            source ..
            "\n----- SOURCE END -----\n" ..
            tostring(loadErr)
        )
    end

    --------------------------------------------------
    -- Execute chunk
    --------------------------------------------------
    local success, factory = pcall(chunk)

    if not success then
        error("[Loader] Runtime error while executing module '" .. path .. "'\n" .. tostring(factory))
    end

    --------------------------------------------------
    -- Validate module format
    --------------------------------------------------
    if type(factory) ~= "function" then
        error(
            "[Loader] Module '" .. path ..
            "' must return a factory function:\n" ..
            "return function(import) ... end"
        )
    end

    --------------------------------------------------
    -- Create module instance
    --------------------------------------------------
    local module = factory(Import)

    if module == nil then
        error("[Loader] Module returned nil: " .. path)
    end

    --------------------------------------------------
    -- Cache result
    --------------------------------------------------
    ModuleCache[path] = module

    return module
end

--------------------------------------------------
-- PUBLIC LOADER API
--------------------------------------------------

Loader.Import = Import

function Loader.Unload()
    table.clear(ModuleCache)
end

return Loader
