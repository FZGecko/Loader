return function(import)
    -- A utility class for cleaning up tasks (connections, instances, functions).
    local Janitor = {}
    Janitor.__index = Janitor

    function Janitor.new()
        return setmetatable({ _tasks = {} }, Janitor)
    end

    function Janitor:Add(task)
        if not task then return end
        table.insert(self._tasks, task)
        return task
    end

    function Janitor:Clean()
        -- Iterate backwards to safely handle tasks that might remove other tasks.
        for i = #self._tasks, 1, -1 do
            local task = self._tasks[i]
            local type = typeof(task)
            
            if type == "RBXScriptConnection" then task:Disconnect()
            elseif type == "Instance" then task:Destroy()
            elseif type == "function" then pcall(task)
            elseif type == "table" and (task.Destroy or task.Clean) then (task.Destroy or task.Clean)(task)
            end
            
            self._tasks[i] = nil
        end
    end

    function Janitor:Destroy() self:Clean() end

    return Janitor
end
