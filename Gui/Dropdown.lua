return function(import)
    --[GuiLibrary]
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local InputManager = import("Core/InputManager")
    local LoopManager = import("Core/LoopManager")
	local DrawingManager = import("Core/DrawingManager")
    local Services = import("Core/Services")
    local UserInputService = Services.Get("UserInputService")
    local Theme = import("Gui/Theme")
	local Button = import("Gui/Elements/Button")
	local Dropdown = import("Gui/Elements/Dropdown")

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
            Size = UDim2.new(1, 0, 0, 30),
            Position = UDim2.new(0, 0, 0, 30),
            BackgroundColor3 = Theme.Secondary,
            BorderSizePixel = 0,
        })
        windowJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = tabContainer }))

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

        screenGui.Enabled = false
        screenGui.Parent = game:GetService("CoreGui")
        return windowJanitor -- Return the janitor so the window can be destroyed individually if needed
    end

    return Library
return function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local Theme = import("Gui/Theme")
    local Services = import("Core/Services")
    local UserInputService = Services.Get("UserInputService")

    local Dropdown = {}
    Dropdown.__index = Dropdown

    function Dropdown.Create(properties)
        local elementJanitor = Janitor.new()

        local dropdownFrame = Kernel:Create("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.Primary,
            BorderSizePixel = 0,
            LayoutOrder = properties.LayoutOrder,
            ClipsDescendants = true
        })
        elementJanitor:Add(dropdownFrame)
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = dropdownFrame }))

        local mainButton = Kernel:Create("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Theme.Primary,
            Font = Theme.Font,
            TextSize = Theme.Font_Size,
            TextColor3 = Theme.Text,
            Text = properties.DefaultText or "Select Option",
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            TextTransparency = 0
        })
        elementJanitor:Add(mainButton)
        elementJanitor:Add(Kernel:Create("UIPadding", {PaddingLeft = UDim.new(0,5,0), PaddingRight = UDim.new(0,5,0), PaddingTop = UDim.new(0,0,0), PaddingBottom = UDim.new(0,0,0), Parent = mainButton}))
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = mainButton }))

        local dropdownList = Kernel:Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(0,0,1,0),
            BackgroundColor3 = Theme.Primary,
            BorderSizePixel = 0,
            Visible = false,
            ClipsDescendants = true,
        })

        elementJanitor:Add(dropdownList)
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = dropdownList }))

        local scrollingFrame = Kernel:Create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Theme.Primary,
            BorderSizePixel = 0,
            ScrollBarThickness = 5,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(1,0,0,0),
            Parent = dropdownList
        })
        elementJanitor:Add(Kernel:Create("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder,  Parent = scrollingFrame, Padding = UDim.new(0,2,0) }))
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = scrollingFrame }))

        local isDropdownOpen = false

        local function ToggleDropdown()
            isDropdownOpen = not isDropdownOpen
            dropdownList.Visible = isDropdownOpen
            if isDropdownOpen then
                dropdownList:TweenSize(UDim2.new(1, 0, 0, math.min(200, #properties.Options * 32)), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
            else
                dropdownList:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
            end
        end
        elementJanitor:Add(Kernel:Connect(mainButton.MouseButton1Click, ToggleDropdown))

        local function OnOptionSelected(optionText, optionValue)
            mainButton.Text = optionText
            ToggleDropdown()
            properties.Callback(optionValue)
        end

        if properties.Options then
            for i, option in ipairs(properties.Options) do
                local button = Kernel:Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundColor3 = Theme.Secondary,
                    Font = Theme.Font,
                    TextSize = Theme.Font_Size,
                    TextColor3 = Theme.Text,
                    Text = option.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BorderSizePixel = 0,
                    LayoutOrder = i
                })
        elementJanitor:Add(Kernel:Create("UIPadding", {PaddingLeft = UDim.new(0,5,0), PaddingRight = UDim.new(0,5,0), PaddingTop = UDim.new(0,0,0), PaddingBottom = UDim.new(0,0,0), Parent = button}))
                elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = button }))

                elementJanitor:Add(Kernel:Connect(button.MouseButton1Click, function()
                    OnOptionSelected(option.Text, option.Value)
                end))
                button.Parent = scrollingFrame
            end
        end

        -- Give access to destroy for easy deletion
		dropdownFrame.Destroy = function()
			elementJanitor:Clean()
		end

        return dropdownFrame
    end

    return Dropdown
end
