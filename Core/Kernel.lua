-- [ Core/Kernel.lua ]
-- Note: We wrap the whole module in a function that accepts 'import'

return function(import)
    -- Dependency Injection: We ask the loader for what we need.
    local MaidClass = import("Core/Maid")
    local Services = import("Core/Services")

    local Kernel = {
        _maid = MaidClass.new(), -- Using the imported Maid
        IsActive = true
    }

    function Kernel:Init()
        print("Kernel Initialized via Dependency Injection")
    end

    function Kernel:Shutdown()
        self._maid:Destroy()
        print("Kernel Shutdown")
    end

    return Kernel
end
