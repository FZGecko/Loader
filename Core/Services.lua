return function(import)
    -- [ Optimization ] Localize globals
    local game = game
    local pcall = pcall
    
    local Services = {}
    local cache = {}
    
    -- Attempt to use cloneref for safety, fallback to standard identity
    local clone = cloneref or function(o) return o end

    function Services.Get(name)
        if cache[name] then return cache[name] end

        local success, service = pcall(game.GetService, game, name)
        
        -- Fallback 1: FindService (Stealthier check before brute-forcing)
        if not success or not service then
            pcall(function() service = game:FindService(name) end)
        end

        -- Fallback 2: Manual scan if GetService is hooked/blocked
        if not success or not service then
            for _, child in ipairs(game:GetChildren()) do
                if child.ClassName == name then
                    service = child
                    break
                end
            end
        end

        if service then
            local ref = clone(service)
            cache[name] = ref
            return ref
        end
        
        error("[Services] Critical: Could not find service " .. name)
    end

    return Services
end
