-- [ Bootstrap / Loader.lua ]
-- The only file the user executes.

local Repo = "https://raw.githubusercontent.com/YourUser/YourRepo/main/"

local Cache = {}

-- The Magic Function: Custom Require
local function Import(path)
    if Cache[path] then return Cache[path] end

    local url = Repo .. path .. ".lua"
    print("[Bootstrap] Fetching: " .. path)
    
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        error("[Bootstrap] Failed to fetch " .. path .. ": " .. tostring(result))
    end

    -- Compile the string into a function
    local func, loadErr = loadstring(result)
    if not func then
        error("[Bootstrap] Syntax error in " .. path .. ": " .. tostring(loadErr))
    end

    -- Execute the module. 
    -- CRITICAL: We pass the 'Import' function TO the module so it can load its own dependencies.
    local module = func(Import)
    
    Cache[path] = module
    return module
end

-- Initialize the Engine
local function Boot()
    getgenv().UniversalEngine = {} -- Optional: Global access if needed
    
    -- Load the Kernel. The Kernel will use 'Import' to load Maid and Services.
    local Kernel = Import("Core/Kernel")
    local EntityManager = Import("Core/EntityManager")
    
    print("[Bootstrap] Engine Loaded Successfully.")
    
    -- Example: Start a feature
    -- local ESP = Import("Features/ESP")
    -- ESP.Init()
end

Boot()
