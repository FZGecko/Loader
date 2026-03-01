return  function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local ThemeApplier = import("Gui/ThemeApplier")
    local Theme = import("Gui/Theme")

    local Button = {}
    Button.__index = Button

    function Button.Create(properties)
        local elementJanitor = Janitor.new()

        local button = Kernel:Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.Primary,
            Font = Theme.Font,
            TextSize = Theme.Font_Size,
            TextColor3 = Theme.Text,
            Text = properties.Text or "Button",
            LayoutOrder = properties.LayoutOrder,
            BorderSizePixel = 0
        })
        elementJanitor:Add(button)
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = button }))

        local function SetState(state)
            if state == "Hovered" then
                button.BackgroundColor3 = Theme.Secondary
            elseif state == "Pressed" then
                button.BackgroundColor3 = Theme.Accent
            else
                button.BackgroundColor3 = Theme.Primary
            end
        end

        elementJanitor:Add(Kernel:Connect(button.MouseEnter, function() SetState("Hovered") end))
        elementJanitor:Add(Kernel:Connect(button.MouseLeave, function() SetState("Normal") end))
        elementJanitor:Add(Kernel:Connect(button.MouseButton1Down, function() SetState("Pressed") end))
        elementJanitor:Add(Kernel:Connect(button.MouseButton1Up, function() SetState("Hovered") end))

        if properties.Callback then
            elementJanitor:Add(Kernel:Connect(button.MouseButton1Click, properties.Callback))
        end

        SetState("Normal")

        -- Give access to destroy for easy deletion
		button.Destroy = function()
			elementJanitor:Clean()
		end

        return button
    end

    return Button
end

-- Properties : Text, Callback, LayoutOrder
