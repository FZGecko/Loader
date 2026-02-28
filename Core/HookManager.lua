return function(import)
    local Kernel = import("Core/Kernel")
    
    -- [ Optimization ] Localize globals
    local getnamecallmethod = getnamecallmethod
    local checkcaller = checkcaller
    local hookmetamethod = hookmetamethod
    local newcclosure = newcclosure
    local pcall = pcall
    local pairs = pairs
    local table_insert = table.insert
    
    -- [ Capability Check ]
    if not hookmetamethod then
        warn("[HookManager] 'hookmetamethod' is missing. Hooking disabled.")
        return {
            HookNamecall = function() end,
            HookIndex = function() end,
            HookNewIndex = function() end
        }
    end

    local HookManager = {
        _registry = {
            namecall = {},
            index = {},
            newindex = {},
            modules = {} -- For monkey patching
        },
        _originals = {}
    }

    -- [ Master Hooks ]
    -- These act as traffic controllers. They decide if a call should be intercepted.
    
    local function MasterNamecall(self, ...)
        -- 1. Safety: If engine is dead or call is from our thread, pass through.
        if not Kernel.IsActive or checkcaller() then 
            return HookManager._originals.namecall(self, ...) 
        end
        
        local method = getnamecallmethod()
        local callbacks = HookManager._registry.namecall[method]
        
        if callbacks then
            for _, cb in pairs(callbacks) do
                -- 2. Protection: Wrap user logic in pcall.
                -- Protocol: Callback returns (shouldOverride, ...values)
                local success, override, res1, res2, res3, res4 = pcall(cb, self, ...)
                
                if not success then
                    warn("[HookManager] Error in Namecall hook '" .. tostring(method) .. "':", override)
                elseif override then
                    return res1, res2, res3, res4
                end
            end
        end
        
        return HookManager._originals.namecall(self, ...)
    end

    local function MasterIndex(self, key)
        if not Kernel.IsActive or checkcaller() then 
            return HookManager._originals.index(self, key) 
        end

        local callbacks = HookManager._registry.index[key]
        if callbacks then
            for _, cb in pairs(callbacks) do
                local success, override, result = pcall(cb, self, key)
                if not success then
                    warn("[HookManager] Error in Index hook '" .. tostring(key) .. "':", override)
                elseif override then
                    return result
                end
            end
        end

        return HookManager._originals.index(self, key)
    end

    local function MasterNewIndex(self, key, value)
        if not Kernel.IsActive or checkcaller() then
            return HookManager._originals.newindex(self, key, value)
        end

        local callbacks = HookManager._registry.newindex[key]
        if callbacks then
            for _, cb in pairs(callbacks) do
                -- Protocol: Callback returns (shouldOverride, [newValue])
                local success, override, result = pcall(cb, self, key, value)
                if not success then
                    warn("[HookManager] Error in NewIndex hook '" .. tostring(key) .. "':", override)
                elseif override then
                    return HookManager._originals.newindex(self, key, result) -- Use the new value
                end
            end
        end
        return HookManager._originals.newindex(self, key, value)
    end

    -- [ Public API ]

    function HookManager:HookNamecall(methodName, callback)
        -- Lazy Install: Only hook __namecall if we haven't yet.
        if not self._originals.namecall then
            local old = hookmetamethod(game, "__namecall", newcclosure(MasterNamecall))
            self._originals.namecall = old
        end

        self._registry.namecall[methodName] = self._registry.namecall[methodName] or {}
        table_insert(self._registry.namecall[methodName], callback)
    end

    function HookManager:HookIndex(propertyName, callback)
        if not self._originals.index then
            local old = hookmetamethod(game, "__index", newcclosure(MasterIndex))
            self._originals.index = old
        end

        self._registry.index[propertyName] = self._registry.index[propertyName] or {}
        table_insert(self._registry.index[propertyName], callback)
    end

    function HookManager:HookNewIndex(propertyName, callback)
        if not self._originals.newindex then
            local old = hookmetamethod(game, "__newindex", newcclosure(MasterNewIndex))
            self._originals.newindex = old
        end

        self._registry.newindex[propertyName] = self._registry.newindex[propertyName] or {}
        table_insert(self._registry.newindex[propertyName], callback)
    end

    -- Safely hooks a function on a ModuleScript's returned table.
    function HookManager:HookModuleFunction(module, functionName, callback)
        local originalFunc = module[functionName]
        if type(originalFunc) ~= "function" then
            warn("[HookManager] Cannot hook '" .. tostring(functionName) .. "'. Not a function on the provided module.")
            return
        end

        -- Replace the function with our wrapper
        module[functionName] = function(...)
            return callback(originalFunc, ...)
        end

        table_insert(self._registry.modules, { module, functionName, originalFunc })
    end

    -- [ Reversal ]
    function HookManager:Restore()
        if self._originals.namecall then
            hookmetamethod(game, "__namecall", self._originals.namecall)
            self._originals.namecall = nil
        end
        if self._originals.index then
            hookmetamethod(game, "__index", self._originals.index)
            self._originals.index = nil
        end
        if self._originals.newindex then
            hookmetamethod(game, "__newindex", self._originals.newindex)
            self._originals.newindex = nil
        end

        -- Restore all monkey-patched module functions
        for _, data in pairs(self._registry.modules) do
            data[1][data[2]] = data[3] -- module[functionName] = originalFunc
        end

        -- Clear registry to ensure no lingering references
        self._registry.namecall = {}
        self._registry.index = {}
        self._registry.newindex = {}
        self._registry.modules = {}
    end

    -- [ Auto-Cleanup ]
    -- Register our restoration logic with the Kernel's Janitor.
    Kernel._janitor:Add(function()
        HookManager:Restore()
    end)

    return HookManager
end
