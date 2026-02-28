-- [ Core/Services.lua ]
-- Provides stealthy and resilient access to Roblox services.

return function(import)
    local Services = {}
    local cache = {}

    -- Use cloneref if the executor supports it. This creates a "shadow" reference
    -- that can bypass some anti-cheat checks. If not, it gracefully falls back.
    local clone = cloneref or function(v) return v end

    function Services.Get(serviceName)
        if cache[serviceName] then
            return cache[serviceName]
        end

        local success, service = pcall(game.GetService, game, serviceName)

        if not success or not service then
            -- FALLBACK: If GetService is hooked, renamed, or fails, we scan manually.
            -- This is your plan B. A good engine always has a plan B.
            warn("[Services] GetService failed for " .. serviceName .. ". Using fallback scan.")
            for _, child in ipairs(game:GetChildren()) do
                if child.ClassName == serviceName then
                    service = child
                    break
                end
            end
        end

        if service then
            local ref = clone(service)
            cache[serviceName] = ref
            return ref
        end

        -- If we still can't find it, the engine is dead in the water. Fail loudly.
        error("[Services] CRITICAL FAILURE: Could not locate service '" .. serviceName .. "'. Engine cannot continue.")
    end

    return Services
end
