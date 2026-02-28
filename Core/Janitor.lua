-- [ Core/Janitor.lua ]
-- A utility class for cleaning up connections, instances, and other tasks.
-- It's a container for anything that needs to be destroyed or disconnected.

return function(import)
    local Janitor = {}
    Janitor.__index = Janitor

    function Janitor.new()
        return setmetatable({ _tasks = {} }, Janitor)
    end

    -- Adds a task to the Janitor's list.
    -- Returns the task for convenience.
    function Janitor:Add(task)
        if not task then return end
        table.insert(self._tasks, task)
        return task
    end

    -- Cleans up all tasks managed by this Janitor.
    function Janitor:Clean()
        -- Iterate backwards to prevent skipping elements if a task modifies the list.
        for i = #self._tasks, 1, -1 do
            local task = self._tasks[i]
            
            local taskType = typeof(task)

            if taskType == "RBXScriptConnection" then
                task:Disconnect()
            elseif taskType == "Instance" then
                task:Destroy()
            elseif taskType == "function" then
                pcall(task)
            elseif taskType == "table" and (task.Clean or task.Destroy) then
                -- Supports nested Janitors or other objects with a cleanup method.
                (task.Clean or task.Destroy)(task)
            end
            
            self._tasks[i] = nil
        end
    end

    -- Alias to Destroy for compatibility with standard object patterns.
    function Janitor:Destroy()
        self:Clean()
    end

    return Janitor
end
