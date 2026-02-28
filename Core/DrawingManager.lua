return function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    
    -- [ Capability Check ]
    -- The 'Drawing' library is injected by the executor, not Roblox.
    local Drawing = Drawing
    local pcall = pcall
    local pairs = pairs

    if not Drawing then
        warn("[DrawingManager] Drawing API is not supported by this executor.")
        return {
            IsAvailable = false,
            Create = function() return nil end
        }
    end

    local DrawingManager = {
        IsAvailable = true,
        _janitor = Janitor.new()
    }

    -- [ Safe Creation ]
    function DrawingManager:Create(type, props)
        if not Kernel.IsActive then return nil end

        local success, obj = pcall(Drawing.new, type)
        if not success or not obj then return nil end

        -- [ Auto-Cleanup ]
        -- Drawing objects use .Remove(), not :Destroy().
        -- We wrap this in a function for the Janitor.
        DrawingManager._janitor:Add(function()
            pcall(function() obj:Remove() end)
        end)

        if props then
            for k, v in pairs(props) do
                pcall(function() obj[k] = v end)
            end
        end

        return obj
    end

    -- Link to Kernel Shutdown
    Kernel._janitor:Add(function()
        DrawingManager._janitor:Clean()
    end)

    return DrawingManager
end
