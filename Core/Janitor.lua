-- [ Core/Janitor.lua ]
-- Even if it has no dependencies, keep the structure consistent.

return function(import)
    local Maid = {}
    Maid.__index = Maid

    function Maid.new()
        return setmetatable({ _tasks = {} }, Maid)
    end

    function Maid:Destroy()
        -- Cleanup logic...
        print("Maid cleaning up...")
    end

    return Maid
end
