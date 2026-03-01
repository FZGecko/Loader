return function(import)

    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local InputManager = import("Core/InputManager")
    local LoopManager = import("Core/LoopManager")
	local DrawingManager = import("Core/DrawingManager")
    local ThemeApplier = import("Gui/ThemeApplier")
    local Services = import("Core/Services")
    local UserInputService = Services.Get("UserInputService")
    local Theme = import("Gui/Theme")
	local Button = import("Gui/Elements/Button")
	local Dropdown = import("Gui/Elements/Dropdown")

    local Tab = import("Gui/Tab")
    local Library = {}

    function Library:CreateWindow(title)
        local windowJanitor = Janitor.new()

        --// Create UI Objects
        local screenGui = Kernel:Create("ScreenGui", {
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Global,
        })
        windowJanitor:Add(screenGui)

        local mainFrame = Kernel:Create("Frame", {
            Parent = screenGui,
            Size = UDim2.fromOffset(500, 350),
            Position = UDim2.fromOffset(100, 100),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
        })
        windowJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = mainFrame }))

        local header = Kernel:Create("Frame", {
            Parent = mainFrame,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.Primary,
        })
        windowJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = header }))

        local titleLabel = Kernel:Create("TextLabel", {
            Parent = header,
            Size = UDim2.new(1, -10, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            BackgroundColor3 = Theme.Primary,
            BackgroundTransparency = 1,
            Font = Theme.Font,
            TextSize = Theme.Font_Size,
            TextColor3 = Theme.Text,
            Text = title or "Universal Core",
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        windowJanitor:Add(titleLabel)
        --// Tab Container
        local tabContainer = Kernel:Create("Frame", {
            Parent = mainFrame,
			BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            Position = UDim2.new(0, 0, 0, 30),
            BackgroundColor3 = Theme.Secondary,
            BorderSizePixel = 0,
        })

        --// Content Container
        local contentContainer = Kernel:Create("Frame", {
            Parent = mainFrame,
            Size = UDim2.new(1, -4, 1, -34),
            Position = UDim2.new(0, 2, 0, 32),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            ClipsDescendants = true,
        })
        windowJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = contentContainer }))

		windowJanitor:Add(Tab.Create("Tab 1", mainFrame, tabContainer, contentContainer))
		windowJanitor:Add(Tab.Create("Tab 2", mainFrame, tabContainer, contentContainer))
		windowJanitor:Add(Tab.Create("Tab 3", mainFrame, tabContainer, contentContainer))

        --// Dragging Logic
        local dragging = false
        local dragStart

        local frameStart

        windowJanitor:Add(Kernel:Connect(header.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = UserInputService:GetMouseLocation()
                frameStart = mainFrame.Position
            end
        end))

        windowJanitor:Add(Kernel:Connect(header.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false

            end
        end))

        LoopManager:Bind("WindowDrag", "Render", function()
            if dragging then
                local delta = (UserInputService:GetMouseLocation() - dragStart)

                mainFrame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
            end
        end)

        --// Toggle Logic
        InputManager:Bind("ToggleUI", Enum.KeyCode.RightShift, function()

            screenGui.Enabled = not screenGui.Enabled
        end)

        screenGui.Enabled = true
        screenGui.Parent = game:GetService("CoreGui")
        return windowJanitor -- Return the janitor so the window can be destroyed individually if needed

    end

    return Library
end
