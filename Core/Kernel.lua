return function(import)
    -- Localize globals for performance
    local pcall, pairs, type = pcall, pairs, type
    local Instance_new, math_random, string_char = Instance.new, math.random, string.char

    local Janitor = import("Core/Janitor")
    local Services = import("Core/Services")

    local Kernel = {
        IsActive = true,
        _janitor = Janitor.new(),
        _snapshots = {}
    }

    -- Generates a random, meaningless string for instance names to avoid detection.
    local function GenerateRandomName()
        local name = "uCE_"
        for i = 1, 6 do
            name = name .. string_char(math_random(97, 122)) -- a-z
        end
        return name
    end

    --// API: Creation
    function Kernel:Create(className, props)
        if not self.IsActive then return end
        
        local success, instance = pcall(Instance_new, className)
        if not success or not instance then return nil end
        
        self._janitor:Add(instance)

        if props then
            -- Optimization: Set Parent last to avoid redundant rendering/physics calculations.
            local parent = props.Parent
            props.Parent = nil

            -- Stealth: If no name is provided, generate a random one.
            if props.Name == nil or props.Name == "" then
                props.Name = GenerateRandomName()
            end
            
            for k, v in pairs(props) do
                pcall(function() instance[k] = v end)
            end
            
            if parent then
                pcall(function() instance.Parent = parent end)
            end
        end
        return instance
    end

    --// API: Events
    function Kernel:Connect(signal, callback)
        if not self.IsActive then return end
        
        local connection = signal:Connect(function(...)
            if not self.IsActive then return end
            -- Safety: pcall isolates errors, preventing one feature from crashing the engine.
            local s, e = pcall(callback, ...)
            if not s then warn("[Kernel] Error:", e) end
        end)
        
        self._janitor:Add(connection)
        return connection
    end

    --// API: State Management
    function Kernel:SetProperty(instance, prop, value)
        if not self.IsActive then return end
        
        self._snapshots[instance] = self._snapshots[instance] or {}
        -- Snapshot the original value on first modification for later restoration.
        if self._snapshots[instance][prop] == nil then
            self._snapshots[instance][prop] = instance[prop]
        end
        
        instance[prop] = value
    end

    --// Lifecycle
    function Kernel:Shutdown()
        if not self.IsActive then return end
        self.IsActive = false
        
        -- 1. Revert Properties
        for inst, props in pairs(self._snapshots) do
            if inst and inst.Parent then
                for p, val in pairs(props) do
                    pcall(function() inst[p] = val end)
                end
            end
        end
        
        -- 2. Clean Objects
        self._janitor:Clean()
        
        -- 3. Clear Memory
        self._snapshots = {}
    end

    return Kernel
end
