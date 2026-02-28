return function(import)
    local Kernel = import("Core/Kernel")
    local Services = import("Core/Services")
    local RunService = Services.Get("RunService")

    -- [ Optimization ] Localize globals
    local pairs = pairs
    local pcall = pcall
    local os_clock = os.clock
    local tostring = tostring

    local LoopManager = {
        _loops = {
            Render = {},
            Heartbeat = {},
            Stepped = {}
        },
        _timers = {}
    }

    -- [ Master Loop Handler ]
    local function RunLoop(registry, ...)
        for name, callback in pairs(registry) do
            -- Isolate errors per feature so one crash doesn't kill all loops
            local success, err = pcall(callback, ...)
            if not success then
                warn("[LoopManager] Error in '" .. tostring(name) .. "':", err)
            end
        end
    end

    -- [ Master Connections ]
    -- We use Kernel:Connect so these master loops are automatically cleaned up on shutdown.
    -- We pass '...' (deltaTime) down to the features.
    
    Kernel:Connect(RunService.RenderStepped, function(...)
        RunLoop(LoopManager._loops.Render, ...)
    end)

    Kernel:Connect(RunService.Heartbeat, function(...)
        RunLoop(LoopManager._loops.Heartbeat, ...)

        -- Process Timers (Throttled Updates)
        -- Timers run on Heartbeat because it's post-physics, ideal for logic checks.
        local now = os_clock()
        for name, timer in pairs(LoopManager._timers) do
            if (now - timer.LastRun) >= timer.Interval then
                timer.LastRun = now
                local success, err = pcall(timer.Callback)
                if not success then
                    warn("[LoopManager] Timer Error '" .. tostring(name) .. "':", err)
                end
            end
        end
    end)

    Kernel:Connect(RunService.Stepped, function(...)
        RunLoop(LoopManager._loops.Stepped, ...)
    end)

    -- [ Public API ]

    -- Binds a function to a specific RunService event.
    -- type: "Render", "Heartbeat", "Stepped"
    function LoopManager:Bind(name, loopType, callback)
        local registry = self._loops[loopType]
        if registry then
            registry[name] = callback
        else
            warn("[LoopManager] Invalid loop type: " .. tostring(loopType))
        end
    end

    -- Binds a function to run at a specific interval (in seconds).
    -- Useful for heavy checks (e.g., finding nearest player) that don't need to run every frame.
    function LoopManager:BindTimer(name, interval, callback)
        self._timers[name] = {
            Interval = interval,
            LastRun = 0,
            Callback = callback
        }
    end

    -- Removes a loop or timer by name.
    function LoopManager:Unbind(name)
        self._loops.Render[name] = nil
        self._loops.Heartbeat[name] = nil
        self._loops.Stepped[name] = nil
        self._timers[name] = nil
    end

    return LoopManager
end
