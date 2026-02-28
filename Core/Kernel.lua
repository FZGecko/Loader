-- [ Core/Kernel.lua ]
-- The central API gateway for the engine.
-- All features must interact with the game through the Kernel.

return function(import)
    -- Dependency Injection: The Kernel asks the loader for the tools it needs.
    local Janitor = import("Core/Janitor")
    local Services = import("Core/Services")

    local Kernel = {
        IsActive = true,
        _masterJanitor = Janitor.new(),
        _propertySnapshots = {},
    }

    -- Safe Instance Creation, tracked by the Janitor.
    function Kernel:Create(className, properties)
        if not self.IsActive then return nil end
        local instance = Instance.new(className)
        self._masterJanitor:Add(instance) -- Give the new instance to the Janitor.

        if properties then
            for prop, value in pairs(properties) do
                pcall(function() instance[prop] = value end)
            end
        end
        return instance
    end

    -- Safe Event Connection, tracked by the Janitor.
    function Kernel:Connect(signal, callback)
        if not self.IsActive then return nil end
        local connection = signal:Connect(function(...)
            if not self.IsActive then return end
            pcall(callback, ...) -- Protect the engine from feature script errors.
        end)
        self._masterJanitor:Add(connection) -- Give the new connection to the Janitor.
        return connection
    end

    -- Safe Property Modification with Restoration.
    function Kernel:SetProperty(instance, property, newValue)
        if not self.IsActive then return end
        self._propertySnapshots[instance] = self._propertySnapshots[instance] or {}
        if self._propertySnapshots[instance][property] == nil then
            self._propertySnapshots[instance][property] = instance[property]
        end
        instance[property] = newValue
    end

    -- The "Zero Footprint" Kill Switch.
    function Kernel:Shutdown()
        if not self.IsActive then return end
        self.IsActive = false
        print("[Kernel] Shutdown initiated. Reverting and cleaning...")

        -- 1. Restore properties.
        for instance, props in pairs(self._propertySnapshots) do
            if instance and instance.Parent then
                for prop, originalValue in pairs(props) do
                    pcall(function() instance[prop] = originalValue end)
                end
            end
        end

        -- 2. Tell the master Janitor to clean everything.
        self._masterJanitor:Clean()

        -- 3. Clear internal state.
        self._propertySnapshots = {}
        print("[Kernel] Zero Footprint achieved. Engine is clean.")
    end

    return Kernel
end
