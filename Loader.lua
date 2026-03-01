-- [ Universal Core Engine : Loader ]
-- !!! CHANGE THIS TO YOUR REPOSITORY URL !!!

local REPO_URL = "https://raw.githubusercontent.com/FZGecko/Loader/main/"

local Loader = {}
local ModuleCache = {}

--------------------------------------------------
-- INTERNAL IMPORT SYSTEM
--------------------------------------------------

local function Import(path)

    --------------------------------------------------
    -- Cache check
    --------------------------------------------------
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    --------------------------------------------------
    -- Fetch module
    --------------------------------------------------
    local url = REPO_URL .. path .. ".lua"

    local success, response = pcall(game.HttpGet, game, url)
    if not success or not response then
        error("[Loader] Failed to fetch module: " .. path)
    end

    local source = response

    --------------------------------------------------
    -- Remove UTF-8 BOM
    --------------------------------------------------
    source = source:gsub("^\239\187\191", "")

    --------------------------------------------------
    -- GitHub HTML protection
    --------------------------------------------------
    if source:sub(1,1) == "<" then
        error("[Loader] GitHub returned HTML instead of Lua for: " .. path)
    end

    --------------------------------------------------
    -- Compile module
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
    local ok, result = pcall(chunk)
    print("[Loader] Executing:", path)

    if not ok then
        error("[Loader] Runtime error while executing module '" .. path .. "'\n" .. tostring(result))
    end

    --------------------------------------------------
    -- Validate factory return
    --------------------------------------------------
    if type(result) ~= "function" then
        error(
            "[Loader] Module '" .. path .. "' must return:\n" ..
            "return function(import)\n" ..
            "Got: " .. typeof(result)
        )
    end

    --------------------------------------------------
    -- Create module instance
    --------------------------------------------------
    local module = result(Import)
    print("[Loader] Module '" .. path .. "' result:", module)

    if module == nil then
        error("[Loader] Module returned nil: " .. path)
    end

    --------------------------------------------------
    -- Cache module
    --------------------------------------------------
    ModuleCache[path] = module

    return module
end

--------------------------------------------------
-- PUBLIC API
--------------------------------------------------

Loader.Import = Import

function Loader.Unload()
    table.clear(ModuleCache)
end

return Loader
