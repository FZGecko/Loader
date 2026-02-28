return function(import)
    -- Manages tracking of player characters, providing a stable list of valid targets.
    -- Can also be extended to track other entity types (e.g., NPCs, Mobs) via TrackFolder.
    local Kernel = import("Core/Kernel")
    local Services = import("Core/Services")
    local Janitor = import("Core/Janitor")
    local Players = Services.Get("Players")
    
    local Manager = {
        TrackedEntities = {
            Players = {} -- Default group for players
        },
        _playerJanitors = {}, -- A Janitor for each player to manage their specific resources

        -- [ Adapters ]
        -- Overridable functions to handle games with custom/obfuscated character structures.
        Adapters = {
            GetCharacter = function(p) return p.Character end,
            GetCharacterAddedSignal = function(p) return p.CharacterAdded end,
            GetRoot = function(c) return c:WaitForChild("HumanoidRootPart", 5) end,
            GetHumanoid = function(c) return c:WaitForChild("Humanoid", 5) end,
            GetDeathSignal = function(h) return h.Died end
        }
    }
    
    --// Internal Player Tracking Logic
    function Manager:AddPlayer(player)
        if player == Players.LocalPlayer then return end
        if self._playerJanitors[player] then return end -- Already tracking

        local playerJanitor = Janitor.new()
        self._playerJanitors[player] = playerJanitor

        local function CharAdded(char)
            local root = self.Adapters.GetRoot(char)
            local hum = self.Adapters.GetHumanoid(char)
            
            -- Humanoid is optional (some games don't use them), but Root is required for ESP/Aimbot.
            if root then
                self.TrackedEntities.Players[player] = { Char = char, Root = root, Hum = hum }
                
                -- Auto-remove from cache on death. Connection is cleaned by the player's Janitor.
                if hum then
                    local deathSignal = self.Adapters.GetDeathSignal(hum)
                    if deathSignal then
                        playerJanitor:Add(deathSignal:Connect(function()
                            self.TrackedEntities.Players[player] = nil
                        end))
                    end
                end
            end
        end
        
        local char = self.Adapters.GetCharacter(player)
        if char then task.spawn(CharAdded, char) end
        
        local charAddedSignal = self.Adapters.GetCharacterAddedSignal(player)
        if charAddedSignal then
            playerJanitor:Add(charAddedSignal:Connect(CharAdded))
        end
    end

    --// Public API
    function Manager.Init()
        for _, p in ipairs(Players:GetPlayers()) do Manager:AddPlayer(p) end
        Kernel:Connect(Players.PlayerAdded, function(p) Manager:AddPlayer(p) end)
        Kernel:Connect(Players.PlayerRemoving, function(p)
            Manager.TrackedEntities.Players[p] = nil
            if Manager._playerJanitors[p] then
                Manager._playerJanitors[p]:Clean()
                Manager._playerJanitors[p] = nil
            end
        end)
    end

    -- Tracks all valid models within a specified folder.
    -- config: { folder, groupName, validation(model) -> bool, getHumanoid(model) -> humanoid }
    function Manager:TrackFolder(config)
        local groupName = config.groupName
        local folder = config.folder
        local validationFunc = config.validation
        local getHumanoidFunc = config.getHumanoid or function(m) return m:FindFirstChildOfClass("Humanoid") end

        if not (groupName and folder and validationFunc) then
            warn("[EntityManager] TrackFolder requires 'groupName', 'folder', and 'validation' function.")
            return
        end

        local group = {}
        self.TrackedEntities[groupName] = group
        local trackerJanitor = Janitor.new()

        local function AddEntity(entity)
            if validationFunc(entity) then
                group[entity] = { Char = entity } -- Basic data
                local hum = getHumanoidFunc(entity)
                if hum then
                    -- If a humanoid exists, automatically clean up on death
                    trackerJanitor:Add(hum.Died:Connect(function()
                        group[entity] = nil
                    end))
                end
            end
        end

        -- Initial scan
        for _, entity in ipairs(folder:GetChildren()) do
            AddEntity(entity)
        end

        -- Listen for changes
        trackerJanitor:Add(folder.ChildAdded:Connect(AddEntity))
        trackerJanitor:Add(folder.ChildRemoved:Connect(function(entity)
            group[entity] = nil -- Remove from tracking
        end))

        -- Return the janitor so the user can stop this specific tracker if needed
        return trackerJanitor
    end

    return Manager
end
