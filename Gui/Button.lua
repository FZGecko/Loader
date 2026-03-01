return function(import)
    local Kernel = import("Core/Kernel")
    local Janitor = import("Core/Janitor")
    local Theme = import("Gui/Theme")

    local Button = {}
    Button.__index = Button

    local function Create(properties)
        local elementJanitor = Janitor.new()

        local button = Kernel:Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.Primary,
            Font = Theme.Font,
            TextSize = Theme.FontSize,
            TextColor3 = Theme.Text,
            Text = properties.Text or "Button",
            LayoutOrder = properties.LayoutOrder,
            BorderSizePixel = 0
        })
        elementJanitor:Add(button)
        elementJanitor:Add(Kernel:Create("UICorner", { CornerRadius = UDim.new(0, Theme.Rounding), Parent = button }))

        elementJanitor:Add(Kernel:Connect(button.MouseEnter, function()
            button.BackgroundColor3 = Theme.Hover
        end))

        elementJanitor:Add(Kernel:Connect(button.MouseLeave, function()
            button.BackgroundColor3 = Theme.Primary
        end))

        elementJanitor:Add(Kernel:Connect(button.MouseButton1Down, function()
            button.BackgroundColor3 = Theme.Accent
        end))

        elementJanitor:Add(Kernel:Connect(button.MouseButton1Up, function()
            button.BackgroundColor3 = Theme.Hover
        end))

        if properties.Callback then
            elementJanitor:Add(Kernel:Connect(button.MouseButton1Click, properties.Callback))
        end

        button.Destroy = function()
            elementJanitor:Clean()
        end

		button.Hide = function()
			button.Visible = false
        end

        button.Show = function()
			button.Visible = true
            end

        return button
    end

    Button.Create = Create
    return Button
end
