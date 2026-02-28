return function(import)
    local Kernel = import("Core/Kernel")
    local Services = import("Core/Services")
    local Janitor = import("Core/Janitor")
    local Players = Services.Get("Players")
    
    local Manager = {
        Targets = {},
        _playerJanitors = {} -- Stores a Janitor for each player
    }
    
    local function AddPlayer(player)
        if player == Players.LocalPlayer then return end
        if Manager._playerJanitors[player] then return end -- Already tracking

        local playerJanitor = Janitor.new()
        Manager._playerJanitors[player] = playerJanitor
        
        local function CharAdded(char)
            -- Wait for replication
            local root = char:WaitForChild("HumanoidRootPart", 5)
            local hum = char:WaitForChild("Humanoid", 5)
            
            if root and hum and hum.Health > 0 then
                Manager.Targets[player] = { Char = char, Root = root, Hum = hum }
                
                -- Auto-remove from cache on death, connection is cleaned by playerJanitor
                playerJanitor:Add(hum.Died:Connect(function()
                    Manager.Targets[player] = nil
                end))
            end
        end
        
        if player.Character then task.spawn(CharAdded, player.Character) end
        playerJanitor:Add(player.CharacterAdded:Connect(CharAdded))
    end
    
    function Manager.Init()
        for _, p in ipairs(Players:GetPlayers()) do AddPlayer(p) end
        Kernel:Connect(Players.PlayerAdded, AddPlayer) -- Kernel manages this connection
        Kernel:Connect(Players.PlayerRemoving, function(p)
            Manager.Targets[p] = nil
            if Manager._playerJanitors[p] then
                Manager._playerJanitors[p]:Clean()
                Manager._playerJanitors[p] = nil
            end
        end)
    end
    
    return Manager
end
