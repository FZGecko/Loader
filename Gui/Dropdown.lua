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


-- Properties : DefaultText, Options, Callback, LayoutOrder
-- Options is a Table that contains Text, and Value
-- Value can be anything, this is what the callback returns. This can be a string or number etc
-- Calback is called when you select the selected item

-- TODO: Implement Scrolling if there are too many items in the list so it renders off screen.
-- Add ability to set default selected option.
-- Add Search bar if there are too many Items

-- Example code to add tabs
-- Options = {
-- {Text = "Option 1", Value = "1"},
--{Text = "Option 2", Value = "2"},
--{Text = "Option 3", Value = "3"},
--{Text = "Option 4", Value = "4"},
--}
